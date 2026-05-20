import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../features/library_sync/data/auth/desktop_oauth_drive_auth_backend.dart';

/// Static checks for platform-specific capabilities. Use these instead of
/// scattering `Platform.isAndroid` / `Platform.isLinux` across the codebase.
class PlatformCapabilities {
  PlatformCapabilities._();

  /// `receive_sharing_intent` only ships Android + iOS bindings.
  static bool get supportsShareIntent {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Drive sync. Both Android and Linux now need the same Web Application
  /// OAuth client_id in `.env` — Android uses it via `serverClientId` in
  /// google_sign_in so file visibility (drive.file scope is per-client_id)
  /// matches the desktop. Without credentials the section is hidden.
  /// iOS would need a separate provisioning profile and is not wired up.
  static bool get supportsDriveSync {
    if (kIsWeb) return false;
    if (Platform.isAndroid) return desktopOAuthCredentialsConfigured;
    if (Platform.isLinux) return desktopOAuthCredentialsConfigured;
    return false;
  }

  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  }

  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Text-to-speech reader mode. Android/iOS/macOS/Windows use the
  /// `flutter_tts` package; Linux desktop uses a custom backend on top of
  /// `spd-say` (speech-dispatcher). On platforms where neither is wired up
  /// (currently just web) the mode is hidden from the reader.
  static bool get supportsTts {
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isWindows;
  }
}
