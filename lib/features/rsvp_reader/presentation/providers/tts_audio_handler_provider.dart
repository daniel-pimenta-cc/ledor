import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/tts_audio_handler.dart';

/// Future of the [TtsAudioHandler] singleton, or `null` on platforms
/// without background audio (Linux / Web). `main.dart` kicks off
/// `AudioService.init` WITHOUT awaiting it (so it doesn't hold the app's
/// first frame) and overrides this provider with the resulting future;
/// unsupported platforms keep the default, already resolved to `null`.
///
/// Engine notifiers await the future when binding (entering TTS mode) — in
/// practice init finished long before that. If the handler is `null`, the
/// engine keeps working without the lockscreen/foreground-service
/// integration.
final ttsAudioHandlerProvider =
    Provider<Future<TtsAudioHandler?>>((_) => Future.value(null));
