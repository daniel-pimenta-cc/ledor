import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../core/utils/sentence_boundary.dart';
import '../../../../database/app_database.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../data/services/tts_audio_handler.dart';
import '../../data/services/tts_player.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';
import 'display_settings_provider.dart';
import 'tts_audio_handler_provider.dart';
import 'tts_backend_provider.dart';

/// The heart of the app. Manages RSVP playback using a [Ticker] for
/// frame-accurate word timing.
///
/// TTS playback is delegated to [TtsPlayer] (see `data/services/tts_player.dart`)
/// — the engine only orchestrates state transitions, session bookkeeping,
/// and progress persistence; the player owns the speak / queue / progress
/// pipeline.
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

  /// String form of the reader mode last persisted to the progress row.
  /// We compare against this before writing so the auto-restore in
  /// [_loadBook] doesn't trigger a wasted write — only genuine user
  /// changes via [enterTtsMode] / [exitTtsMode] / [enterEreaderMode] /
  /// [exitEreaderMode] cause a DB+sync round-trip.
  String? _lastSavedReaderMode;

  DateTime? _sessionStartedAt;
  int? _sessionStartWordIndex;
  static const _uuid = Uuid();

  /// TTS playback delegate. Lazily constructed on first [enterTtsMode] so
  /// the platform-channel cost is paid only when the user actually uses
  /// the mode.
  TtsPlayer? _ttsPlayer;

  /// Audio-handler source we registered on enter. Held so dispose can
  /// release it without clobbering a handler that's already moved on to a
  /// different reader.
  TtsAudioSource? _audioSource;

  /// Cached handler reference so [_unbindAudioHandler] can do its work
  /// without re-reading the provider — useful in [dispose], where the
  /// `ProviderContainer` itself may already be tearing down and a read
  /// would throw.
  TtsAudioHandler? _audioHandler;

  /// Book title cached during _loadBook for the media notification. Falls
  /// back to the book id if the lookup fails or the title is empty.
  String _bookTitle = '';
  String _bookAuthor = '';

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
    final booksDao = _ref.read(booksDaoProvider);
    final settingsNotifier = _ref.read(displaySettingsProvider.notifier);

    final results = await Future.wait([
      tokensDao.getTokensForBook(state.bookId),
      progressDao.getProgressForBook(state.bookId),
      settingsNotifier.load(),
      booksDao.getBookById(state.bookId),
    ]);
    if (!mounted) return;

    final book = results[3] as BooksTableData?;
    _bookTitle = book?.title ?? state.bookId;
    _bookAuthor = book?.author ?? '';

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
    final persistedMode = parsePersistedReaderMode(progress?.readerMode);

    final totalWords = chapters.fold<int>(0, (sum, ch) => sum + ch.wordCount);
    final globalIdx = _calculateGlobalIndex(chapters, chapterIdx, wordIdx);

    final displaySettings =
        _ref.read(displaySettingsProvider).copyWith(wpm: wpm);

    _lastSavedWordIndex = globalIdx;
    _lastSavedReaderMode = progress?.readerMode;

    // TTS restoration is async (player init); keep `isLoading=true` so the
    // user can't tap play before the player is bound. Ereader / RSVP are
    // synchronous — flip loading off in the same state copy.
    final restoringTts = persistedMode == ReaderMode.tts;
    final initialMode = persistedMode == ReaderMode.ereader
        ? ReaderMode.ereader
        : ReaderMode.scroll;

    state = state.copyWith(
      chapters: chapters,
      currentChapterIndex: chapterIdx,
      currentWordIndex: wordIdx,
      globalWordIndex: globalIdx,
      totalWords: totalWords,
      currentWord: chapters[chapterIdx].tokens[wordIdx],
      wpm: wpm,
      mode: initialMode,
      isLoading: restoringTts,
      displaySettings: displaySettings,
    );

    if (restoringTts) {
      await enterTtsMode();
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
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

    // TTS path: ticker stays dormant; the player drives the backend.
    // The end-of-book guard is intentionally relaxed here — the last
    // sentence still needs to be spoken; the player's onBookFinished
    // callback bumps finishTicket.
    if (state.mode == ReaderMode.tts) {
      _sessionStartedAt = DateTime.now();
      _sessionStartWordIndex = state.globalWordIndex;
      _wordsInSession = 0;
      state = state.copyWith(isPlaying: true);
      _pushSettingsToPlayer();
      unawaited(
        _ttsPlayer?.play(fromGlobalIndex: state.globalWordIndex),
      );
      _pushPlaybackState(true);
      return;
    }

    final vsync = _vsync;
    if (vsync == null) return;

    if (state.globalWordIndex >= state.totalWords - 1) return;

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

    // TTS path: stop the backend, keep mode == tts so the reader stays on
    // the scroll-with-highlight view. The user expects the same screen
    // they were on, just without sound.
    if (state.mode == ReaderMode.tts) {
      unawaited(_ttsPlayer?.pause());
      state = state.copyWith(isPlaying: false);
      _flushSession();
      _saveProgress();
      _pushPlaybackState(false);
      return;
    }

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
      if (state.mode == ReaderMode.tts) {
        unawaited(_ttsPlayer?.pause());
      } else {
        _ticker?.stop();
      }
      _flushSession();
    }
    state = state.copyWith(isPlaying: false, mode: ReaderMode.ereader);
    unawaited(_saveProgress());
  }

  void exitEreaderMode() {
    if (state.mode != ReaderMode.ereader) return;
    state = state.copyWith(mode: ReaderMode.scroll);
    unawaited(_saveProgress());
  }

  void toggleEreaderMode() {
    if (state.mode == ReaderMode.ereader) {
      exitEreaderMode();
    } else {
      enterEreaderMode();
    }
  }

  /// Switches into TTS mode without auto-playing. The reader sees the same
  /// scroll-with-highlight view used by `ReaderMode.scroll`, but tapping
  /// play hands control to the TTS player instead of the ticker.
  ///
  /// Lazy-initialises the backend on first call so users who never visit
  /// TTS don't pay the platform-channel cost. If init throws (e.g.
  /// `spd-say` missing on Linux) the error is propagated via the
  /// [ttsErrorProvider] and we revert mode back to scroll.
  Future<void> enterTtsMode() async {
    if (state.mode == ReaderMode.tts) return;

    if (state.isPlaying) {
      _ticker?.stop();
      _flushSession();
    }

    // Flip the UI to TTS up front so the mode menu reflects the choice
    // immediately. The backend setup awaits below — without this, a user
    // who taps play before init finishes would fall into the RSVP path
    // because `state.mode` was still `scroll`.
    state = state.copyWith(isPlaying: false, mode: ReaderMode.tts);

    final player = _ensurePlayer();
    try {
      await player.init();
    } catch (e) {
      if (!mounted) return;
      _ref.read(ttsErrorProvider.notifier).state = e.toString();
      state = state.copyWith(mode: ReaderMode.scroll);
      // Surface the rollback to the persistence layer too so a failed
      // restoration doesn't leave 'tts' stale in the progress row.
      unawaited(_saveProgress());
      return;
    }
    if (!mounted) return;
    // The user may have switched away from TTS while init was awaited
    // (e.g. tapped Ereader in the menu before the player finished
    // initialising). Bail without binding the audio handler — the new
    // mode owns the screen now, and binding here would resurface a
    // lockscreen notification for a session the user already abandoned.
    if (state.mode != ReaderMode.tts) return;

    player.setContent(state.chapters, state.totalWords);
    _pushSettingsToPlayer();
    // Push settings to the backend right away so previews + the first play
    // start with the user's chosen voice / rate / language without waiting
    // for the speak() call to apply them.
    unawaited(player.applySettings());
    _bindAudioHandler();
    // Save the mode (skipped when called from _loadBook auto-restore — the
    // _lastSavedReaderMode there already equals 'tts').
    unawaited(_saveProgress());
  }

  /// Exits TTS mode back to scroll. Stops any in-flight speech, flushes
  /// the session if needed.
  void exitTtsMode() {
    if (state.mode != ReaderMode.tts) return;
    if (state.isPlaying) {
      unawaited(_ttsPlayer?.pause());
      _flushSession();
    }
    state = state.copyWith(isPlaying: false, mode: ReaderMode.scroll);
    _unbindAudioHandler();
    unawaited(_saveProgress());
  }

  /// Called by the screen's lifecycle observer when the app resumes. If
  /// TTS was playing and the OS killed the synth (Android backgrounding
  /// without MediaSession will do this), restart from the current
  /// position. Idempotent — safe to call when the TTS path is healthy.
  void restartTtsIfStalled() {
    if (state.mode != ReaderMode.tts || !state.isPlaying) return;
    unawaited(_ttsPlayer?.restartIfStalled());
  }

  void setWpm(int wpm) {
    final clamped = wpm.clamp(AppConstants.minWpm, AppConstants.maxWpm);
    state = state.copyWith(
      wpm: clamped,
      displaySettings: state.displaySettings.copyWith(wpm: clamped),
    );
    // Mirror into the provider so settings-panel sliders see the latest
    // WPM. Without this, the panel would render stale state and any
    // unrelated slider change would snapshot the old value back into the
    // engine.
    unawaited(_ref
        .read(displaySettingsProvider.notifier)
        .update((s) => s.copyWith(wpm: clamped)));
    // Note: in TTS mode the user controls speed via `setTtsRate`, not WPM —
    // WPM is meaningless when an audio engine sets its own cadence. We
    // intentionally do *not* propagate WPM changes to the backend here.
  }

  void increaseWpm() => setWpm(state.wpm + AppConstants.wpmStep);
  void decreaseWpm() => setWpm(state.wpm - AppConstants.wpmStep);

  /// Sets the TTS speech rate (audiobook-style 1.0x / 1.25x / …). Persists
  /// to `DisplaySettings.ttsRate` and propagates to the player immediately
  /// so the next utterance (including already-queued lookahead) picks it up.
  void setTtsRate(double rate) {
    final clamped = rate.clamp(AppConstants.minTtsRate, AppConstants.maxTtsRate);
    if (clamped == state.displaySettings.ttsRate) return;
    state = state.copyWith(
      displaySettings: state.displaySettings.copyWith(ttsRate: clamped),
    );
    // Same rationale as setWpm: mirror into the provider to keep the
    // settings panel and the engine in sync.
    unawaited(_ref
        .read(displaySettingsProvider.notifier)
        .update((s) => s.copyWith(ttsRate: clamped)));
    if (state.mode == ReaderMode.tts) {
      unawaited(_ttsPlayer?.setRate(clamped));
    }
  }

  void increaseTtsRate() =>
      setTtsRate(state.displaySettings.ttsRate + AppConstants.ttsRateStep);
  void decreaseTtsRate() =>
      setTtsRate(state.displaySettings.ttsRate - AppConstants.ttsRateStep);

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

    // TTS mode: the player rebuilds its pipeline from the new position.
    if (state.mode == ReaderMode.tts) {
      unawaited(_ttsPlayer?.seek(clamped));
      return;
    }

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
    final previous = state.displaySettings;
    final next = updater(previous);
    state = state.copyWith(displaySettings: next);

    // Live-propagate TTS settings so the user hears them on the next
    // utterance. The player itself decides what to apply when (rate goes
    // through immediately; voice / pitch / language wait for the next
    // utterance).
    if (state.mode == ReaderMode.tts && _ttsPlayer != null) {
      _pushSettingsToPlayer();
    }
    // Even outside TTS mode, keep an updated snapshot ready so the player
    // doesn't blow stale settings at the engine on next enterTtsMode.
    _ttsPlayer?.setSettings(_currentTtsSettings());
  }

  // ---------- TTS player wiring ----------

  TtsPlayer _ensurePlayer() {
    final existing = _ttsPlayer;
    if (existing != null) return existing;
    final backend = _ref.read(ttsBackendProvider);
    final player = TtsPlayer(backend);
    player.onWordAdvance = _onPlayerWordAdvance;
    player.onBookFinished = _onPlayerBookFinished;
    player.onError = _onPlayerError;
    _ttsPlayer = player;
    return player;
  }

  TtsPlayerSettings _currentTtsSettings() {
    final s = state.displaySettings;
    return TtsPlayerSettings(
      language: s.ttsLanguage,
      voiceName: s.ttsVoiceName,
      engineId: s.ttsEngineId,
      pitch: s.ttsPitch,
      rate: s.ttsRate,
      largeChunks: PlatformCapabilities.isLinux,
    );
  }

  void _pushSettingsToPlayer() {
    final player = _ttsPlayer;
    if (player == null) return;
    player.setContent(state.chapters, state.totalWords);
    player.setSettings(_currentTtsSettings());
  }

  void _onPlayerWordAdvance(int newGlobalIndex, int wordsAdvanced) {
    if (!mounted) return;
    if (newGlobalIndex < 0 || newGlobalIndex >= state.totalWords) return;
    final (cIdx, wIdx) = _globalToLocal(newGlobalIndex);
    state = state.copyWith(
      currentChapterIndex: cIdx,
      currentWordIndex: wIdx,
      globalWordIndex: newGlobalIndex,
      currentWord: state.chapters[cIdx].tokens[wIdx],
    );
    if (wordsAdvanced > 0) {
      _wordsInSession += wordsAdvanced;
    }
  }

  void _onPlayerBookFinished() {
    if (!mounted) return;
    state = state.copyWith(
      isPlaying: false,
      finishTicket: state.finishTicket + 1,
    );
    _flushSession();
    _saveProgress();
    _pushPlaybackState(false);
  }

  void _onPlayerError(String error) {
    if (!mounted) return;
    if (state.isPlaying && state.mode == ReaderMode.tts) {
      state = state.copyWith(isPlaying: false);
      _flushSession();
      _saveProgress();
      _pushPlaybackState(false);
    }
    _ref.read(ttsErrorProvider.notifier).state = error;
  }

  // ---------- Audio handler wiring ----------

  void _bindAudioHandler() {
    final handler = _ref.read(ttsAudioHandlerProvider);
    if (handler == null) return;
    final source = TtsAudioSource(
      play: play,
      pause: pause,
      skipForward: () => skipForward(),
      skipBackward: () => skipBackward(),
    );
    _audioSource = source;
    _audioHandler = handler;
    handler.bindSource(source);
    handler.setActiveBook(
      bookId: state.bookId,
      title: _bookTitle,
      author: _bookAuthor.isEmpty ? null : _bookAuthor,
    );
    handler.updatePlaybackState(playing: state.isPlaying);
  }

  void _unbindAudioHandler() {
    final handler = _audioHandler;
    final source = _audioSource;
    if (handler == null || source == null) return;
    handler.unbindIfActive(source);
    _audioSource = null;
    _audioHandler = null;
  }

  /// Pushes [playing] to the audio handler if one is currently bound.
  /// Reads through the cached handler reference so it's safe to call
  /// from any path, including dispose-adjacent.
  void _pushPlaybackState(bool playing) {
    _audioHandler?.updatePlaybackState(playing: playing);
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

    // Inline image at the new cursor. RSVP path stops so the reader can
    // pan/zoom. The TTS path advances through images silently inside the
    // player and never reaches this code.
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

    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
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
    final currentMode = persistedReaderMode(state.mode);
    final wordChanged = state.globalWordIndex != _lastSavedWordIndex;
    final modeChanged = currentMode != _lastSavedReaderMode;
    if (!wordChanged && !modeChanged) return;
    _lastSavedWordIndex = state.globalWordIndex;
    _lastSavedReaderMode = currentMode;

    final progressDao = _ref.read(readingProgressDaoProvider);
    await progressDao.upsertProgress(ReadingProgressTableCompanion(
      bookId: Value(state.bookId),
      chapterIndex: Value(state.currentChapterIndex),
      wordIndex: Value(state.currentWordIndex),
      wpm: Value(state.wpm),
      updatedAt: Value(DateTime.now()),
      readerMode: Value(currentMode),
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
    // Dispose the player too — it detaches its callbacks from the shared
    // backend so a late completion doesn't try to drive this disposed
    // notifier. The backend itself is owned by ttsBackendProvider.
    final player = _ttsPlayer;
    if (player != null) {
      unawaited(player.dispose());
    }
    _unbindAudioHandler();
    _flushSession();
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveProgress();
    }
    super.dispose();
  }
}

/// Surfaces the most recent TTS error so the screen can show a snackbar.
/// Cleared by the UI after reading. Plain `StateProvider` because the
/// error is just a string and we don't need a notifier.
final ttsErrorProvider = StateProvider<String?>((_) => null);

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

  if (currentWord != null && wordEndsSentence(currentWord.text)) {
    multiplier *= settings.sentencePauseMultiplier;
  }
  if (nextWord != null && nextWord.isChapterStart) {
    multiplier *= settings.chapterPauseMultiplier;
  }
  return multiplier.clamp(0.5, 10.0);
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
