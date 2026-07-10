import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as ga;
import 'package:http/http.dart' as http;

import 'drive_auth_backend.dart';

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
class GoogleSignInDriveAuthBackend extends DriveAuthBackend {
  late final GoogleSignIn _google;

  GoogleSignInDriveAuthBackend({
    super.clientId,
    super.clientSecret,
    super.storage,
  }) {
    _google = GoogleSignIn(
      scopes: DriveAuthBackend.scopes,
      // serverClientId switches the issuer of the requested authorization
      // code to the Web client_id; without it, tokens are minted for the
      // Android client and Drive treats this device as a different app.
      serverClientId: clientId.isNotEmpty ? clientId : null,
      // Force a fresh, offline-exchangeable serverAuthCode on every
      // interactive sign-in. Without it Android can return a code that's
      // only good for an access token — or a cached, already-consumed one —
      // so the serverAuthCode → refresh-token exchange fails with
      // invalid_grant.
      forceCodeForRefreshToken: true,
    );
  }

  @override
  Future<String?> trySilentSignIn() async {
    if (!hasCredentials) return null;
    // Restore from the previously-stored refresh token first — avoids
    // bouncing through google_sign_in on every cold start.
    final stored = await loadStoredSession();
    if (stored != null) {
      try {
        final creds = ga.AccessCredentials.fromJson(
          jsonDecode(stored.creds) as Map<String, dynamic>,
        );
        attachClient(
            ga.autoRefreshingClient(clientIdObj, creds, http.Client()));
        return stored.email;
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
  Future<String?> signIn() async {
    if (!hasCredentials) {
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
  Future<String?> _exchangeAndStore(GoogleSignInAccount account) async {
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
        'client_id': clientId,
        'client_secret': clientSecret,
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
      DriveAuthBackend.scopes,
    );
    attachClient(ga.autoRefreshingClient(clientIdObj, creds, http.Client()));
    await persistSession(creds, account.email);
    return account.email;
  }

  @override
  Future<void> signOut() async {
    await super.signOut();
    try {
      await _google.signOut();
    } catch (_) {/* best-effort */}
  }
}
