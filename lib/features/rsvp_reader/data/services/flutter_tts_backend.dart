import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_backend.dart';

/// Converts our audiobook-style rate (1.0 = normal, range [0.5, 3.0]) to
/// the `flutter_tts` scale, where **0.5 is normal speed**: Android
/// multiplies the value by 2 before handing it to `setSpeechRate`, and iOS
/// maps 0.5 to `AVSpeechUtteranceDefaultSpeechRate`. Passing our value
/// through unconverted made every Android install speak at 2× — the
/// "bizarre chipmunk voice" bug.
///
/// Clamped to the plugin's own safe band ([0.1, 1.5] → native 0.2×–3×).
@visibleForTesting
double flutterTtsRate(double audiobookRate) =>
    (audiobookRate * 0.5).clamp(0.1, 1.5);

/// Backend on top of the `flutter_tts` package. Used on every platform the
/// package supports (Android, iOS, macOS, Windows, Web). Linux is
/// **unsupported** by `flutter_tts` and is handled by `SpeechdSocketBackend`
/// instead — `ttsBackendProvider` makes the switch.
///
/// Every operation that touches the plugin goes through [_enqueue], a
/// serialising queue. The plugin's Android side has a single-slot pending
/// `Result` for `setEngine` and drains queued calls against a
/// half-initialised client when two calls overlap — concurrent callers
/// (TtsPlayer applying settings + ttsVoicesProvider listing voices) used to
/// hang each other and corrupt engine state. With the queue plus the
/// [_activeEngineId] dedup, overlap simply cannot happen.
class FlutterTtsBackend implements TtsBackend {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _initFuture;
  TtsQueueMode _activeQueueMode = TtsQueueMode.flush;
  String? _activeEngineId;

