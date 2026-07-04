import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as ga;
import 'package:http/http.dart' as http;

import 'drive_auth_backend.dart';

const _clientIdKey = 'RSVP_OAUTH_CLIENT_ID';
const _clientSecretKey = 'RSVP_OAUTH_CLIENT_SECRET';

String _envOrEmpty(String key) => dotenv.maybeGet(key) ?? '';

/// Mobile (Android/iOS) backend. Pairs the native Google account picker
/// with a [serverClientId] pointing at the same Web Application OAuth
/// client used by the desktop backend, then exchanges the returned
/// `serverAuthCode` for refresh/access tokens issued for that client.
///
/// Why the dance: Drive's `drive.file` scope filters file visibility per
/// OAuth client_id. If Android tokens are issued for the Android
/// client_id (the default with stock google_sign_in) while desktop tokens
/// are issued for a separate Web client_id, the two devices see different
/// "RSVP Reader" folders even though they're on the same Google account.
/// Pinning Android to the web client_id via [serverClientId] makes both
/// devices see the same set of app-created files.
class GoogleSignInDriveAuthBackend implements DriveAuthBackend {
  static const _credsKey = 'drive_auth.credentials';
  static const _emailKey = 'drive_auth.email';
  static const _scopes = <String>[
    drive.DriveApi.driveFileScope,
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  final String _clientId;
  final String _clientSecret;
  final FlutterSecureStorage _storage;
  late final GoogleSignIn _google;

  ga.AutoRefreshingAuthClient? _client;
  StreamSubscription<ga.AccessCredentials>? _credsSub;

  GoogleSignInDriveAuthBackend({
    String? clientId,
    String? clientSecret,
    FlutterSecureStorage? storage,
  })  : _clientId = clientId ?? _envOrEmpty(_clientIdKey),
        _clientSecret = clientSecret ?? _envOrEmpty(_clientSecretKey),
        _storage = storage ?? const FlutterSecureStorage() {
    _google = GoogleSignIn(
      scopes: _scopes,
      // serverClientId switches the issuer of the requested authorization
      // code to the Web client_id; without it, tokens are minted for the
      // Android client and Drive treats this device as a different app.
      serverClientId: _clientId.isNotEmpty ? _clientId : null,
      // Force a fresh, offline-exchangeable serverAuthCode on every
      // interactive sign-in. Without it Android can return a code that's
      // only good for an access token — or a cached, already-consumed one —
      // so the serverAuthCode → refresh-token exchange fails with
      // invalid_grant.
      forceCodeForRefreshToken: true,
    );
  }

  ga.ClientId get _clientIdObj => ga.ClientId(_clientId, _clientSecret);

  bool get _hasCredentials =>
      _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  @override
  Future<DriveSignInResult?> trySilentSignIn() async {
    if (!_hasCredentials) return null;
    // Restore from the previously-stored refresh token first — avoids
    // bouncing through google_sign_in on every cold start.
    final stored = await _storage.read(key: _credsKey);
    final email = await _storage.read(key: _emailKey);
    if (stored != null && email != null) {
      try {
        final creds = ga.AccessCredentials.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
        final client =
            ga.autoRefreshingClient(_clientIdObj, creds, http.Client());
        _attachClient(client);
        return DriveSignInResult(email);
      } catch (_) {
        // Stored credentials corrupt/revoked — clear and fall through.
        await signOut();
      }
    }
    // Last-ditch: try a silent native sign-in. The user may have just
    // upgraded from the pre-serverClientId build and have no stored web
    // credentials yet. On failure (e.g., no consent for offline access
    // yet) we return null so the UI prompts for an interactive connect.
    final account = await _google.signInSilently(suppressErrors: true);
    if (account == null) return null;
    try {
      return await _exchangeAndStore(account);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DriveSignInResult?> signIn() async {
    if (!_hasCredentials) {
      throw StateError(
        'OAuth credentials not configured. Copy .env.example to .env and '
        'fill in RSVP_OAUTH_CLIENT_ID (must be a "Web Application" OAuth '
        'client_id from Google Cloud Console) and RSVP_OAUTH_CLIENT_SECRET.',
      );
    }
    // Clear any cached google_sign_in session first. A cached account hands
    // back its original serverAuthCode — single-use and ~10 min-lived, so by
    // now expired/consumed — and any grant minted while the OAuth consent
    // screen was in "Testing" is revoked once it moves to "Production". Both
    // surface as invalid_grant in the exchange below. Signing out forces
    // signIn() to mint a brand-new code (and re-consent if the grant is gone).
    try {
      await _google.signOut();
    } catch (_) {/* nothing cached — fine */}
    final account = await _google.signIn();
    if (account == null) return null;
    return _exchangeAndStore(account);
  }

  /// Trades the server auth code for an access+refresh token pair that
  /// belongs to the Web client.
  Future<DriveSignInResult?> _exchangeAndStore(
      GoogleSignInAccount account) async {
    final code = account.serverAuthCode;
    if (code == null) {
      throw StateError(
        'Google Sign-In did not return a serverAuthCode. Make sure '
        'RSVP_OAUTH_CLIENT_ID is a Web Application client_id and that '
        'an Android OAuth client (with the app\'s package name + SHA-1) '
        'is registered in the same Google Cloud project.',
      );
    }
    final resp = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'code': code,
        'client_id': _clientId,
        'client_secret': _clientSecret,
        // Empty redirect_uri tells Google to use the "installed app" semantics
        // that match what serverAuthCode was issued for.
        'redirect_uri': '',
        'grant_type': 'authorization_code',
      },
    );
    if (resp.statusCode != 200) {
      throw StateError(
        'OAuth token exchange failed (${resp.statusCode}): ${resp.body}',
      );
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String?;
    final refreshToken = body['refresh_token'] as String?;
    final expiresIn = (body['expires_in'] as num?)?.toInt();
    if (accessToken == null || refreshToken == null || expiresIn == null) {
      throw StateError('OAuth token response missing required fields: $body');
    }
    final creds = ga.AccessCredentials(
      ga.AccessToken(
        'Bearer',
        accessToken,
        DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      ),
      refreshToken,
      _scopes,
    );
    final client =
        ga.autoRefreshingClient(_clientIdObj, creds, http.Client());
    _attachClient(client);
    await _persistCredentials(creds);
    await _storage.write(key: _emailKey, value: account.email);
    return DriveSignInResult(account.email);
  }

  @override
  Future<void> signOut() async {
    await _credsSub?.cancel();
    _credsSub = null;
    _client?.close();
    _client = null;
    await _storage.delete(key: _credsKey);
    await _storage.delete(key: _emailKey);
    try {
      await _google.signOut();
    } catch (_) {/* best-effort */}
  }

  @override
  Future<ga.AuthClient?> authenticatedClient() async => _client;

  void _attachClient(ga.AutoRefreshingAuthClient client) {
    _credsSub?.cancel();
    _client?.close();
    _client = client;
    _credsSub = client.credentialUpdates
        .listen(_persistCredentials, onError: (_) {});
  }

  Future<void> _persistCredentials(ga.AccessCredentials creds) {
    return _storage.write(
      key: _credsKey,
      value: jsonEncode(creds.toJson()),
    );
  }
}
