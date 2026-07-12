# Linux desktop

Versão desktop GTK do Ledor. Compartilha 100% do código Dart com Android/iOS — só o shell nativo (CMake + GTK em `linux/`) e alguns guards de plataforma são específicos.

## Pré-requisitos

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev
```

(Em distros que ainda usam GCC 11, troque `libstdc++-12-dev` pelo equivalente. `libsecret-1-dev` é necessário pelo `flutter_secure_storage_linux`, usado pra guardar o refresh token do Google Drive.)

## Rodar e buildar

```bash
flutter run -d linux                  # debug
flutter build linux --release         # bundle em build/linux/x64/release/bundle/ledor
```

A janela abre em 1280×800 (mínimo 800×600). Título e tamanho são definidos em `linux/runner/my_application.cc`.

## Capacidades por plataforma

`lib/core/utils/platform_capabilities.dart` é a fonte única da verdade. Use os getters em vez de espalhar `Platform.isLinux` pelo código:

| Capability | Android | iOS | Linux |
|---|---|---|---|
| `supportsShareIntent` (receive_sharing_intent) | ✓ | ✓ | ✗ |
| `supportsDriveSync` | ✓ | ✗ | ✓ (com credenciais) |
| `isDesktop` (DropTarget, atalhos) | ✗ | ✗ | ✓ |

Em Linux sem credenciais OAuth compiladas (ver "Google Drive sync" abaixo), `supportsDriveSync` é falso e a seção **Sync** das Settings fica oculta.

## Atalhos de teclado (reader)

Ativos só em desktop, ligados via `CallbackShortcuts` em `RsvpReaderScreen`:

| Tecla | Ação |
|---|---|
| `Space` | play/pause |
| `←` / `→` | volta/avança 1 palavra |
| `Shift+←` / `Shift+→` | volta/avança `AppConstants.skipWordCount` palavras |
| `↑` / `↓` | WPM ± `AppConstants.wpmStep` |
| `Esc` | volta pra biblioteca (ou fecha o split-view) |

## Drag-and-drop

`DesktopDropHandler` (em `lib/core/share/desktop_drop_handler.dart`) envolve toda a árvore via `MaterialApp.builder`. Aceita:

- **`.epub`**: chama `EpubImportNotifier.importFromPath`, passando pelo mesmo pipeline (`persistParsedBook`) do `file_picker`.
- **URL / texto contendo URL**: usa `UrlUtils.extractHttpUrl` e dispara `articleImportProvider.importFromUrl`. Mesmo pipeline da janela "Importar URL".

## Google Drive sync

O sync usa o mesmo `DriveSyncFolderGateway` do Android — só a auth muda. No Linux, `DesktopOAuthDriveAuthBackend` (em `lib/features/library_sync/data/auth/`) faz o fluxo OAuth 2.0 "installed app":

1. Usuário clica **Connect Drive** em Settings.
2. App sobe um loopback server próprio em `http://localhost:<porta-aleatória>/` e abre o navegador padrão (via `url_launcher`) na URL de consent do Google, montada com `access_type=offline&prompt=consent` (um client "Web" só devolve refresh token com ambos presentes).
3. Após aprovação, Google redireciona pro loopback; o app captura o code, responde **302 → https://ledor.app/auth/** (landing page amigável) e troca o code por tokens via `googleapis_auth.obtainAccessCredentialsViaCodeExchange`.
4. Refresh token é gravado no keyring (libsecret) via `flutter_secure_storage`. Próximas execuções restauram silenciosamente em `trySilentSignIn()`.

### Setup das credenciais

Crie um OAuth Client ID **type "Web application"** no [Google Cloud Console](https://console.cloud.google.com/apis/credentials), no mesmo projeto/consent screen do Android. Em **Authorized redirect URIs** adicione **`http://localhost` E `http://127.0.0.1`** (ambos sem porta — pro host de loopback "pelado" o Google ignora a porta). O app abre o loopback em `http://localhost:<porta-aleatória>`, então o **`http://localhost` é o que realmente casa**; o `127.0.0.1` fica por garantia. Cadastrar só `127.0.0.1` (ou só com porta) causa `redirect_uri_mismatch`: client "Web" faz match exato de host, diferente de client "Desktop" que aceita qualquer porta de loopback sem registro.

> Por que "Web application" e não "Desktop"? O scope `drive.file` filtra visibilidade de arquivos **por OAuth client_id**. Pra Android e desktop verem a mesma pasta `Ledor/` no Drive, ambos passam pelo mesmo client_id — Android usa `serverClientId` em `google_sign_in` apontando pra esse Web client. Clients "Desktop application" não funcionam como `serverClientId`.

O Android também precisa de um **Android OAuth client** separado registrado no mesmo projeto (com package name + SHA-1 do certificado de signing); o `google_sign_in` usa esse pra verificar o app no dispositivo. Esse Android client não vai no `.env` — fica registrado no Cloud Console e o Play Services pega automaticamente.

Copie `.env.example` pra `.env` na raiz do projeto e preencha os dois valores:

```bash
cp .env.example .env
# edite .env e cole o client id e o secret
```

`.env` é gitignored. O `flutter_dotenv` empacota o arquivo como asset (declarado em `pubspec.yaml`) e `main.dart` chama `dotenv.load(isOptional: true)` no startup. Sem ambos preenchidos, `desktopOAuthCredentialsConfigured` é `false` e a seção Sync some das Settings.

```bash
flutter run -d linux           # desenvolvimento
flutter build linux --release  # bundle final
```

### Storage

- Refresh + access token: keyring do desktop (libsecret/GNOME keyring) via `flutter_secure_storage`.
- Email do usuário conectado: mesma keyring (chave `drive_auth.email`).
- `signOut` apaga ambas e fecha o cliente HTTP.

## Limitações conhecidas

- **Share-sheet do sistema**: `receive_sharing_intent` não tem binding Linux. Sem registro de URL/MIME handler — pra importar artigo, abra o app e use o dialog "Importar URL" (ou arraste a URL na janela).
- **Packaging**: ainda não há AppImage/Flatpak/Snap; o build produz o bundle bruto em `build/linux/x64/release/bundle/`. Releases oficiais publicam esse bundle como `ledor-linux-x64-vX.Y.Z.tar.gz` via GitHub Actions (`.github/workflows/release.yml`, disparado por tag `v*`).
- **Storage**: `getApplicationDocumentsDirectory()` resolve para `~/Documents` em Linux (XDG) — o DB (`rsvp_reader.db`, nome mantido pré-rename) e os EPUBs ficam lá, independentes do `APPLICATION_ID`. Só as SharedPreferences vivem em `~/.local/share/com.pimenta.ledor/` e resetam se o app id mudar (o Drive sync restaura as settings).
