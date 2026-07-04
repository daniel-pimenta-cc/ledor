# iOS share extension setup

Android já aceita URLs compartilhadas via intent-filter em `AndroidManifest.xml`.
Pra iOS fazer o mesmo, é necessário adicionar um **Share Extension target** no
Xcode — isso só pode ser feito num Mac com Xcode aberto.

## Passos no Xcode (uma vez por projeto)

1. Abrir `ios/Runner.xcworkspace`.
2. `File` → `New` → `Target…` → escolher **Share Extension** → Next.
3. Nome: `ShareExtension` (ou outro; lembrar dele).
4. Linguagem: Swift. Confirmar a criação.
5. Selecionar a target `ShareExtension` criada → aba **Signing & Capabilities**:
   - Definir o mesmo Team da target `Runner`.
   - Adicionar capability **App Groups** e criar o grupo
     `group.com.danielpimenta.rsvpReader` (ou outro ID único).
   - Fazer o mesmo na target `Runner` — adicionar App Groups e marcar o
     mesmo grupo criado acima.
6. Substituir o conteúdo de `ios/ShareExtension/ShareViewController.swift`
   pelo exemplo do
   [receive_sharing_intent](https://pub.dev/packages/receive_sharing_intent#ios)
   (seção "iOS Share Extension").
7. Em `ios/ShareExtension/Info.plist`, ajustar o `NSExtensionAttributes`:
   - `NSExtensionActivationRule` → permitir `NSExtensionActivationSupportsWebURLWithMaxCount = 1`
     e `NSExtensionActivationSupportsText = true`.
8. Em `ios/Runner/Info.plist` adicionar (ou garantir que exista):
   ```xml
   <key>AppGroupId</key>
   <string>group.com.danielpimenta.rsvpReader</string>
   ```
   — o pacote lê essa key para saber o App Group ID compartilhado.

## Testando

1. `flutter run` num device iOS (simulator share-sheet não mostra extensões
   de terceiros — precisa ser aparelho físico ou TestFlight).
2. Abrir o Safari, compartilhar uma página → o app Ledor deve aparecer
   na lista de destinos.
3. Selecionar → app abre, snackbar "Importando artigo…" aparece, reader
   abre quando termina.

## Por que não fica automatizado

Share extensions são uma target separada no Xcode project, com arquivos
próprios (`Info.plist`, `.entitlements`, `ShareViewController.swift`) e
capability setup (App Groups + Team). Gerar isso por script exigiria mexer
no `project.pbxproj`, que é frágil e difícil de manter — melhor fazer uma
vez no Xcode e commitar o resultado.
