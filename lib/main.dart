import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'core/utils/platform_capabilities.dart';
import 'database/app_database.dart';
import 'features/library_sync/presentation/providers/drive_auth_provider.dart';
import 'features/library_sync/presentation/providers/library_sync_provider.dart';
import 'features/library_sync/presentation/providers/sync_config_provider.dart';
import 'features/rsvp_reader/data/services/tts_audio_handler.dart';
import 'features/rsvp_reader/presentation/providers/display_settings_provider.dart';
import 'features/rsvp_reader/presentation/providers/tts_audio_handler_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load secrets (currently only the desktop OAuth credentials) before
  // anything reads PlatformCapabilities.supportsDriveSync. The .env file
  // is bundled as an asset; missing/empty is fine on platforms that
  // don't need it.
  await dotenv.load(fileName: '.env', isOptional: true);

  if (PlatformCapabilities.isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  final dbDir = await getApplicationDocumentsDirectory();
  // Filename predates the Ledor rename. Kept as-is on purpose: on Linux this
  // lives in ~/Documents and renaming it would orphan existing databases.
  final dbFile = File('${dbDir.path}/rsvp_reader.db');
  final database = AppDatabase(
    NativeDatabase.createInBackground(dbFile),
  );

  // Spin up the media-session bridge on platforms that support background
  // audio. The handler is a long-lived singleton — engines bind/unbind
  // themselves as the user navigates between books. Linux / Web skip this
  // (audio_service has no implementation there).
  //
  // Intencionalmente NÃO aguardado: o init faz IPC com o MediaSession do
  // Android e segurava o primeiro frame do app. Engines aguardam o future
  // só na hora do bind (entrada em modo TTS), bem depois do startup.
  Future<TtsAudioHandler?> audioHandlerFuture = Future.value(null);
  if (PlatformCapabilities.supportsBackgroundAudio) {
    audioHandlerFuture = AudioService.init(
      builder: () => TtsAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.pimenta.ledor.tts',
        androidNotificationChannelName: 'TTS playback',
        androidNotificationChannelDescription:
            'Controls for the TTS narration',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFFE55324),
      ),
    ).then<TtsAudioHandler?>((h) => h).catchError((Object _) => null);
  }

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      ttsAudioHandlerProvider.overrideWithValue(audioHandlerFuture),
    ],
  );

  // Fire an initial sync on startup if the user has configured a folder.
  // We need to wait for SyncConfigNotifier.load() to finish first.
  if (PlatformCapabilities.supportsDriveSync) {
    unawaited(_initialSync(container));
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RsvpReaderApp(),
    ),
  );
}

Future<void> _initialSync(ProviderContainer container) async {
  final configNotifier = container.read(syncConfigProvider.notifier);
  while (!configNotifier.isLoaded) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (!container.read(syncConfigProvider).isActive) return;

  // Restore the previous Google session silently; without a signed-in
  // user the sync provider is a no-op and we'd just burn the startup.
  final signedIn =
      await container.read(driveAuthProvider.notifier).trySilentSignIn();
  if (!signedIn) return;

  // Wait for local display settings to load before we snapshot them for the
  // push — otherwise the service would read the defaulted initial state
  // (const DisplaySettings()) and overwrite the remote's real values.
  await container.read(displaySettingsProvider.notifier).load();

  await container.read(librarySyncProvider.notifier).triggerSync();
}
