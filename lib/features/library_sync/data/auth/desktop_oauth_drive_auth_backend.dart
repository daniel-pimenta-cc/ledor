import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/auth_io.dart' as ga;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'drive_auth_backend.dart';

/// OAuth credentials are loaded from `.env` (bundled as an asset). They
/// must come from a "Web application" client in Google Cloud Console with
/// BOTH `http://localhost` and `http://127.0.0.1` listed as authorized
/// redirect URIs. The loopback below redirects to `http://localhost:<port>`,
/// so the `localhost` entry is the one that actually matches; a Web client
/// exact-matches the host (unlike a Desktop client, which accepts any
/// loopback port without registration). The same
/// client_id is reused by the Android backend (via google_sign_in's
/// `serverClientId`) so Drive's `drive.file` scope sees the same folder
/// on both platforms.

/// Where the browser lands after the loopback captures the auth code.
const _postAuthRedirectUrl = 'https://ledor.app/auth/';

/// Whether the build was provisioned with desktop OAuth credentials.
/// Requires that `dotenv.load()` has already run (see `main.dart`).
bool get desktopOAuthCredentialsConfigured =>
    envOrEmpty(oauthClientIdKey).isNotEmpty &&
    envOrEmpty(oauthClientSecretKey).isNotEmpty;

/// Linux/macOS/Windows backend. Drives the OAuth 2.0 "installed app" flow:
/// opens the user's default browser, listens on a loopback port, captures
/// the redirected auth code (sending the browser on to [_postAuthRedirectUrl]),
/// exchanges it for tokens, and persists the refresh token via
/// [FlutterSecureStorage] (libsecret on Linux).
class DesktopOAuthDriveAuthBackend extends DriveAuthBackend {
  DesktopOAuthDriveAuthBackend({
    super.clientId,
    super.clientSecret,
    super.storage,
  });

  @override
  Future<String?> trySilentSignIn() async {
    if (!hasCredentials) return null;
    final stored = await loadStoredSession();
    if (stored == null) return null;
    try {
      final creds = ga.AccessCredentials.fromJson(
        jsonDecode(stored.creds) as Map<String, dynamic>,
      );
      attachClient(ga.autoRefreshingClient(clientIdObj, creds, http.Client()));
      return stored.email;
    } catch (e) {
      // Stored credentials are corrupt or revoked — wipe them so the next
      // signIn() starts clean.
      debugPrint('[auth] silent sign-in failed, wiping stored session: $e');
      await signOut();
      return null;
    }
  }

  @override
  Future<String?> signIn() async {
    if (!hasCredentials) {
      throw StateError(
        'OAuth credentials not configured. Copy .env.example to .env and '
        'fill in $oauthClientIdKey and $oauthClientSecretKey.',
      );
    }
    // Own loopback server instead of ga.clientViaUserConsent: it lets us
    // (a) send access_type=offline + prompt=consent — a Web client only
    // returns a refresh token when both are present — and (b) bounce the
    // browser to a friendly landing page instead of the package's bare
    // "You may now close this window".
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirectUri = 'http://localhost:${server.port}';
      final state = _randomState();
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': DriveAuthBackend.scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
        'state': state,
      });
      unawaited(launchUrl(authUrl, mode: LaunchMode.externalApplication));

      // Without a deadline an abandoned consent (closed browser tab,
      // redirect_uri_mismatch page) pins the UI on "Connecting..." forever —
      // the notifier only unlocks when signIn returns or throws.
      final params = await _awaitRedirect(server)
          .timeout(const Duration(minutes: 5));
      if (params['error'] == 'access_denied') return null; // user cancelled
      final code = params['code'];
      if (code == null || params['state'] != state) {
        throw StateError(
          'OAuth redirect invalid (error=${params['error']})',
        );
      }

      final baseClient = http.Client();
      final creds = await ga.obtainAccessCredentialsViaCodeExchange(
        baseClient,
        clientIdObj,
        code,
        redirectUrl: redirectUri,
      );
      final client = ga.autoRefreshingClient(clientIdObj, creds, baseClient);
      attachClient(client);
      final email = await _fetchEmail(client);
      await persistSession(client.credentials, email);
      return email;
    } finally {
      await server.close();
    }
  }

  /// Serves the loopback until Google's redirect arrives, ignoring stray
  /// requests (favicon etc.), and answers it with a 302 to the site.
  Future<Map<String, String>> _awaitRedirect(HttpServer server) async {
    await for (final request in server) {
      final params = request.uri.queryParameters;
      final isOAuthRedirect =
          params.containsKey('code') || params.containsKey('error');
      request.response.statusCode =
          isOAuthRedirect ? HttpStatus.found : HttpStatus.notFound;
      if (isOAuthRedirect) {
        request.response.headers.set(
          HttpHeaders.locationHeader,
          _postAuthRedirectUrl,
        );
      }
      await request.response.close();
      if (isOAuthRedirect) return params;
    }
    throw StateError('Loopback server closed before the OAuth redirect');
  }

  String _randomState() {
    final rng = Random.secure();
    return base64UrlEncode(
      Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256))),
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
}
