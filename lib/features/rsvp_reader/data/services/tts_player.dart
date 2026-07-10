import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../epub_import/domain/entities/chapter.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/sentence_segment.dart';
import '../../domain/utils/sentence_extractor.dart';
import 'tts_backend.dart';

/// Pipelined wrapper around a [TtsBackend].
///
/// Pre-extracts the next [_lookahead] segments and enqueues them on the
/// backend with [TtsQueueMode.add] so the platform engine plays them
/// back-to-back with no audible gap. Without this, every chunk boundary
/// introduced a ~200–500ms IPC gap on Android (the time between the
/// completion handler firing and the next `speak()` being processed).
///
/// Responsibilities (vs the engine notifier):
/// - Owns the queue of in-flight + queued segments.
/// - Owns the cursor inside the spoken text (the engine subscribes via
///   [onWordAdvance] to keep `RsvpState.globalWordIndex` in sync).
/// - Owns the backend's progress / completion / error callbacks.
/// - Does **not** manage reading sessions, persistence, or display state —
///   those stay with the engine.
class TtsPlayer {
  final TtsBackend _backend;

  // ---- Content + settings ----
  List<Chapter> _chapters = const [];
  int _totalWords = 0;
  DisplaySettings _settings = const DisplaySettings();

  // Per-field snapshot of what the backend last accepted. Sentinel "_unset"
  // strings would be neater but the platform APIs never return null and
  // these getters are read on every settings push, so the extra
  // wrapping isn't worth it. Each field advances independently inside
  // [_applySettingsIfChanged] so a half-applied snapshot doesn't force
  // every later call to re-push everything.
  String? _appliedEngineId;
  String? _appliedLanguage;
  String? _appliedVoiceName;
  double? _appliedPitch;
  double? _appliedRate;
  bool _hasAppliedAny = false;

  // ---- Callbacks the owner subscribes to ----

  /// Fires whenever the cursor advances inside the spoken text.
  /// [newGlobalIndex] is the latest word index; [wordsAdvanced] is the
  /// number of words crossed since the previous call (≥ 1 for normal
  /// progress, larger for image-only ranges that were skipped silently).
  void Function(int newGlobalIndex, int wordsAdvanced)? onWordAdvance;

  /// Fires once when the last segment of the book finishes playing.
  VoidCallback? onBookFinished;

  /// Fires when the backend reports a fatal error. The player has already
  /// stopped + cleared its queue by the time this callback runs.
  void Function(String error)? onError;

  // ---- Internal state ----
  final Queue<_QueuedSegment> _queue = Queue();
  int _currentGlobalIndex = 0;
  bool _isPlaying = false;
  bool _initialised = false;

  /// Bumped on every action that should invalidate in-flight callbacks
  /// (`pause`, `stop`, `seek`, `dispose`, `play`). Each queued segment
  /// captures the generation in which it was enqueued; stale completion /
  /// progress callbacks compare against the live counter and bail.
  int _generation = 0;

  /// Lookahead depth: 2 = one segment playing + one pre-queued so the
  /// platform engine (flutter_tts queueMode=1 / speech-dispatcher daemon
  /// socket) stitches them gap-free. Deeper helps nothing (the gap appears
  /// at every queue boundary, not just the second) and makes `stop()` slower.
  static const int _lookahead = 2;

  /// Wall-clock timestamp of the last progress callback we received from
  /// the backend. Used by [restartIfStalled] to detect a backend that
  /// went silent (e.g. Android killed the synth while the foreground
  /// service was misconfigured). `null` until the first callback fires.
  DateTime? _lastProgressAt;

  /// Threshold for [restartIfStalled]: after this long without a progress
  /// callback while `_isPlaying`, assume the backend is dead.
  static const _stallThreshold = Duration(seconds: 10);

  TtsPlayer(this._backend);

