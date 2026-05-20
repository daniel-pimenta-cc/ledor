import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/sentence_boundary.dart';
import '../../../../database/app_database.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../data/services/tts_backend.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';
import '../../domain/entities/sentence_segment.dart';
import '../../domain/utils/sentence_extractor.dart';
import 'display_settings_provider.dart';
import 'tts_backend_provider.dart';

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

  // ---------- TTS-specific state ----------
  //
  // The TTS path runs in parallel to the Ticker-driven RSVP path. When
  // `state.mode == ReaderMode.tts && state.isPlaying`, the ticker is
  // dormant and `_tts` is driving word advancement through its progress
  // callback. The two paths share `_advanceWord`, `_flushSession`,
  // `_saveProgress`, and `finishTicket` semantics so reading stats and
  // completion screens light up uniformly.
  TtsBackend? _tts;
  SentenceSegment? _currentTtsSentence;

  /// Monotonically incremented every time we issue a new `speak()` or
  /// cancel an in-flight one (pause, stop, exitTtsMode, dispose). Async
  /// callbacks from `_tts` compare against this on entry — a stale
  /// callback (e.g. completion of a sentence the user already paused)
  /// becomes a no-op. Without this counter we'd race the engine on every
  /// pause/seek.
  int _ttsSpeakGeneration = 0;

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
    final vsync = _vsync;
    if (vsync == null) return;

    // TTS path: ticker stays dormant; the backend drives advancement.
    // The end-of-book guard is intentionally relaxed here — the last
    // sentence still needs to be spoken, and the completion callback
    // will bump finishTicket.
    if (state.mode == ReaderMode.tts) {
      _sessionStartedAt = DateTime.now();
      _sessionStartWordIndex = state.globalWordIndex;
      _wordsInSession = 0;
      state = state.copyWith(isPlaying: true);
      _startTtsSpeak();
      return;
    }

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
      _ttsSpeakGeneration++;
      unawaited(_tts?.stop());
      _currentTtsSentence = null;
      state = state.copyWith(isPlaying: false);
      _flushSession();
      _saveProgress();
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
        _ttsSpeakGeneration++;
        unawaited(_tts?.stop());
        _currentTtsSentence = null;
      } else {
        _ticker?.stop();
      }
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

  /// Switches into TTS mode without auto-playing. The reader sees the same
  /// scroll-with-highlight view used by `ReaderMode.scroll`, but tapping
  /// play hands control to the TTS backend instead of the ticker.
  ///
  /// Lazy-initialises the backend on first call so users who never visit
  /// TTS don't pay the platform-channel cost. If init throws (e.g.
  /// `spd-say` missing on Linux) the error is propagated via [onTtsError]
  /// and we revert mode back to scroll.
  Future<void> enterTtsMode() async {
    if (state.mode == ReaderMode.tts) return;

    // Flush whatever was running.
    if (state.isPlaying) {
      _ticker?.stop();
      _flushSession();
      unawaited(_saveProgress());
    }

    // Flip the UI to TTS up front so the mode menu reflects the choice
    // immediately. The backend setup awaits below — without this, a user
    // who taps play before init finishes would fall into the RSVP path
    // because `state.mode` was still `scroll`.
    state = state.copyWith(isPlaying: false, mode: ReaderMode.tts);

    final backend = _ref.read(ttsBackendProvider);
    try {
      await backend.init();
    } catch (e) {
      if (!mounted) return;
      // Propagate via the standard error channel so the UI shows a snackbar.
      _onTtsError(e.toString());
      // Init failed — roll the mode back so the user isn't stuck on a
      // dead TTS screen.
      state = state.copyWith(mode: ReaderMode.scroll);
      return;
    }
    if (!mounted) return;

    _tts = backend;
    backend.onProgress = _onTtsProgress;
    backend.onCompletion = _onTtsCompletion;
    backend.onError = _onTtsError;
    backend.onStart = null;

    // Apply settings to the backend up-front. Each call awaits so the
    // backend ends up in a consistent state before the user hits play.
    final s = state.displaySettings;
    await backend.setLanguage(s.ttsLanguage);
    if (!mounted) return;
    final voiceName = s.ttsVoiceName;
    if (voiceName != null && voiceName.isNotEmpty) {
      await backend.setVoice(TtsVoice(name: voiceName, locale: s.ttsLanguage));
      if (!mounted) return;
    }
    await backend.setPitch(s.ttsPitch);
    if (!mounted) return;
    await backend.setRate(s.ttsRate);
    if (!mounted) return;

    // If the user already tapped play while init was running, the
    // `play()` branch set `isPlaying = true` but couldn't kick off the
    // first utterance because `_tts` was still null. Pick that up now.
    if (state.isPlaying && _currentTtsSentence == null) {
      unawaited(_startTtsSpeak());
    }
  }

  /// Exits TTS mode back to scroll. Stops any in-flight speech, flushes
  /// the session if needed.
  void exitTtsMode() {
    if (state.mode != ReaderMode.tts) return;
    if (state.isPlaying) {
      _ttsSpeakGeneration++;
      unawaited(_tts?.stop());
      _currentTtsSentence = null;
      _flushSession();
      _saveProgress();
    }
    state = state.copyWith(isPlaying: false, mode: ReaderMode.scroll);
  }

  /// Called by the screen's lifecycle observer when the app resumes. If
  /// TTS was playing and the OS killed the synth (Android backgrounding
  /// without MediaSession will do this), restart from the current
  /// position. Idempotent — safe to call when the TTS path is healthy.
  void restartTtsIfStalled() {
    if (state.mode != ReaderMode.tts || !state.isPlaying) return;
    // If we have no current sentence the backend has finished and the
    // completion callback was lost — re-kick the loop.
    if (_currentTtsSentence == null) {
      _startTtsSpeak();
    }
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
  /// to `DisplaySettings.ttsRate` and propagates to the backend immediately;
  /// the change lands on the next utterance.
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
      unawaited(_tts?.setRate(clamped));
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

    // TTS mode: any user-initiated seek needs to restart the speak() at the
    // new position. We can't keep the previous utterance going — the audio
    // is already past the new spot.
    if (state.mode == ReaderMode.tts && state.isPlaying) {
      _ttsSpeakGeneration++;
      unawaited(_tts?.stop());
      _currentTtsSentence = null;
      _startTtsSpeak();
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

    // Live-propagate TTS-specific changes so the user hears them on the
    // next utterance (or immediately for an in-flight stream). We don't
    // restart in-flight speech for pitch/voice/language — too jarring;
    // the next sentence picks them up.
    final tts = _tts;
    if (state.mode != ReaderMode.tts || tts == null) return;
    if (next.ttsLanguage != previous.ttsLanguage) {
      unawaited(tts.setLanguage(next.ttsLanguage));
    }
    if (next.ttsVoiceName != previous.ttsVoiceName) {
      final voiceName = next.ttsVoiceName;
      unawaited(tts.setVoice(voiceName == null || voiceName.isEmpty
          ? null
          : TtsVoice(name: voiceName, locale: next.ttsLanguage)));
    }
    if (next.ttsPitch != previous.ttsPitch) {
      unawaited(tts.setPitch(next.ttsPitch));
    }
    if (next.ttsRate != previous.ttsRate) {
      unawaited(tts.setRate(next.ttsRate));
    }
  }

  /// Starts speaking the sentence that begins at the current global index.
  ///
  /// All async paths through this method check the generation counter on
  /// reentry: any call to `pause`, `stop`, `exitTtsMode`, `dispose`,
  /// `seekToWord`, or `enterEreaderMode` bumps the counter, so a stale
  /// `await` that finishes after the user changed their mind becomes a
  /// no-op. Without this guard, an awaited `setRate` could clobber state
  /// that pause() just cleared.
  Future<void> _startTtsSpeak() async {
    final tts = _tts;
    if (tts == null) return;
    if (state.mode != ReaderMode.tts || !state.isPlaying) return;

    _ttsSpeakGeneration++;
    final myGen = _ttsSpeakGeneration;

    // Skip past any image tokens at the current cursor (TTS doesn't speak
    // pictures, so the highlight just rolls forward silently).
    var startGlobal = state.globalWordIndex;
    while (startGlobal < state.totalWords) {
      final (cIdx, wIdx) = _globalToLocal(startGlobal);
      if (cIdx >= state.chapters.length) break;
      final tok = state.chapters[cIdx].tokens[wIdx];
      if (!tok.isImage) break;
      startGlobal++;
    }
    if (startGlobal >= state.totalWords) {
      // No more speakable tokens. Trigger the end-of-book celebration.
      state = state.copyWith(
        isPlaying: false,
        finishTicket: state.finishTicket + 1,
      );
      _flushSession();
      unawaited(_saveProgress());
      return;
    }

    // Surface the silent-image skip in the state so the highlight moves
    // even before the next progress callback fires.
    if (startGlobal != state.globalWordIndex) {
      _seekInternal(startGlobal);
    }

    final segment = extractSentenceFrom(state.chapters, startGlobal);
    if (segment == null || segment.isEmpty) {
      // Fall through: nothing to speak. Advance the cursor past whatever
      // range the segment covered and try the next chunk.
      final next = segment?.endGlobalIndexExcl ?? (startGlobal + 1);
      if (next >= state.totalWords) {
        state = state.copyWith(
          isPlaying: false,
          finishTicket: state.finishTicket + 1,
        );
        _flushSession();
        unawaited(_saveProgress());
        return;
      }
      _seekInternal(next);
      return _startTtsSpeak();
    }

    _currentTtsSentence = segment;

    // Apply rate just before speaking so a recent setTtsRate change lands
    // on this utterance. setRate is set-and-forget in the backends, so
    // it's safe to call every time.
    await tts.setRate(state.displaySettings.ttsRate);
    if (myGen != _ttsSpeakGeneration) return;
    if (!mounted) return;

    await tts.speak(segment.spokenText);
  }

  /// Progress callback wired up to the backend. [charOffset] is in chars
  /// (Linux) or UTF-16 code units (Android) — for the latin texts this app
  /// targets the two are interchangeable; if multi-byte text becomes
  /// common we can introduce a per-platform normaliser here.
  void _onTtsProgress(int charOffset, int charEnd, String word) {
    final segment = _currentTtsSentence;
    if (segment == null) return;
    if (state.mode != ReaderMode.tts || !state.isPlaying) return;

    final localIdx =
        charOffsetToTokenIndex(segment.tokenCharOffsets, charOffset);
    if (localIdx < 0) return;
    final targetGlobal = segment.tokenGlobalIndices[localIdx];
    if (targetGlobal > state.globalWordIndex &&
        targetGlobal < state.totalWords) {
      // Increment session-words counter for each advance so the flush
      // path reports a meaningful WPM (otherwise TTS sessions show 0).
      _wordsInSession += (targetGlobal - state.globalWordIndex);
      _seekInternal(targetGlobal);
    }
  }

  /// Completion callback. Advances past the spoken sentence and either
  /// queues the next one or bumps `finishTicket` when the book is done.
  void _onTtsCompletion() {
    final segment = _currentTtsSentence;
    _currentTtsSentence = null;
    if (state.mode != ReaderMode.tts) return;
    if (!state.isPlaying) return; // user paused in flight; nothing to do
    if (segment == null) return;

    final next = segment.endGlobalIndexExcl;

    // End-of-book — bump finishTicket via the same path as the RSVP
    // ticker so the completion screen lights up exactly once.
    if (next >= state.totalWords) {
      _wordsInSession += (state.totalWords - state.globalWordIndex);
      // Land the highlight on the last token before celebrating.
      if (state.totalWords > 0) {
        _seekInternal(state.totalWords - 1);
      }
      state = state.copyWith(
        isPlaying: false,
        finishTicket: state.finishTicket + 1,
      );
      _flushSession();
      _saveProgress();
      return;
    }

    _seekInternal(next);
    _startTtsSpeak();
  }

  /// Error callback. Stops playback and surfaces the error via the public
  /// `ttsErrorProvider` so the screen can show a snackbar. We don't crash
  /// — TTS errors are usually recoverable (engine not yet ready, locale
  /// unsupported) and the user can retry.
  void _onTtsError(String error) {
    _currentTtsSentence = null;
    if (state.isPlaying && state.mode == ReaderMode.tts) {
      state = state.copyWith(isPlaying: false);
      _flushSession();
      _saveProgress();
    }
    _ref.read(ttsErrorProvider.notifier).state = error;
  }

  /// Internal seek used by callbacks that already know exactly where to
  /// jump. Skips the debounce + sync push triggered by user-initiated
  /// `seekToWord` — callbacks fire fast enough that throttling those
  /// would hurt the highlight cadence.
  void _seekInternal(int targetGlobal) {
    if (targetGlobal < 0 || targetGlobal >= state.totalWords) return;
    final (cIdx, wIdx) = _globalToLocal(targetGlobal);
    state = state.copyWith(
      currentChapterIndex: cIdx,
      currentWordIndex: wIdx,
      globalWordIndex: targetGlobal,
      currentWord: state.chapters[cIdx].tokens[wIdx],
    );
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

    // Inline image at the new cursor. In RSVP we stop so the reader can
    // pan/zoom. In TTS we silently advance past it — audio doesn't
    // interrupt for figures.
    if (state.currentWord?.isImage ?? false) {
      if (state.mode == ReaderMode.tts) {
        // The TTS path manages its own progression via _startTtsSpeak's
        // image-skip; reaching here from the RSVP ticker while in TTS
        // mode shouldn't happen, but guard defensively.
        return;
      }
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
    // Stop any in-flight TTS but DON'T dispose the backend here — the
    // provider owns its lifecycle (it's a singleton across reader opens).
    if (state.mode == ReaderMode.tts && state.isPlaying) {
      _ttsSpeakGeneration++;
      unawaited(_tts?.stop());
    }
    // Detach the callbacks so a late completion doesn't try to drive a
    // disposed state notifier.
    final tts = _tts;
    if (tts != null) {
      tts.onProgress = null;
      tts.onCompletion = null;
      tts.onError = null;
      tts.onStart = null;
    }
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
