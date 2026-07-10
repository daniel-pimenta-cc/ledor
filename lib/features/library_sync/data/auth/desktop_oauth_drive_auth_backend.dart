import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/auth_io.dart' as ga;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'drive_auth_backend.dart';

/// OAuth credentials are loaded from `.env` (bundled as an asset). They
/// must come from a "Web application" client in Google Cloud Console with
/// BOTH `http://localhost` and `http://127.0.0.1` listed as authorized
/// redirect URIs. googleapis_auth's loopback sends `http://localhost:<port>`,
/// so the `localhost` entry is the one that actually matches; a Web client
/// exact-matches the host (unlike a Desktop client, which accepts any
/// loopback port without registration). The same
/// client_id is reused by the Android backend (via google_sign_in's
/// `serverClientId`) so Drive's `drive.file` scope sees the same folder
/// on both platforms.

/// Whether the build was provisioned with desktop OAuth credentials.
/// Requires that `dotenv.load()` has already run (see `main.dart`).
bool get desktopOAuthCredentialsConfigured =>
    envOrEmpty(oauthClientIdKey).isNotEmpty &&
    envOrEmpty(oauthClientSecretKey).isNotEmpty;

/// Linux/macOS/Windows backend. Drives the OAuth 2.0 "installed app" flow:
/// opens the user's default browser, listens on a loopback port, captures
/// the redirected auth code, exchanges it for tokens, and persists the
/// refresh token via [FlutterSecureStorage] (libsecret on Linux).
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
        'fill in RSVP_OAUTH_CLIENT_ID and RSVP_OAUTH_CLIENT_SECRET.',
      );
    }
    final client = await ga.clientViaUserConsent(
      clientIdObj,
      DriveAuthBackend.scopes,
      _launchPrompt,
    );
    attachClient(client);
    final email = await _fetchEmail(client);
    await persistSession(client.credentials, email);
    return email;
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
    // googleapis_auth never sends access_type=offline / prompt=consent, and
    // a Web client only returns a refresh token when both are present. On
    // re-auth (grant already active) Google would otherwise omit the refresh
    // token, the session gets persisted with refreshToken=null, and the next
    // trySilentSignIn throws in autoRefreshingClient and wipes the session —
    // forcing a fresh login on every app start.
    final uri = Uri.parse(url);
    final patched = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'access_type': 'offline',
      'prompt': 'consent',
    });
    // Fire-and-forget: the loopback flow is waiting on the redirect, and
    // the prompt callback signature is synchronous.
    unawaited(launchUrl(patched, mode: LaunchMode.externalApplication));
  }
}