  /// Tail of the serialising queue. Each public operation chains onto it;
  /// failures are swallowed from the chain (but surface to the caller) so
  /// one failed op doesn't poison every later one.
  Future<void> _serial = Future.value();

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final result = _serial.then((_) => op());
    _serial = result.then((_) {}, onError: (_) {});
    return result;
  }

  TtsProgressHandler? _onProgress;
  VoidCallback? _onCompletion;
  void Function(String)? _onError;

  bool get _initialised => _initFuture != null;

  @override
  Future<void> init() => _initFuture ??= _initImpl();

  Future<void> _initImpl() async {
    _tts.setProgressHandler((String text, int start, int end, String word) {
      _onProgress?.call(start, end, word);
    });
    _tts.setCompletionHandler(() {
      _onCompletion?.call();
    });
    _tts.setCancelHandler(() {
      // Cancellation is initiated by us (stop / re-speak / pause); we don't
      // surface it as completion. The caller already knows it stopped because
      // they're the one who called stop().
    });
    _tts.setErrorHandler((dynamic msg) {
      _onError?.call(msg?.toString() ?? 'Unknown TTS error');
    });

    // iOS / macOS: shared AVAudioSession with playback category so the audio
    // continues when the device is locked or the app is backgrounded. Without
    // playback + spokenAudio, the OS suspends the synthesiser as soon as the
    // screen turns off. Wrap in try/catch because the method-channel calls
    // are platform-specific and throw MissingPluginException elsewhere.
    try {
      await _tts.setSharedInstance(true);
    } catch (_) {}
    try {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    } catch (_) {}

    // Default volume to 1.0 — some Android devices ship with the TTS
    // volume at 0 if the user never used the system narrator. Without
    // this our `speak()` would succeed silently.
    try {
      await _tts.setVolume(1.0);
    } catch (_) {}

    // Don't call awaitSpeakCompletion(true). It makes `speak()` block
    // until the completion handler fires, which interacts badly with the
    // pipelined queue: the next `speak()` would be issued while the
    // previous call hasn't returned, and flutter_tts ends up with a
    // confused internal state. We treat `speak()` as fire-and-forget and
    // rely on the completion handler for sequencing.
  }

  @override
  Future<List<TtsVoice>> getVoices() => _enqueue(() async {
    await init();
    final raw = await _tts.getVoices;
    if (raw is! List) return const [];
    final voices = <TtsVoice>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString();
      final locale = entry['locale']?.toString();
      if (name == null || locale == null) continue;
      voices.add(TtsVoice(
        name: name,
        locale: locale,
        gender: entry['gender']?.toString(),
      ));
    }
    return voices;
  });

  @override
  Future<List<TtsEngine>> getEngines() => _enqueue(() async {
    await init();
    // `getEngines` is Android-only on flutter_tts. Other platforms throw
    // MissingPluginException or return null; we treat both as "no engine
    // selection available".
    try {
      final raw = await _tts.getEngines;
      if (raw is! List) return const [];
      return [
        for (final entry in raw)
          if (entry is String && entry.isNotEmpty)
            TtsEngine(id: entry, displayName: _humaniseEngineId(entry)),
      ];
    } catch (_) {
      return const [];
    }
  });

  @override
  Future<void> setEngine(String engineId) => _enqueue(() async {
    await init();
    if (engineId.isEmpty || engineId == _activeEngineId) return;
    try {
      // flutter_tts never stops or shuts down the outgoing native client on
      // an engine switch — anything still speaking would keep playing over
      // the new engine, and its late completion callbacks would pop our
      // player's queue. Silence it first.
      await _tts.stop();
      // The plugin's engine init can hang forever when its single pending
      // Result slot gets confused; the timeout keeps this queue (and the
      // player awaiting us) from wedging with it.
      await _tts.setEngine(engineId).timeout(const Duration(seconds: 8));
      _activeEngineId = engineId;
    } on MissingPluginException {
      // Platform without engine selection (iOS/macOS/Windows) — a synced
      // Android engine id is meaningless here; ignore.
    } catch (e) {
      _onError?.call('setEngine($engineId): $e');
    }
  });

  @override
  Future<void> setVoice(TtsVoice? voice) => _enqueue(() async {
    await init();
    if (voice == null) {
      // Reset to the active engine's default instead of silently keeping
      // whatever voice happens to be loaded (matters right after an engine
      // switch, where "no voice chosen" must mean the new engine's default).
      try {
        await _tts.clearVoice();
      } catch (_) {
        // Not implemented everywhere; the engine default is already active
        // on platforms that lack it.
      }
      return;
    }
    await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
  });

  @override
  Future<void> setLanguage(String iso) => _enqueue(() async {
    await init();
    await _tts.setLanguage(iso);
  });

  @override
  Future<void> setRate(double rate) => _enqueue(() async {
    await init();
    await _tts.setSpeechRate(flutterTtsRate(rate));
  });

  @override
  Future<void> setPitch(double pitch) => _enqueue(() async {
    await init();
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  });

  @override
  Future<void> speak(
    String text, {
    TtsQueueMode mode = TtsQueueMode.flush,
  }) => _enqueue(() async {
    await init();
    if (text.isEmpty) {
      // Nothing to say. Fire completion synthetically so callers don't
      // wait forever for a callback that never comes.
      _onCompletion?.call();
      return;
    }

    if (mode != _activeQueueMode) {
      try {
        await _tts.setQueueMode(mode == TtsQueueMode.add ? 1 : 0);
        _activeQueueMode = mode;
      } catch (_) {
        // setQueueMode isn't available on every flutter_tts platform; if it
        // throws we still speak — worst case the platform falls back to
        // flush semantics and the user hears a tiny gap.
      }
    }

    // Fire-and-forget: the engine sequences subsequent speaks through the
    // completion handler, so we don't need (or want) the inner Future to
    // suspend `speak()` until audio finishes. Awaiting here without
    // `awaitSpeakCompletion(true)` would resolve immediately anyway, but
    // we drop the await to make the intent obvious.
    unawaited(_tts.speak(text));
  });

  @override
  Future<void> stop() => _enqueue(() async {
    if (!_initialised) return;
    await _tts.stop();
  });

  @override
  Future<void> dispose() => _enqueue(() async {
    if (!_initialised) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _onProgress = null;
    _onCompletion = null;
    _onError = null;
    _initFuture = null;
    _activeEngineId = null;
  });

  @override
  set onProgress(TtsProgressHandler? cb) => _onProgress = cb;

  @override
  set onCompletion(VoidCallback? cb) => _onCompletion = cb;

  @override
  set onError(void Function(String error)? cb) => _onError = cb;
}

/// Best-effort prettifier for Android engine package names. Turns
/// `com.google.android.tts` into `Google TTS`, `com.samsung.SMT` into
/// `Samsung TTS`, and falls through to the raw id when the prefix isn't
/// recognised so the user can still tell engines apart.
String _humaniseEngineId(String id) {
  const known = <String, String>{
    'com.google.android.tts': 'Google',
    'com.samsung.SMT': 'Samsung',
    'com.svox.pico': 'Pico',
    'com.huawei.hiai': 'Huawei',
    'com.microsoft.cortana': 'Microsoft',
    'com.reecedunn.espeak': 'eSpeak',
    'es.codefactory.vocalizertts': 'Vocalizer',
    'com.acapelagroup.android.tts': 'Acapela',
  };
  final hit = known[id];
  if (hit != null) return '$hit TTS';
  // Take the last dotted component and Title-Case it.
  final tail = id.split('.').last;
  if (tail.isEmpty) return id;
  final cleaned = tail.replaceAll('_', ' ');
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}
