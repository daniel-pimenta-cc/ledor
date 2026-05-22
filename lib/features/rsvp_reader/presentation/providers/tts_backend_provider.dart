import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/flutter_tts_backend.dart';
import '../../data/services/speech_dispatcher_backend.dart';
import '../../data/services/speechd_socket_backend.dart';
import '../../data/services/tts_backend.dart';

/// Provides the single [TtsBackend] instance the engine uses. Selection by
/// platform:
///
/// - **Linux desktop**: [SpeechdSocketBackend] (persistent SSIP socket to
///   `speech-dispatcher`). When the daemon socket isn't present we fall back
///   to [SpeechDispatcherBackend] (`spd-say` CLI), which has higher per-chunk
///   latency but doesn't require a running daemon socket.
/// - **Everywhere else**: [FlutterTtsBackend].
///
/// The provider is `Provider` (not `autoDispose`) so the backend survives
/// reader re-mounts. The TTS player calls `dispose()` only when the app
/// shuts down — per-reader state lives on the engine notifier, not on the
/// backend.
final ttsBackendProvider = Provider<TtsBackend>((ref) {
  if (!kIsWeb && Platform.isLinux) {
    // Prefer the socket backend; it lets the daemon queue utterances
    // back-to-back with no gap. Only fall through to spd-say when the
    // socket genuinely isn't there.
    final backend = _hasSpeechdSocket()
        ? SpeechdSocketBackend()
        : SpeechDispatcherBackend();
    ref.onDispose(() {
      backend.dispose();
    });
    return backend;
  }
  final backend = FlutterTtsBackend();
  ref.onDispose(() {
    backend.dispose();
  });
  return backend;
});

bool _hasSpeechdSocket() {
  final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
  if (runtimeDir != null && runtimeDir.isNotEmpty) {
    if (File('$runtimeDir/speech-dispatcher/speechd.sock').existsSync()) {
      return true;
    }
  }
  if (File('/var/run/speech-dispatcher/speechd.sock').existsSync()) {
    return true;
  }
  if (File('/tmp/speech-dispatcher/speechd.sock').existsSync()) {
    return true;
  }
  return false;
}
