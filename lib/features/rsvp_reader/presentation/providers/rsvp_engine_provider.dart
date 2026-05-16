import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';
import 'display_settings_provider.dart';

/// The heart of the app. Manages RSVP playback using a [Ticker] for
/// frame-accurate word timing.
class RsvpEngineNotifier extends StateNotifier<RsvpState> {
  final Ref _ref;
  Ticker? _ticker;
  TickerProvider? _vsync;
  Future<void>? _initFuture;
  Duration _elapsed = Duration.zero;
  Duration _nextWordAt = Duration.zero;
  int _wordsInSession = 0;
  Timer? _saveDebounce;
  int _lastSavedWordIndex = -1;

  DateTime? _sessionStartedAt;
  int? _sessionStartWordIndex;
  static const _uuid = Uuid();

  RsvpEngineNotifier(this._ref, String bookId)
      : super(RsvpState(bookId: bookId)) {
    _initFuture = _loadBook();
  }

  /// Hand the engine a [TickerProvider] for later [play] calls.
  ///
  /// The book is already loading (or finished) by the time this is called;
  /// the widget no longer blocks data loading on its own mount. The Ticker
  /// itself is created lazily on first play so pre-warming from outside the
  /// widget tree stays trivial.
  Future<void> attachVsync(TickerProvider vsync) {
    _vsync = vsync;
    return _initFuture ?? Future.value();
  }

