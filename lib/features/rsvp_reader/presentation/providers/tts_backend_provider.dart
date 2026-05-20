import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/flutter_tts_backend.dart';
import '../../data/services/speech_dispatcher_backend.dart';
import '../../data/services/tts_backend.dart';

/// Provides the single [TtsBackend] instance the engine uses. Selection by
/// platform: Linux desktop uses `spd-say`, everything else uses the
/// `flutter_tts` package.
///
/// The provider is `Provider` (not `autoDispose`) so the backend survives
/// reader re-mounts. The engine notifier calls `dispose()` when it itself
/// disposes — the provider doesn't own lifecycle beyond construction.
final ttsBackendProvider = Provider<TtsBackend>((ref) {
  if (!kIsWeb && Platform.isLinux) {
    final backend = SpeechDispatcherBackend();
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
