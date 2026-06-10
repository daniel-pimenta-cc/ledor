import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/tts_audio_handler.dart';

/// Future do singleton [TtsAudioHandler], ou `null` em plataformas sem
/// background audio (Linux / Web). `main.dart` dispara `AudioService.init`
/// SEM aguardar (pra não segurar o primeiro frame do app) e faz override
/// deste provider com o future resultante; plataformas não suportadas
/// mantêm o default já resolvido em `null`.
///
/// Engine notifiers aguardam o future na hora de fazer o bind (entrada em
/// modo TTS) — na prática o init já terminou muito antes disso. Se o
/// handler for `null`, o engine segue funcionando sem a integração de
/// lockscreen/foreground-service.
final ttsAudioHandlerProvider =
    Provider<Future<TtsAudioHandler?>>((_) => Future.value(null));
