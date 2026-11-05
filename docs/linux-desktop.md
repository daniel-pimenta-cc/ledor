# Linux desktop

GTK desktop build of Ledor. It shares all Dart code with Android/iOS; only the
native shell (CMake + GTK in `linux/`) and a few platform guards are specific.

## Prerequisites

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev
```

Use your distro's matching `libstdc++-*-dev` if it isn't GCC 12.
`libsecret-1-dev` is required by `flutter_secure_storage_linux`, which stores
the Google Drive refresh token. TTS needs `speech-dispatcher` at runtime (see
[tts-mode.md](tts-mode.md#linux-backend-speechdsocketbackend)).

`.env` is a declared asset in `pubspec.yaml`, so it must exist or the build
fails. Without Drive credentials an empty one is enough (`touch .env`, as CI
does); see [Google Drive sync](#google-drive-sync).

## Run and build

```bash
flutter run -d linux                  # debug
flutter build linux --release         # bundle in build/linux/x64/release/bundle/ (binary: ledor)
```

The window opens at 1280×800 (minimum 800×600); title and size are set in
`linux/runner/my_application.cc`. `BINARY_NAME` (`ledor`) and
`APPLICATION_ID` (`com.pimenta.ledor`) live in `linux/CMakeLists.txt`.

## Platform capabilities

`lib/core/utils/platform_capabilities.dart` is the single source of truth. Use
its getters instead of scattering `Platform.isLinux`:

| Capability | Android | iOS | Linux |
|---|---|---|---|
| `supportsShareIntent` (receive_sharing_intent) | ✓ | ✓ | ✗ |
| `supportsDriveSync` | ✓ (with credentials) | ✗ | ✓ (with credentials) |
| `isDesktop` (drop target, shortcuts; also macOS/Windows) | ✗ | ✗ | ✓ |
| `supportsTts` | ✓ | ✓ | ✓ |
| `supportsBackgroundAudio` (audio_service) | ✓ | ✓ | ✗ |

Without OAuth credentials (see below), `supportsDriveSync` is false and the
**Sync** section is hidden in Settings.

## Keyboard shortcuts (reader)

Desktop only, bound with `CallbackShortcuts` in
`RsvpReaderScreen._wrapWithShortcuts`:

| Key | Action |
|---|---|
| `Space` | play/pause |
| `←` / `→` | back/forward 1 word |
| `Shift+←` / `Shift+→` | back/forward `AppConstants.skipWordCount` (10) words |
| `↑` / `↓` | WPM ± `AppConstants.wpmStep` (25); changes WPM even in TTS mode, not the TTS rate |
| `Esc` | pause if playing, then close the reader (back to the library, or close the reader pane in split view) |
| `Ctrl+B` | split view only: toggle the library panel (`libraryPanelVisibleProvider`) |

## Drag-and-drop

`DesktopDropHandler` (`lib/core/share/desktop_drop_handler.dart`) wraps the
tree via `MaterialApp.builder` and is a pass-through unless
`PlatformCapabilities.isDesktop`. It accepts:

- **`.epub` files**: all dropped `.epub`s go to
  `EpubImportNotifier.importFromPaths` (batch import), through the same
  `persistParsedBook` pipeline as the file picker. If any EPUB is in the drop,
  non-EPUB items are ignored.
- **URL / text containing a URL**: each item is read as text,
  `UrlUtils.extractHttpUrl` picks the first http(s) URL, and
  `articleImportProvider.notifier.importFromUrl` imports it (same pipeline as
  the "Import URL" dialog).

## Google Drive sync

Sync uses the same `DriveSyncFolderGateway` as Android; only auth differs. On
Linux, `DesktopOAuthDriveAuthBackend`
(`lib/features/library_sync/data/auth/`) runs an installed-app OAuth 2.0 flow:

1. The user clicks **Connect Drive** in Settings.
2. The app binds a loopback server on `127.0.0.1:<random port>`, uses
   `http://localhost:<port>` as the redirect URI and opens the Google consent
   URL in the default browser (`url_launcher`) with
   `access_type=offline&prompt=consent` (a Web client only returns a refresh
   token when both are present).
3. Google redirects to the loopback; the app captures the code, answers with a
   **302 to https://ledor.app/auth/** (landing page) and exchanges the code via
   `googleapis_auth.obtainAccessCredentialsViaCodeExchange`.
4. Credentials are stored in the keyring (libsecret) via
   `flutter_secure_storage`; later launches restore them in `trySilentSignIn()`.

### Credentials setup

Create an OAuth Client ID of type **Web application** in the
[Google Cloud Console](https://console.cloud.google.com/apis/credentials). Under
**Authorized redirect URIs** add both `http://localhost` and `http://127.0.0.1`
(no port; Google ignores the port for bare loopback hosts). The redirect uses
`localhost`, so that entry is the one that matches; registering only
`127.0.0.1` gives `redirect_uri_mismatch`, because Web clients match the host
exactly.

> Why "Web application" and not "Desktop"? The `drive.file` scope filters file
> visibility **per OAuth client_id**. For Android and desktop to see the same
> `Ledor/` Drive folder, both use the same client_id: Android passes this Web
> client as `serverClientId` to `google_sign_in`. Desktop clients can't be used
> as `serverClientId`.

Android also needs a separate **Android** OAuth client in the same project
(package name + signing-cert SHA-1) so `google_sign_in` can verify the app.
That client is not in `.env`; Play Services picks it up.

Then:

```bash
cp .env.example .env
# fill in LEDOR_OAUTH_CLIENT_ID and LEDOR_OAUTH_CLIENT_SECRET
```

`.env` is gitignored. `flutter_dotenv` bundles it as an asset and `main.dart`
calls `dotenv.load(fileName: '.env', isOptional: true)` at startup. Unless both
values are set, `desktopOAuthCredentialsConfigured` is false and Sync is
hidden. Release builds write `.env` from CI secrets
(`.github/workflows/release.yml`).

### Storage

- Credentials (access + refresh token) and the signed-in email: desktop keyring
  (libsecret/GNOME Keyring) via `flutter_secure_storage`, keys
  `drive_auth.credentials` and `drive_auth.email` (shared with Android in
  `DriveAuthBackend`).
- `signOut` deletes both and closes the HTTP client.

## Known limitations

- **System share sheet**: `receive_sharing_intent` has no Linux binding and no
  URL/MIME handler is registered. To import an article, use the "Import URL"
  dialog or drag the URL onto the window.
- **TTS**: no background audio (`supportsBackgroundAudio` is false); word
  highlights are timer-estimated. See [tts-mode.md](tts-mode.md).
- **Packaging**: no AppImage/Flatpak/Snap; the build produces the raw bundle.
  Releases publish it as `ledor-linux-x64-vX.Y.Z.tar.gz` via
  `.github/workflows/release.yml` (triggered by a `v*` tag). CMake installs
  `install-desktop-entry.sh` and `ledor.png` into the bundle; running the
  script once after unpacking writes `com.pimenta.ledor.desktop` to
  `~/.local/share/applications`. Without it, docks show a generic icon (on
  Wayland the window's app_id must match an installed desktop file).
- **Storage paths**: `getApplicationDocumentsDirectory()` resolves to the XDG
  documents dir (`~/Documents`). The DB (`rsvp_reader.db`, pre-rename name kept
  on purpose) and imported EPUBs live there, independent of `APPLICATION_ID`.
  Only SharedPreferences live under `~/.local/share/com.pimenta.ledor/` and
  reset if the app id changes (Drive sync restores settings).
