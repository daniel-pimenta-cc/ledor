import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/tts_audio_handler.dart';

/// Provides the singleton [TtsAudioHandler], or `null` on platforms that
/// don't support background audio (Linux / Web). `main.dart` overrides
/// this with the instance returned by `AudioService.init` on supported
/// platforms; other platforms keep the default `null`.
///
/// Engine notifiers check the provider for null before binding/unbinding
/// — if there's no handler, the engine still works but the lockscreen
/// + foreground-service integration is skipped.
final ttsAudioHandlerProvider = Provider<TtsAudioHandler?>((_) => null);
