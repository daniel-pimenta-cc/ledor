import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as ga;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'drive_auth_backend.dart';

/// OAuth credentials are loaded from `.env` (bundled as an asset). They
/// must come from a "Web application" client in Google Cloud Console with
/// `http://127.0.0.1` listed as an authorized redirect URI. The same
/// client_id is reused by the Android backend (via google_sign_in's
/// `serverClientId`) so Drive's `drive.file` scope sees the same folder
/// on both platforms.
const _clientIdKey = 'RSVP_OAUTH_CLIENT_ID';
const _clientSecretKey = 'RSVP_OAUTH_CLIENT_SECRET';

String _envOrEmpty(String key) => dotenv.maybeGet(key) ?? '';

/// Whether the build was provisioned with desktop OAuth credentials.
/// Requires that `dotenv.load()` has already run (see `main.dart`).
bool get desktopOAuthCredentialsConfigured =>
    _envOrEmpty(_clientIdKey).isNotEmpty &&
    _envOrEmpty(_clientSecretKey).isNotEmpty;

/// Linux/macOS/Windows backend. Drives the OAuth 2.0 "installed app" flow:
/// opens the user's default browser, listens on a loopback port, captures
/// the redirected auth code, exchanges it for tokens, and persists the
/// refresh token via [FlutterSecureStorage] (libsecret on Linux).
class DesktopOAuthDriveAuthBackend implements DriveAuthBackend {
  static const _credsKey = 'drive_auth.credentials';
  static const _emailKey = 'drive_auth.email';
  // `userinfo.email` is needed for the OIDC userinfo endpoint we use to
  // surface the connected account in Settings.
  static const _scopes = <String>[
    drive.DriveApi.driveFileScope,
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  final String _clientId;
  final String _clientSecret;
  final FlutterSecureStorage _storage;

  ga.AutoRefreshingAuthClient? _client;
  StreamSubscription<ga.AccessCredentials>? _credsSub;

  DesktopOAuthDriveAuthBackend({
    String? clientId,
    String? clientSecret,
    FlutterSecureStorage? storage,
  })  : _clientId = clientId ?? _envOrEmpty(_clientIdKey),
        _clientSecret = clientSecret ?? _envOrEmpty(_clientSecretKey),
        _storage = storage ?? const FlutterSecureStorage();

  ga.ClientId get _clientIdObj => ga.ClientId(_clientId, _clientSecret);

  bool get _hasCredentials =>
      _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  @override
  Future<DriveSignInResult?> trySilentSignIn() async {
    if (!_hasCredentials) return null;
    final stored = await _storage.read(key: _credsKey);
    final email = await _storage.read(key: _emailKey);
    if (stored == null || email == null) return null;
    try {
      final creds = ga.AccessCredentials.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
      final base = http.Client();
      final client = ga.autoRefreshingClient(_clientIdObj, creds, base);
      _attachClient(client);
      return DriveSignInResult(email);
    } catch (_) {
      // Stored credentials are corrupt or revoked — wipe them so the next
      // signIn() starts clean.
      await signOut();
      return null;
    }
  }

  @override
  Future<DriveSignInResult?> signIn() async {
    if (!_hasCredentials) {
      throw StateError(
        'OAuth credentials not configured. Copy .env.example to .env and '
        'fill in RSVP_OAUTH_CLIENT_ID and RSVP_OAUTH_CLIENT_SECRET.',
      );
    }
    final client = await ga.clientViaUserConsent(
      _clientIdObj,
      _scopes,
      _launchPrompt,
    );
    _attachClient(client);
    final email = await _fetchEmail(client);
    await _persistCredentials(client.credentials);
    await _storage.write(key: _emailKey, value: email);
    return DriveSignInResult(email);
  }

  @override
  Future<void> signOut() async {
    await _credsSub?.cancel();
    _credsSub = null;
    _client?.close();
    _client = null;
    await _storage.delete(key: _credsKey);
    await _storage.delete(key: _emailKey);
  }

  @override
  Future<ga.AuthClient?> authenticatedClient() async => _client;

  void _attachClient(ga.AutoRefreshingAuthClient client) {
    _credsSub?.cancel();
    _client?.close();
    _client = client;
    // Re-persist on every refresh so a long-lived install doesn't end up
    // with a stale access token written to disk.
    _credsSub =
        client.credentialUpdates.listen(_persistCredentials, onError: (_) {});
  }

  Future<void> _persistCredentials(ga.AccessCredentials creds) {
    return _storage.write(
      key: _credsKey,
      value: jsonEncode(creds.toJson()),
    );
  }

  Future<String> _fetchEmail(http.Client client) async {
    final resp = await client.get(
      Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'),
    );
    if (resp.statusCode != 200) {
      throw StateError(
        'OIDC userinfo failed (${resp.statusCode}): ${resp.body}',
      );
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final email = body['email'];
    if (email is! String) {
      throw StateError('userinfo response missing "email"');
    }
    return email;
  }

  void _launchPrompt(String url) {
    // Fire-and-forget: the loopback flow is waiting on the redirect, and
    // the prompt callback signature is synchronous.
    unawaited(launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ));
  }
}