  /// Lazily wires up the backend and subscribes to its callbacks. Safe to
  /// call multiple times. Re-throws any [TtsUnavailableException] the
  /// backend raises so the caller can show a user-actionable message.
  Future<void> init() async {
    if (_initialised) return;
    await _backend.init();
    _backend.onProgress = _onProgress;
    _backend.onCompletion = _onCompletion;
    _backend.onError = _onErrorInternal;
    _initialised = true;
  }

  /// Replaces the book content the player will read.
  void setContent(List<Chapter> chapters, int totalWords) {
    _chapters = chapters;
    _totalWords = totalWords;
  }

  /// Replaces the player's settings snapshot. Settings are applied to the
  /// backend on the next [play]; rate changes also propagate immediately
  /// to the next utterance through [setRate].
  void setSettings(DisplaySettings settings) {
    _settings = settings;
  }

  /// Pushes the current settings snapshot to the backend right now.
  /// Useful right after init / mode entry so a subsequent voice preview
  /// (or the engine's own first speak) starts with the user's choices
  /// already in place — no need to wait for [play] to fire `setEngine` /
  /// `setLanguage` etc.
  ///
  /// No-op when the backend isn't initialised yet.
  Future<void> applySettings() async {
    if (!_initialised) return;
    await _applySettingsIfChanged();
  }

  /// Updates only the speech rate, propagating immediately to the backend
  /// so the next utterance (including any already queued via lookahead)
  /// picks it up. The rest of the settings are unchanged.
  Future<void> setRate(double rate) async {
    _settings = _settings.copyWith(ttsRate: rate);
    if (!_initialised) return;
    // Dedup via _appliedRate so a slider that re-emits the same value
    // (common with the capsule's stepper) doesn't burn IPC.
    if (_appliedRate == rate) return;
    await _backend.setRate(rate);
    _appliedRate = rate;
  }

  /// Starts playback from [fromGlobalIndex]. Applies the current settings
  /// to the backend before issuing the first `speak()`, then fills the
  /// pipeline with [_lookahead] queued segments so the platform engine
  /// stitches them together seamlessly.
  ///
  /// `_isPlaying` is set to `true` **synchronously** before any `await`
  /// so a `pause()` issued in the same tick (typical when the user taps
  /// pause right after play) sees the right state and actually stops the
  /// backend.
  Future<void> play({required int fromGlobalIndex}) async {
    if (_isPlaying) return;
    if (_totalWords == 0 || _chapters.isEmpty) return;

    _isPlaying = true;
    _generation++;
    final myGen = _generation;
    _currentGlobalIndex = fromGlobalIndex.clamp(0, _totalWords - 1);

    try {
      await init();
    } catch (e) {
      _isPlaying = false;
      onError?.call(e.toString());
      return;
    }
    if (myGen != _generation) return;

    await _applySettingsIfChanged();
    if (myGen != _generation) return;

    for (var i = 0; i < _lookahead; i++) {
      final more = await _enqueueNext();
      if (myGen != _generation) return;
      if (!more) break;
    }
  }

