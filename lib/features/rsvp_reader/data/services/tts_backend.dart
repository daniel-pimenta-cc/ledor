import 'package:flutter/foundation.dart';

/// Engine-facing voice descriptor. Backends translate this to whatever shape
/// the underlying TTS engine expects (Map for `flutter_tts`, name + module
/// args for `spd-say`).
class TtsVoice {
  final String name;
  final String locale;
  final String? gender;

  /// Optional opaque ID the backend can use to round-trip selection through
  /// its own APIs. Not persisted — `ttsVoiceName` from `DisplaySettings`
  /// is the source of truth for what voice the user picked.
  final String? engineId;

  const TtsVoice({
    required this.name,
    required this.locale,
    this.gender,
    this.engineId,
  });
}

/// Thrown by `TtsBackend.init` when the platform's TTS stack is missing or
/// not configured (e.g. `spd-say` not on PATH on Linux). The reader UI
/// catches this to show a user-actionable message rather than crashing.
class TtsUnavailableException implements Exception {
  final String message;
  const TtsUnavailableException(this.message);

  @override
  String toString() => 'TtsUnavailableException: $message';
}

/// Callback signature for TTS progress events.
///
/// [charOffset] / [charEnd] are character positions inside the string passed
/// to [TtsBackend.speak]. The exact unit depends on the engine — Android
/// reports UTF-16 code units, iOS reports characters; for ASCII / common
/// Latin text they coincide. The engine implementation normalises this
/// where possible.
typedef TtsProgressHandler = void Function(
  int charOffset,
  int charEnd,
  String word,
);

/// Common interface for every TTS engine the reader knows about. Backends
/// are stateful (callbacks set via setters); a single instance is reused
/// for the whole life of the engine notifier and disposed when the
/// notifier disposes.
abstract class TtsBackend {
  /// Lazily wires up the underlying engine. Safe to call multiple times.
  /// Throws [TtsUnavailableException] when the platform stack isn't ready.
  Future<void> init();

  /// Returns the voices the engine knows about. May be empty (degraded
  /// path) — UI shows a "no voices available" message.
  Future<List<TtsVoice>> getVoices();

  /// Returns the locales the engine claims to support. May be empty.
  Future<List<String>> getLanguages();

  /// Selects the voice for subsequent [speak] calls. Pass `null` to clear
  /// (fall back to default for the current language).
  Future<void> setVoice(TtsVoice? voice);

  /// Sets the BCP-47 / ISO locale.
  Future<void> setLanguage(String iso);

  /// Speech rate. Caller passes the engine-agnostic value in `[0.3, 2.5]`
  /// (relative to a nominal 200 WPM). Implementations map to platform-
  /// specific units (e.g. `spd-say -r` is in `[-100, +100]`).
  Future<void> setRate(double rate);

  /// Voice pitch. Caller passes `[0.5, 2.0]`.
  Future<void> setPitch(double pitch);

  /// Speaks [text]. Returns once the request has been accepted; emission of
  /// the audio happens asynchronously and is observable through
  /// [onCompletion] / [onError] / [onProgress].
  Future<void> speak(String text);

  /// Cancels any in-flight speech. Safe to call when idle.
  Future<void> stop();

  /// Releases native resources. After this the backend is unusable.
  Future<void> dispose();

  set onProgress(TtsProgressHandler? cb);
  set onCompletion(VoidCallback? cb);
  set onError(void Function(String error)? cb);
  set onStart(VoidCallback? cb);
}