  Future<void> _loadBook() async {
    final tokensDao = _ref.read(cachedTokensDaoProvider);
    final progressDao = _ref.read(readingProgressDaoProvider);
    final settingsNotifier = _ref.read(displaySettingsProvider.notifier);

    final results = await Future.wait([
      tokensDao.getTokensForBook(state.bookId),
      progressDao.getProgressForBook(state.bookId),
      settingsNotifier.load(),
    ]);
    if (!mounted) return;

    final cachedRows = results[0] as List<CachedTokensTableData>;
    final progress = results[1] as ReadingProgressTableData?;

    if (cachedRows.isEmpty) return;

    final chapters = await compute(
      _decodeChapters,
      [for (final r in cachedRows) (r.chapterTitle, r.tokensJson)],
    );
    if (!mounted) return;
    if (chapters.isEmpty) return;

    final chapterIdx = progress?.chapterIndex ?? 0;
    final wordIdx = progress?.wordIndex ?? 0;
    final wpm = progress?.wpm ?? _ref.read(displaySettingsProvider).wpm;

    final totalWords = chapters.fold<int>(0, (sum, ch) => sum + ch.wordCount);
    final globalIdx = _calculateGlobalIndex(chapters, chapterIdx, wordIdx);

    final displaySettings =
        _ref.read(displaySettingsProvider).copyWith(wpm: wpm);

    _lastSavedWordIndex = globalIdx;

    state = state.copyWith(
      chapters: chapters,
      currentChapterIndex: chapterIdx,
      currentWordIndex: wordIdx,
      globalWordIndex: globalIdx,
      totalWords: totalWords,
      currentWord: chapters[chapterIdx].tokens[wordIdx],
      wpm: wpm,
      isLoading: false,
      displaySettings: displaySettings,
    );
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;

    if (_elapsed >= _nextWordAt) {
      _advanceWord();
      _wordsInSession++;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    final effectiveWpm = _effectiveWpm();
    final baseMs = 60000.0 / effectiveWpm;
    final multiplier = computeWordIntervalMultiplier(
      currentWord: state.currentWord,
      nextWord: _peekNextWord(),
      settings: state.displaySettings,
    );
    _nextWordAt =
        _elapsed + Duration(milliseconds: (baseMs * multiplier).round());
  }

  /// Returns the token that will replace the current word on the next tick,
  /// or `null` when we're already on the last word of the last chapter.
  /// Used to schedule a chapter-seam pause before the new chapter shows up.
  WordToken? _peekNextWord() {
    final chapters = state.chapters;
    final chapterIdx = state.currentChapterIndex;
    final wordIdx = state.currentWordIndex;
    if (chapterIdx >= chapters.length) return null;
    final chapter = chapters[chapterIdx];
    if (wordIdx + 1 < chapter.tokens.length) {
      return chapter.tokens[wordIdx + 1];
    }
    if (chapterIdx + 1 < chapters.length &&
        chapters[chapterIdx + 1].tokens.isNotEmpty) {
      return chapters[chapterIdx + 1].tokens[0];
    }
    return null;
  }

  /// Returns the current effective WPM accounting for ramp-up.
  double _effectiveWpm() => computeEffectiveWpm(
        targetWpm: state.wpm,
        wordsInSession: _wordsInSession,
        rampUpEnabled: state.displaySettings.rampUp,
      );

  // ---------- Public controls ----------

  void play() {
    if (state.isPlaying || state.isLoading) return;
    if (state.globalWordIndex >= state.totalWords - 1) return;
    final vsync = _vsync;
    if (vsync == null) return;

    // Cursor sits on an inline image: don't run the ticker — the reader
    // needs the screen to stay put so they can pan/zoom. Switching to rsvp
    // mode is enough; the image-display widget takes the word slot.
    if (state.currentWord?.isImage ?? false) {
      state = state.copyWith(mode: ReaderMode.rsvp);
      return;
    }

    _ticker ??= vsync.createTicker(_onTick);

    _elapsed = Duration.zero;
    // Hold the first word for the pre-roll delay so the scroll → rsvp
    // AnimatedSwitcher can finish and the eyes have time to focus before
    // the engine starts advancing.
    _nextWordAt = AppConstants.playPreRollDelay;
    _wordsInSession = 0;
    _sessionStartedAt = DateTime.now();
    _sessionStartWordIndex = state.globalWordIndex;
    _ticker?.start();
    state = state.copyWith(isPlaying: true, mode: ReaderMode.rsvp);
  }

  void pause() {
    if (!state.isPlaying) return;
    _ticker?.stop();
    state = state.copyWith(isPlaying: false, mode: ReaderMode.scroll);
    _flushSession();
    _saveProgress();
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Advance past the image the reader has been inspecting and resume
  /// playback from the next text word. No-op if the cursor isn't on an
  /// image (defensive; the dismiss button is only wired in image state).
  void dismissImage() {
    if (!(state.currentWord?.isImage ?? false)) return;
    final next = state.globalWordIndex + 1;
    if (next >= state.totalWords) return;

    final (chapterIdx, wordIdx) = _globalToLocal(next);
    state = state.copyWith(
      currentChapterIndex: chapterIdx,
      currentWordIndex: wordIdx,
      globalWordIndex: next,
      currentWord: state.chapters[chapterIdx].tokens[wordIdx],
    );
    // Auto-resume — the reader just told us they're done with the figure.
    play();
  }

  void enterEreaderMode() {
    if (state.isPlaying) {
      _ticker?.stop();
      _flushSession();
      _saveProgress();
    }
    state = state.copyWith(isPlaying: false, mode: ReaderMode.ereader);
  }

  void exitEreaderMode() {
    if (state.mode != ReaderMode.ereader) return;
    state = state.copyWith(mode: ReaderMode.scroll);
  }

  void toggleEreaderMode() {
    if (state.mode == ReaderMode.ereader) {
      exitEreaderMode();
    } else {
      enterEreaderMode();
    }
  }

  void setWpm(int wpm) {
    final clamped = wpm.clamp(AppConstants.minWpm, AppConstants.maxWpm);
    state = state.copyWith(
      wpm: clamped,
      displaySettings: state.displaySettings.copyWith(wpm: clamped),
    );
  }

  void increaseWpm() => setWpm(state.wpm + AppConstants.wpmStep);
  void decreaseWpm() => setWpm(state.wpm - AppConstants.wpmStep);

  /// Seek to a specific global word index.
  void seekToWord(int globalIndex) {
    final clamped = globalIndex.clamp(0, state.totalWords - 1);
    final (chapterIdx, wordIdx) = _globalToLocal(clamped);

    state = state.copyWith(
      currentChapterIndex: chapterIdx,
      currentWordIndex: wordIdx,
      globalWordIndex: clamped,
      currentWord: state.chapters[chapterIdx].tokens[wordIdx],
    );

    if (!state.isPlaying) _scheduleSaveProgress();
  }

  void skipForward([int words = AppConstants.skipWordCount]) {
    seekToWord(state.globalWordIndex + words);
  }

  void skipBackward([int words = AppConstants.skipWordCount]) {
    seekToWord(state.globalWordIndex - words);
  }

  void jumpToChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;
    final globalIdx = _calculateGlobalIndex(state.chapters, chapterIndex, 0);
    seekToWord(globalIdx);
  }

  void updateDisplaySettings(DisplaySettings Function(DisplaySettings) updater) {
    state = state.copyWith(displaySettings: updater(state.displaySettings));
  }

  // ---------- Private helpers ----------

  void _advanceWord() {
    int chapterIdx = state.currentChapterIndex;
    int wordIdx = state.currentWordIndex + 1;

    if (wordIdx >= state.chapters[chapterIdx].tokens.length) {
      chapterIdx++;
      wordIdx = 0;
      if (chapterIdx >= state.chapters.length) {
        // End of book
        _ticker?.stop();
        state = state.copyWith(
          isPlaying: false,
          finishTicket: state.finishTicket + 1,
        );
        _flushSession();
        _saveProgress();
        return;
      }
    }

    state = state.copyWith(
      currentChapterIndex: chapterIdx,
      currentWordIndex: wordIdx,
      globalWordIndex: state.globalWordIndex + 1,
      currentWord: state.chapters[chapterIdx].tokens[wordIdx],
    );

    // Inline image at the new cursor: stop and wait for the reader to
    // dismiss it. We keep `mode: ReaderMode.rsvp` so the image widget can
    // take the spot the RSVP word would have rendered in.
    if (state.currentWord?.isImage ?? false) {
      _autoPauseOnImage();
    }
  }

  /// Halts playback and persists progress when [_advanceWord] lands on an
  /// image token. Distinct from [pause] because we don't flip back to
  /// scroll mode — the image is still the focus.
  void _autoPauseOnImage() {
    _ticker?.stop();
    state = state.copyWith(isPlaying: false);
    _flushSession();
    _saveProgress();
  }

  /// Persists the current session if it meets minimum thresholds
  /// (see [computeSessionAvgWpm]). Safe to call multiple times — clears
  /// session state on first call. Fires DAO insert as fire-and-forget
  /// so pause() doesn't lag on DB write.
  void _flushSession() {
    final startedAt = _sessionStartedAt;
    final startIdx = _sessionStartWordIndex;
    _sessionStartedAt = null;
    _sessionStartWordIndex = null;
    if (startedAt == null || startIdx == null) return;

    final durationMs = _elapsed.inMilliseconds;
    final wordsRead = _wordsInSession;
    final avgWpm = computeSessionAvgWpm(durationMs, wordsRead);
    if (avgWpm == null) return;

    final dao = _ref.read(readingSessionDaoProvider);
    unawaited(dao.insertSession(
      ReadingSessionTableCompanion.insert(
        id: _uuid.v4(),
        bookId: state.bookId,
        startedAt: startedAt,
        endedAt: DateTime.now(),
        durationMs: durationMs,
        wordsRead: wordsRead,
        startWordIndex: startIdx,
        endWordIndex: state.globalWordIndex,
        avgWpm: avgWpm,
      ),
    ));
  }

  /// Coalesce rapid saves (e.g. continuous slider drag) into one DB write.
  void _scheduleSaveProgress() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 300),
      _saveProgress,
    );
  }

  Future<void> _saveProgress() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (state.globalWordIndex == _lastSavedWordIndex) return;
    _lastSavedWordIndex = state.globalWordIndex;

    final progressDao = _ref.read(readingProgressDaoProvider);
    await progressDao.upsertProgress(ReadingProgressTableCompanion(
      bookId: Value(state.bookId),
      chapterIndex: Value(state.currentChapterIndex),
      wordIndex: Value(state.currentWordIndex),
      wpm: Value(state.wpm),
      updatedAt: Value(DateTime.now()),
    ));

    final booksDao = _ref.read(booksDaoProvider);
    await booksDao.updateLastReadAt(state.bookId);

    _ref.read(librarySyncProvider.notifier).schedulePush();
  }

  int _calculateGlobalIndex(List<Chapter> chapters, int chapterIdx, int wordIdx) {
    int global = 0;
    for (int c = 0; c < chapterIdx && c < chapters.length; c++) {
      global += chapters[c].tokens.length;
    }
    return global + wordIdx;
  }

  (int chapterIdx, int wordIdx) _globalToLocal(int globalIndex) {
    int remaining = globalIndex;
    for (int c = 0; c < state.chapters.length; c++) {
      if (remaining < state.chapters[c].tokens.length) {
        return (c, remaining);
      }
      remaining -= state.chapters[c].tokens.length;
    }
    // Fallback: last word of last chapter
    final lastChapter = state.chapters.length - 1;
    return (lastChapter, state.chapters[lastChapter].tokens.length - 1);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _flushSession();
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveProgress();
    }
    super.dispose();
  }
}

