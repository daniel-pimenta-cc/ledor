import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as ga;

const oauthClientIdKey = 'RSVP_OAUTH_CLIENT_ID';
const oauthClientSecretKey = 'RSVP_OAUTH_CLIENT_SECRET';

String envOrEmpty(String key) => dotenv.maybeGet(key) ?? '';

/// Platform-agnostic surface for Google Drive authentication. The
/// [DriveAuthNotifier] only talks to this interface; concrete
/// implementations handle the platform specifics (native Android sheet,
/// desktop OAuth loopback, etc.).
///
/// Credential storage and the auto-refreshing client lifecycle are shared
/// here; subclasses implement only their sign-in flow ([trySilentSignIn] /
/// [signIn]) via the protected [attachClient]/[persistSession]/
/// [loadStoredSession] helpers.
abstract class DriveAuthBackend {
  static const _credsKey = 'drive_auth.credentials';
  static const _emailKey = 'drive_auth.email';
  static const scopes = <String>[
    drive.DriveApi.driveFileScope,
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  final String clientId;
  final String clientSecret;
  final FlutterSecureStorage storage;

  ga.AutoRefreshingAuthClient? _client;
  StreamSubscription<ga.AccessCredentials>? _credsSub;

  DriveAuthBackend({
    String? clientId,
    String? clientSecret,
    FlutterSecureStorage? storage,
  })  : clientId = clientId ?? envOrEmpty(oauthClientIdKey),
        clientSecret = clientSecret ?? envOrEmpty(oauthClientSecretKey),
        storage = storage ?? const FlutterSecureStorage();

  ga.ClientId get clientIdObj => ga.ClientId(clientId, clientSecret);

  bool get hasCredentials => clientId.isNotEmpty && clientSecret.isNotEmpty;

  /// Try to restore a previous session without UI. Returns the email
  /// when successful, null otherwise. Must never throw.
  Future<String?> trySilentSignIn();

  /// Interactive sign-in. Returns the email on success, null if the
  /// user cancelled. Throws on hard errors so the caller can surface them.
  Future<String?> signIn();

  /// Wipe local credentials so the next [signIn] starts fresh.
  Future<void> signOut() async {
    await _credsSub?.cancel();
    _credsSub = null;
    _client?.close();
    _client = null;
    await storage.delete(key: _credsKey);
    await storage.delete(key: _emailKey);
  }

  /// Returns an authenticated HTTP client with the Drive scope. Null when
  /// there is no current session or the cached refresh token is no longer
  /// valid.
  Future<ga.AuthClient?> authenticatedClient() async => _client;

  /// Adopts [client] as the current session, closing any previous one and
  /// re-persisting credentials on every auto-refresh.
  void attachClient(ga.AutoRefreshingAuthClient client) {
    _credsSub?.cancel();
    _client?.close();
    _client = client;
    _credsSub =
        client.credentialUpdates.listen(persistCredentials, onError: (_) {});
  }

  Future<void> persistCredentials(ga.AccessCredentials creds) {
    return storage.write(key: _credsKey, value: jsonEncode(creds.toJson()));
  }

  /// Persist both the credentials and the connected [email] after a
  /// successful sign-in.
  Future<void> persistSession(ga.AccessCredentials creds, String email) async {
    await persistCredentials(creds);
    await storage.write(key: _emailKey, value: email);
  }

  /// Reads the stored `(creds, email)` pair, or null when either is missing.
  Future<({String creds, String email})?> loadStoredSession() async {
    final creds = await storage.read(key: _credsKey);
    final email = await storage.read(key: _emailKey);
    if (creds == null || email == null) return null;
    return (creds: creds, email: email);
  }
}