  /// Stops the backend and drains the local queue. Idempotent.
  Future<void> pause() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    _generation++;
    _queue.clear();
    // Clear the heartbeat so a subsequent restartIfStalled doesn't fire
    // because of a stale "no progress for 10s" reading from before the
    // pause.
    _lastProgressAt = null;
    if (_initialised) {
      try {
        await _backend.stop();
      } catch (_) {
        // stop() failures don't have a clean recovery — log and move on.
      }
    }
  }

  /// Moves the cursor to [globalIndex]. If the player was playing, the
  /// pipeline is rebuilt from the new position; if paused, only the cursor
  /// moves and the next [play] will pick up the new index.
  Future<void> seek(int globalIndex) async {
    final clamped = globalIndex.clamp(0, _totalWords == 0 ? 0 : _totalWords - 1);
    if (_isPlaying) {
      await pause();
      _currentGlobalIndex = clamped;
      await play(fromGlobalIndex: clamped);
    } else {
      _currentGlobalIndex = clamped;
    }
  }

  /// Restarts playback from the current cursor when the backend has fallen
  /// silent unexpectedly (e.g. Android killed the synthesiser while the
  /// app was backgrounded without a foreground service). Detects stalls
  /// via lack of recent progress callbacks rather than queue depth — a
  /// killed backend can leave the queue full but never fire completion.
  /// Idempotent — safe to call when the player is healthy.
  Future<void> restartIfStalled() async {
    if (!_isPlaying) return;
    final last = _lastProgressAt;
    // Restart only when we've actually heard progress before AND it's
    // gone silent for too long. `last == null` means either the backend
    // hasn't started speaking yet (give it more time) or pause() just
    // cleared the heartbeat — neither warrants a restart.
    if (last == null) return;
    if (DateTime.now().difference(last) < _stallThreshold) return;

    final cursor = _currentGlobalIndex;
    _isPlaying = false; // play() refuses when already playing
    _queue.clear();
    // A stall usually means the OS killed and recreated the native synth,
    // which comes back with default voice/language/rate — force a full
    // settings re-push instead of trusting the _applied* snapshot.
    _hasAppliedAny = false;
    try {
      await _backend.stop();
    } catch (_) {}
    await play(fromGlobalIndex: cursor);
  }

  Future<void> dispose() async {
    _isPlaying = false;
    _generation++;
    _queue.clear();
    if (_initialised) {
      try {
        await _backend.stop();
      } catch (_) {}
      // Detach callbacks so a late event from the platform layer doesn't
      // try to drive a disposed player.
      _backend.onProgress = null;
      _backend.onCompletion = null;
      _backend.onError = null;
    }
  }

  // ---- Internals ----

  /// Pushes every setting that differs from the per-field `_applied*`
  /// snapshot to the backend, advancing each snapshot field after its
  /// `await` succeeds. Each `await` checks the generation counter so a
  /// concurrent [pause] / [seek] / [dispose] aborts cleanly.
  ///
  /// The per-field snapshot (vs a single struct) means a half-applied
  /// state doesn't force every later call to re-push everything — only
  /// the fields that genuinely differ get an IPC roundtrip.
  Future<void> _applySettingsIfChanged() async {
    final s = _settings;
    final myGen = _generation;
    final firstApply = !_hasAppliedAny;

    // Switching engines (Android: flutter_tts tears down and rebuilds the
    // platform TTS client) silently resets voice/language/pitch/rate to the
    // new engine's defaults, so a change here forces every later block to
    // re-push even when the `_applied*` snapshot says the value is current.
    var engineChanged = false;
    if (firstApply || _appliedEngineId != s.ttsEngineId) {
      final eng = s.ttsEngineId;
      if (eng != null && eng.isNotEmpty) {
        await _backend.setEngine(eng);
        if (myGen != _generation) return;
        engineChanged = !firstApply;
      }
      _appliedEngineId = s.ttsEngineId;
    }
    if (firstApply || engineChanged || _appliedLanguage != s.ttsLanguage) {
      await _backend.setLanguage(s.ttsLanguage);
      if (myGen != _generation) return;
      _appliedLanguage = s.ttsLanguage;
    }
    if (firstApply || engineChanged || _appliedVoiceName != s.ttsVoiceName) {
      final name = s.ttsVoiceName;
      if (name == null || name.isEmpty) {
        await _backend.setVoice(null);
      } else {
        await _backend.setVoice(TtsVoice(name: name, locale: s.ttsLanguage));
      }
      if (myGen != _generation) return;
      _appliedVoiceName = s.ttsVoiceName;
    }
    if (firstApply || engineChanged || _appliedPitch != s.ttsPitch) {
      await _backend.setPitch(s.ttsPitch);
      if (myGen != _generation) return;
      _appliedPitch = s.ttsPitch;
    }
    if (firstApply || engineChanged || _appliedRate != s.ttsRate) {
      await _backend.setRate(s.ttsRate);
      if (myGen != _generation) return;
      _appliedRate = s.ttsRate;
    }
    _hasAppliedAny = true;
  }

  /// Pulls the next speakable segment off the book and pushes it onto the
  /// backend's queue. Returns false when end-of-book is reached.
  ///
  /// All-image ranges are silently advanced past (the cursor jumps; the
  /// highlight rolls forward without audio).
  Future<bool> _enqueueNext() async {
    final myGen = _generation;
    final startIdx = _queue.isEmpty
        ? _currentGlobalIndex
        : _queue.last.segment.endGlobalIndexExcl;

    if (startIdx >= _totalWords) return false;

    final segment = extractSentenceFrom(_chapters, startIdx);
    if (segment == null) return false;
    if (segment.isEmpty) {
      // Range was all image tokens. Advance cursor past it; no speak().
      if (_currentGlobalIndex < segment.endGlobalIndexExcl) {
        final advance = segment.endGlobalIndexExcl - _currentGlobalIndex;
        _currentGlobalIndex = segment.endGlobalIndexExcl;
        onWordAdvance?.call(_currentGlobalIndex, advance);
      }
      if (myGen != _generation) return false;
      return _enqueueNext();
    }

    _queue.add(_QueuedSegment(segment, myGen));

    // First in the queue → flush; subsequent → add (pipelined). Settings
    // (rate included) were applied via _applySettingsIfChanged earlier in
    // [play] and stay in sync via [setRate] when the user changes them
    // mid-flight, so we don't re-push them per segment.
    final mode = _queue.length == 1 ? TtsQueueMode.flush : TtsQueueMode.add;
    await _backend.speak(segment.spokenText, mode: mode);
    return true;
  }

  void _onProgress(int charOffset, int charEnd, String word) {
    if (!_isPlaying) return;
    // Heartbeat for restartIfStalled — record even when the line below
    // bails out, since a too-early or out-of-range callback still proves
    // the backend is alive.
    _lastProgressAt = DateTime.now();
    if (_queue.isEmpty) return;
    final active = _queue.first;
    if (active.generation != _generation) return;

    final segment = active.segment;
    final localIdx =
        charOffsetToTokenIndex(segment.tokenCharOffsets, charOffset);
    if (localIdx < 0) return;
    final targetGlobal = segment.tokenGlobalIndices[localIdx];
    if (targetGlobal > _currentGlobalIndex && targetGlobal < _totalWords) {
      final advance = targetGlobal - _currentGlobalIndex;
      _currentGlobalIndex = targetGlobal;
      onWordAdvance?.call(_currentGlobalIndex, advance);
    }
  }

  void _onCompletion() {
    if (!_isPlaying) return;
    if (_queue.isEmpty) return;
    final finished = _queue.removeFirst();
    if (finished.generation != _generation) return;

    final endIdx = finished.segment.endGlobalIndexExcl;
    if (endIdx >= _totalWords) {
      _isPlaying = false;
      _queue.clear();
      // Land the cursor on the very last word for a clean visual end.
      if (_totalWords > 0 && _currentGlobalIndex < _totalWords - 1) {
        final advance = _totalWords - 1 - _currentGlobalIndex;
        _currentGlobalIndex = _totalWords - 1;
        onWordAdvance?.call(_currentGlobalIndex, advance);
      }
      onBookFinished?.call();
      return;
    }

    // Cursor may still be inside the just-finished segment if the engine
    // didn't fire a progress callback on the final token (some engines
    // skip the last word). Align it to the segment end so the next
    // segment starts with a clean handoff.
    if (_currentGlobalIndex < endIdx) {
      final advance = endIdx - _currentGlobalIndex;
      _currentGlobalIndex = endIdx;
      onWordAdvance?.call(_currentGlobalIndex, advance);
    }

    // Refill the pipeline so the next segment is queued ahead of time.
    unawaited(_enqueueNext());
  }

  void _onErrorInternal(String error) {
    _isPlaying = false;
    _queue.clear();
    onError?.call(error);
  }
}

class _QueuedSegment {
  final SentenceSegment segment;
  final int generation;
  _QueuedSegment(this.segment, this.generation);
}