/// Provider family keyed by bookId. `autoDispose` so the per-book engine
/// (and its full decoded token graph) is released when the reader unmounts.
final rsvpEngineProvider = StateNotifierProvider.autoDispose
    .family<RsvpEngineNotifier, RsvpState, String>(
  (ref, bookId) => RsvpEngineNotifier(ref, bookId),
);

/// Returns the effective WPM during ramp-up.
///
/// Starts at [AppConstants.rampUpStartFraction] of [targetWpm] and follows
/// an ease-out cubic curve (`1 - (1 - t)^3`) to [targetWpm] over
/// [AppConstants.rampUpWords] words. The eased shape spends most of the
/// ramp near the target so the final convergence is gentle instead of a
/// hard linear hand-off — which used to feel abrupt at high target WPMs.
///
/// Returns [targetWpm] unchanged when [rampUpEnabled] is false or the
/// ramp is already complete.
double computeEffectiveWpm({
  required int targetWpm,
  required int wordsInSession,
  required bool rampUpEnabled,
}) {
  final target = targetWpm.toDouble();
  if (!rampUpEnabled) return target;
  if (wordsInSession >= AppConstants.rampUpWords) return target;

  final t = wordsInSession / AppConstants.rampUpWords;
  final inv = 1.0 - t;
  final eased = 1.0 - inv * inv * inv;
  final startWpm = target * AppConstants.rampUpStartFraction;
  return startWpm + (target - startWpm) * eased;
}

