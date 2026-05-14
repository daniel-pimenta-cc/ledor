# Linux desktop

Versão desktop GTK do RSVP Reader. Compartilha 100% do código Dart com Android/iOS — só o shell nativo (CMake + GTK em `linux/`) e alguns guards de plataforma são específicos.

## Pré-requisitos

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev
```

(Em distros que ainda usam GCC 11, troque `libstdc++-12-dev` pelo equivalente. `libsecret-1-dev` é necessário pelo `flutter_secure_storage_linux`, usado pra guardar o refresh token do Google Drive.)

## Rodar e buildar

```bash
flutter run -d linux                  # debug
flutter build linux --release         # bundle em build/linux/x64/release/bundle/rsvp_reader
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
2. App abre o navegador padrão (via `url_launcher`) na URL de consent do Google.
3. App escuta em `http://127.0.0.1:<porta-aleatória>/`.
4. Após aprovação, Google redireciona pro loopback; `googleapis_auth.clientViaUserConsent` captura o code, troca por tokens e devolve um `AutoRefreshingAuthClient`.
5. Refresh token é gravado no keyring (libsecret) via `flutter_secure_storage`. Próximas execuções restauram silenciosamente em `trySilentSignIn()`.

### Setup das credenciais

Crie um OAuth Client ID **type "Web application"** no [Google Cloud Console](https://console.cloud.google.com/apis/credentials), no mesmo projeto/consent screen do Android. Em **Authorized redirect URIs** adicione `http://127.0.0.1` (sem porta — pra loopback IPs o Google ignora a porta).

> Por que "Web application" e não "Desktop"? O scope `drive.file` filtra visibilidade de arquivos **por OAuth client_id**. Pra Android e desktop verem a mesma pasta `RSVP Reader/` no Drive, ambos passam pelo mesmo client_id — Android usa `serverClientId` em `google_sign_in` apontando pra esse Web client. Clients "Desktop application" não funcionam como `serverClientId`.

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
- **Packaging**: ainda não há AppImage/Flatpak/Snap; o build produz só o bundle bruto em `build/linux/x64/release/bundle/`.
- **Storage**: `path_provider` resolve para `~/.local/share/rsvp_reader/` em Linux (XDG). O DB e os EPUBs ficam lá.
