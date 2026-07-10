import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/flutter_tts_backend.dart';
import '../../data/services/speechd_socket_backend.dart';
import '../../data/services/tts_backend.dart';

/// Provides the single [TtsBackend] instance the engine uses. Selection by
/// platform:
///
/// - **Linux desktop**: [SpeechdSocketBackend] (persistent SSIP socket to
///   `speech-dispatcher`). When the daemon isn't running yet, the backend's
///   `init()` spawns it (as the old `spd-say` CLI did implicitly).
/// - **Everywhere else**: [FlutterTtsBackend].
///
/// The provider is `Provider` (not `autoDispose`) so the backend survives
/// reader re-mounts. The TTS player calls `dispose()` only when the app
/// shuts down — per-reader state lives on the engine notifier, not on the
/// backend.
final ttsBackendProvider = Provider<TtsBackend>((ref) {
  final backend = !kIsWeb && Platform.isLinux
      ? SpeechdSocketBackend()
      : FlutterTtsBackend();
  ref.onDispose(backend.dispose);
  return backend;
});
