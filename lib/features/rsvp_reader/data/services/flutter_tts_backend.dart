import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_backend.dart';

/// Backend on top of the `flutter_tts` package. Used on every platform the
/// package supports (Android, iOS, macOS, Windows, Web). Linux is
/// **unsupported** by `flutter_tts` and is handled by `SpeechdSocketBackend`
/// (or the legacy `SpeechDispatcherBackend`) instead — `ttsBackendProvider`
/// makes the switch.
class FlutterTtsBackend implements TtsBackend {
  final FlutterTts _tts = FlutterTts();
  bool _initialised = false;
  TtsQueueMode _activeQueueMode = TtsQueueMode.flush;

  @override
  bool get canPipeline => true;

  TtsProgressHandler? _onProgress;
  VoidCallback? _onCompletion;
  void Function(String)? _onError;
  VoidCallback? _onStart;

  @override
  Future<void> init() async {
    if (_initialised) return;

    _tts.setProgressHandler((String text, int start, int end, String word) {
      _onProgress?.call(start, end, word);
    });
    _tts.setStartHandler(() {
      _onStart?.call();
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

    _initialised = true;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
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
  }

  @override
  Future<List<String>> getLanguages() async {
    await init();
    final raw = await _tts.getLanguages;
    if (raw is! List) return const [];
    return [for (final lang in raw) lang.toString()];
  }

  @override
  Future<List<TtsEngine>> getEngines() async {
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
  }

  @override
  Future<void> setEngine(String engineId) async {
    await init();
    if (engineId.isEmpty) return;
    try {
      await _tts.setEngine(engineId);
    } catch (_) {
      // Older Android versions or non-Android platforms may not implement
      // setEngine; swallow so a synced value from another device doesn't
      // crash the reader.
    }
  }

  @override
  Future<void> setVoice(TtsVoice? voice) async {
    await init();
    if (voice == null) return;
    await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
  }

  @override
  Future<void> setLanguage(String iso) async {
    await init();
    await _tts.setLanguage(iso);
  }

  @override
  Future<void> setRate(double rate) async {
    await init();
    // flutter_tts treats 0.5 as default in some versions; modern versions
    // accept values up to ~2.0 reliably. Clamp to a safe band so engines
    // don't reject the call.
    final clamped = rate.clamp(0.1, 2.0);
    await _tts.setSpeechRate(clamped);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await init();
    final clamped = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(clamped);
  }

  @override
  Future<void> speak(
    String text, {
    TtsQueueMode mode = TtsQueueMode.flush,
  }) async {
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
  }

  @override
  Future<void> stop() async {
    if (!_initialised) return;
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    if (!_initialised) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _onProgress = null;
    _onCompletion = null;
    _onError = null;
    _onStart = null;
    _initialised = false;
  }

  @override
  set onProgress(TtsProgressHandler? cb) => _onProgress = cb;

  @override
  set onCompletion(VoidCallback? cb) => _onCompletion = cb;

  @override
  set onError(void Function(String error)? cb) => _onError = cb;

  @override
  set onStart(VoidCallback? cb) => _onStart = cb;
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