/// Returns the multiplier applied to the base ms-per-word interval.
///
/// Composes three sources, all multiplicative:
/// 1. The import-time [WordToken.timingMultiplier] (the existing
///    "smart timing" — short/long words, punctuation pauses, paragraph
///    and chapter-first-word stretches). Suppressed when
///    [DisplaySettings.smartTiming] is off so the raw 60000/WPM cadence
///    can be requested independently of the structural beats below.
/// 2. [DisplaySettings.sentencePauseMultiplier] when [currentWord] ends
///    a sentence (`.` `!` `?` or `…`/`...`). The pause sits on the
///    sentence-ender so the gap lands between sentences, not after the
///    first word of the next one.
/// 3. [DisplaySettings.chapterPauseMultiplier] when [nextWord] is the
///    first word of a new chapter, so the gap sits at the seam and the
///    chapter title is the first thing the reader sees after the pause.
///
/// The product is clamped to `[0.5, 10.0]` so a user maxing every dial
/// can't accidentally freeze the reader on a single word.
double computeWordIntervalMultiplier({
  required WordToken? currentWord,
  required WordToken? nextWord,
  required DisplaySettings settings,
}) {
  double multiplier = settings.smartTiming
      ? (currentWord?.timingMultiplier ?? 1.0)
      : 1.0;

  if (currentWord != null && _wordEndsSentence(currentWord.text)) {
    multiplier *= settings.sentencePauseMultiplier;
  }
  if (nextWord != null && nextWord.isChapterStart) {
    multiplier *= settings.chapterPauseMultiplier;
  }
  return multiplier.clamp(0.5, 10.0);
}

bool _wordEndsSentence(String text) {
  if (text.endsWith('…') || text.endsWith('...')) return true;
  return text.endsWith('.') || text.endsWith('!') || text.endsWith('?');
}

/// Returns the rounded avg WPM for a session with [durationMs] elapsed
/// and [wordsRead] ticks — or `null` if the session should be dropped as
/// noise (below minimum duration or word count). The thresholds filter
/// accidental taps on the play button.
int? computeSessionAvgWpm(int durationMs, int wordsRead) {
  const minDurationMs = 3000;
  const minWords = 5;
  if (durationMs < minDurationMs || wordsRead < minWords) return null;
  return (wordsRead * 60000 / durationMs).round();
}

/// Runs in a background isolate. Each record is `(chapterTitle, tokensJson)`.
/// For a 100k-word book the synchronous version of this blocked the UI
/// thread for hundreds of milliseconds; offloading it keeps the reader's
/// entry animation smooth.
List<Chapter> _decodeChapters(List<(String, String)> rows) {
  final chapters = <Chapter>[];
  for (final (title, json) in rows) {
    final tokens = (jsonDecode(json) as List)
        .map((j) => WordToken.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    chapters.add(Chapter(title: title, tokens: tokens));
  }
  return chapters;
}
