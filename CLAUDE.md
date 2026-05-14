# RSVP Reader

Leitor de livros (EPUB) e artigos web em Flutter com RSVP (Rapid Serial Visual Presentation), para Android/iOS/tablet/Linux desktop.

## Comandos

```bash
flutter pub get                                    # instalar deps
dart run build_runner build --delete-conflicting-outputs  # gerar codigo (drift, freezed)
flutter gen-l10n                                   # gerar strings i18n
flutter analyze                                    # verificar erros
flutter test test/                                 # rodar testes (requer lld instalado)
flutter run                                        # rodar no device/emulador
```

## Arquitetura

Feature-based Clean Architecture com Riverpod. Ver [docs/architecture.md](docs/architecture.md).

**Stack:** Flutter 3.x | Riverpod 2 (sem codegen) | Drift/SQLite | SharedPreferences | epub_pro | go_router | http | receive_sharing_intent (mobile-only) | google_sign_in (mobile) + googleapis_auth loopback (desktop) + googleapis (Drive v3) | flutter_secure_storage + url_launcher (desktop OAuth) | google_fonts (Lora + Inter) | fl_chart (stats) | share_plus (export PNG) | desktop_drop (Linux) | intl (DateFormat)

## Estrutura de pastas

```
lib/
  core/
    theme/        # design system editorial
      app_colors    — AppPalette dual (light/dark), AppColors (back-compat)
      app_theme     — AppTheme.build(brightness:) com 14+ component themes
      app_typography — Lora (serif headlines) + Inter (sans body) + tabular figures
      app_spacing   — escala 4/8/12/16/24/32/48
      app_radius    — sm(6)/md(10)/lg(16)/xl(24) + BorderRadius helpers
      app_elevations — BoxShadow por brightness (level1..4)
      app_motion    — duracoes (fast/base/slow/page) + curvas (standard/emphasized/decelerate)
      responsive    — Breakpoints (compact/medium/expanded), DeviceType enum,
                      extensions context.isTablet/isLandscape/deviceType,
                      gridCrossAxisCount(), gridAspectRatio()
    routing/      # app_router (go_router), selected_book_provider (master-detail)
    constants/    # app_constants, responsive_defaults (font scale + margins por device)
    widgets/      # section_card, skeleton_loader (shimmer com AnimationController compartilhado)
    utils/        # orp_calculator, word_timing, html_stripper, text_tokenizer,
                  # readability_extractor, url_utils, sync_file_name, font_mapper,
                  # image_export_service (RepaintBoundary -> PNG -> share_plus),
                  # platform_capabilities (supportsShareIntent/supportsDriveSync/isDesktop)
    di/           # provider overrides (appDatabaseProvider etc.)
    share/        # share_intent_handler (Android share target),
                  # desktop_drop_handler (drag-drop de EPUB/URL no Linux)
  database/       # Drift: app_database, tables/ (books, reading_progress,
                  # reading_session, cached_tokens, sync_import_failures,
                  # book_source constants), daos/
  features/
    book_library/
      presentation/
        screens/    library_screen (master-detail host, tabs, listeners)
        widgets/    book_card, library_list, library_fab, library_appbar_bottom,
                    library_skeleton, library_empty_state, library_section_header,
                    reading_progress_bar, reader_placeholder
        providers/  book_library_provider (categorized stream)
      data/         book_persistence (persistParsedBook)
    epub_import/     # parsing EPUB -> WordToken, cache de tokens no DB
    article_import/  # fetch URL -> readability -> WordToken, cache de tokens no DB
    library_sync/    # sync de biblioteca (EPUB) + progresso + settings via Google Drive
                     # (drive.file scope, pasta "RSVP Reader" no Drive do usuario)
                     # pipeline paraleliza read/list, pula write quando nada mudou,
                     # compacta tombstones zumbis, cache de fileId no gateway
    rsvp_reader/
      domain/entities/  rsvp_state (inclui finishTicket), display_settings, word_token, chapter
      presentation/
        screens/    rsvp_reader_screen (modes, top bar, side panel host,
                    ref.listen em finishTicket -> /books/:id/completion)
        widgets/    rsvp_word_display, context_scroll_view,
                    rsvp_paragraph_view (extraido pra testar sem engine provider),
                    rsvp_controls (dock compositor),
                    controls_shell, controls_meta_row, controls_progress_row,
                    controls_transport_row, seek_slider,
                    wpm_selector (capsule + preset drawer compartilhado),
                    display_settings_panel + display_settings_widgets (part),
                    reader_settings_sheet, chapter_list_sheet, reader_side_panel,
                    finish_book_button (entrada manual pra tela de completion)
        providers/  rsvp_engine_provider (flush de sessao em pause/end/ereader/dispose,
                    computeEffectiveWpm + computeSessionAvgWpm como helpers puros),
                    display_settings_provider, reader_side_panel_provider
    reading_stats/   # telemetria + dashboards + shareable cards
      domain/entities/  stats_range, stats_snapshot, monthly_recap, book_completion_summary
      presentation/
        screens/    reading_stats_screen (TabBar weekly/monthly),
                    monthly_recap_screen, book_completion_screen
        widgets/    stats_* (summary_cards, color_palette, book_breakdown,
                    *_chart, empty_state), monthly_recap_card,
                    book_completion_card, star_rating_picker
        providers/  reading_stats_provider (statsSnapshotProvider),
                    monthly_recap_provider, book_completion_provider
    settings/
      presentation/
        screens/    settings_screen (Appearance + DisplaySettingsPanel + Sync + About)
        providers/  theme_mode_provider (system/light/dark, persiste + inverte cores)
  l10n/         # ARB files (en, pt) + generated/
```

## Conceitos-chave

- **WordToken**: unidade fundamental — cada palavra pre-processada com ORP index e timing multiplier no momento do import. O motor RSVP nao faz nenhum calculo no hot loop.
- **ORP (Optimal Recognition Point)**: letra de foco a ~30% da palavra, destacada em cor accent. Ver [docs/rsvp-engine.md](docs/rsvp-engine.md).
- **Duas fontes de conteudo, uma pipeline** (`BookSource`):
  - `epub`: arquivo EPUB importado (file picker ou Drive sync).
  - `article`: artigo web importado por URL (dialog manual ou share sheet).
  - Ambos viram `ParsedBook` -> `persistParsedBook` -> `books` + `cached_tokens`. Leitura, progresso e engine RSVP sao identicos. Ver [docs/article-import.md](docs/article-import.md).
- **Tres modos de leitura** (`ReaderMode`):
  - `rsvp`: palavra unica com ORP — ativo durante play
  - `scroll`: texto completo com highlight da palavra atual — pausado, com controles
  - `ereader`: texto completo sem highlight, sem controles — leitura tradicional
  - Toggle entre rsvp/scroll e ereader via icone no top bar; dentro de rsvp/scroll, play/pause alterna entre eles.
- **DisplaySettings**: todas as configs visuais e de leitura (cores, fontes, posicoes, toggles, focus line) persistidas via SharedPreferences. Painel unico (`DisplaySettingsPanel`) usado tanto no bottom sheet do leitor quanto na tela full-screen de Settings — fonte unica de verdade para adicionar opcoes.
- **Tema light + dark**: paleta editorial com tons quentes ("ink on paper" / "paper"), accent laranja #E55324 preservado em ambos. Toggle em Settings via `SegmentedButton` (system/light/dark), persistido em `themeModeProvider`. Ao trocar de brightness, `ThemeModeNotifier` chama `DisplaySettingsNotifier.applyBrightness()` que inverte automaticamente wordColor e backgroundColor para a paleta correspondente — ORP e highlight ficam preservados.
- **Tipografia editorial**: Lora (serif) em display/headline/title; Inter (sans) em body/label. Font families para RSVP incluem monos (Roboto Mono, JetBrains Mono, Fira Code, Source Code Pro) + serifs (Lora, Source Serif 4). Mapeamento centralizado em `lib/core/utils/font_mapper.dart`.
- **Responsivo + master-detail**: breakpoints em `responsive.dart` (compact <600 / medium 600-840 / expanded >840). Grid adaptativo 2/3/4 colunas. Em tablet landscape, `LibraryScreen` renderiza split-view: lista a esquerda (440px) + reader/placeholder a direita — `selectedBookIdProvider` controla qual livro esta aberto sem trocar rota. Settings e chapter list do reader viram painel lateral (`ReaderSidePanel` + `readerSidePanelProvider`) em tablet landscape; bottom sheet em mobile/portrait. Context scroll view limita largura a 720px em telas largas (readable line-length editorial).
- **WPM selector compartilhado**: `WpmSelector` (all-in-one) usado em settings; `WpmCapsule` + `WpmPresetRow` usados separadamente nos controles. Preset drawer gera valores dinamicamente (atual ± incrementos de 50, clamped min/max), auto-centraliza o chip selecionado no scroll. Capsule com +/- faz ajuste fino de 25.
- **Biblioteca com tabs**: `LibraryScreen` separa "Livros" (source=epub) de "Artigos" (source=article) via `TabBar`. O FAB (`LibraryFab`) muda de acao conforme a tab ativa.
- **Reading sessions**: cada trecho continuo de `isPlaying=true` (play -> pause/end/ereader/dispose) vira uma row em `reading_session`. Seeks durante play nao quebram a sessao. Threshold 3s/5 words descarta taps acidentais. Ver [docs/reading-stats.md](docs/reading-stats.md).
- **Stats + recap + completion**: feature `reading_stats` consome sessions para (a) dashboard `/stats` com charts weekly/monthly (fl_chart), (b) recap mensal `/stats/recap` com PNG compartilhavel, (c) tela de conclusao `/books/:id/completion` disparada automaticamente ao chegar no final de um livro (via `RsvpState.finishTicket`). Entradas manuais: long-press num livro Lido na biblioteca reabre a tela; `FinishBookButton` (no sheet/side panel do reader) bumpa o progresso pro fim e abre completion pra livros em andamento. Rating 0-5 estrelas persiste em `books.rating` + `ratingUpdatedAt` (timestamp dedicado pro LWW de sync). Share cards usam paleta fixa (independente de tema) e capturam via `RepaintBoundary -> toImage -> share_plus`.
- **Lock + recenter no context view**: overlay flutuante (bottom-right) com toggle de lock (impede o scroll de seguir o highlight enquanto a engine avanca) + botao de recenter. O recenter mede o `RenderBox` real da palavra atual via `GlobalKey` + `getTransformTo(viewport)` em vez de estimar por fracao de caractere — centralizacao precisa em paragrafos longos. A pill em si vem do `RsvpParagraphView` que carrega o `highlightKey`.

## Regras

- Todas as strings de UI devem usar i18n (ARB files em `lib/l10n/`). Nunca hardcodar texto PT ou EN.
- **Cores no leitor e painel de DisplaySettings vem de `DisplaySettings`, nunca de `Theme.of(context)`** — para permitir preview "ao vivo". A unica excecao e a secao Appearance em `settings_screen.dart` (toggle de ThemeMode), que usa o theme global.
- **Cores na biblioteca e chrome do app** (AppBar, cards, FAB, empty states, dialogs) vem de `Theme.of(context).colorScheme`, nunca de `AppColors.*` diretamente.
- Para adicionar/remover uma opcao de display ou leitura: editar `display_settings_panel.dart` (afeta automaticamente o bottom sheet no leitor E a tela full-screen de settings). Adicionar tambem o campo em `DisplaySettings` + `copyWith` + load/save no `DisplaySettingsNotifier`.
- Apos alterar tables do Drift ou classes com `@freezed`: rodar `build_runner`.
- Apos alterar ARB files: rodar `flutter gen-l10n` (l10n.yaml ja configurado).
- **Persistir livros/artigos**: sempre via `persistParsedBook` (em `lib/features/book_library/data/services/book_persistence.dart`). Nunca duplicar o fluxo insert-book + fan-out de tokens.
- **Comparar `source`**: usar as constantes de `BookSource` (`lib/database/tables/book_source.dart`), nunca literais `'epub'`/`'article'`.
- **URLs**: usar `UrlUtils.extractHttpUrl` / `parseWithHttpsFallback` em `lib/core/utils/url_utils.dart` — nao reimplementar parsing ad-hoc.
- **Font mapping**: usar `mapFontFamily()` de `lib/core/utils/font_mapper.dart` — nao reimplementar switch de nomes em cada widget.
- **Sync via Google Drive**: `DriveSyncFolderGateway` implementa `SyncFolderGateway` usando googleapis com scope `drive.file` (so enxerga arquivos que o proprio app criou). Auth abstraida por `DriveAuthBackend` (em `lib/features/library_sync/data/auth/`): `GoogleSignInDriveAuthBackend` em mobile, `DesktopOAuthDriveAuthBackend` em desktop (loopback OAuth via `googleapis_auth.clientViaUserConsent`, browser do sistema via `url_launcher`, refresh token em `flutter_secure_storage`/libsecret). `DriveAuthNotifier` so depende da abstracao — qualquer codigo abaixo (gateway, sync service, manifest) e identico entre plataformas. Silent sign-in no startup, connect explicito em Settings. Root folder "RSVP Reader" criada sob demanda; id cacheado em `SyncConfig.driveFolderId`. UI de sync escondida via `PlatformCapabilities.supportsDriveSync` quando credenciais OAuth nao foram baked-in (Linux sem `.env` preenchido). `.env` (gitignored) carregado em `main.dart` via `flutter_dotenv` antes de qualquer leitura de `supportsDriveSync`; template em `.env.example`. Pipeline detalhada em [docs/library-sync.md](docs/library-sync.md); setup desktop em [docs/linux-desktop.md](docs/linux-desktop.md#google-drive-sync).
- **Capacidades por plataforma**: usar `PlatformCapabilities` (`lib/core/utils/platform_capabilities.dart`) em vez de espalhar `Platform.isAndroid` / `Platform.isLinux`. Getters: `supportsShareIntent`, `supportsDriveSync`, `isDesktop`, `isMobile`. Linux usa `DesktopDropHandler` (drag-drop de EPUB/URL) e atalhos de teclado no reader (`Space`/`←→`/`↑↓`/`Esc`); detalhes em [docs/linux-desktop.md](docs/linux-desktop.md).
- **Sync de biblioteca so inclui EPUB**: `LibrarySyncService` filtra `source=='epub'`. Artigos sao sempre locais.
- **DateTime compare no sync: SEMPRE `isAtSameMomentAs`, nunca `==`**: local DateTime vem do Drift com `isUtc=false`, remote vem de JSON UTC com `isUtc=true`. `DateTime.==` compara `(micros, isUtc)` — mesmo instante registra como diferente, causando um write de DB por livro todo sync. Afeta qualquer code path que compare lastReadAt/progress.updatedAt/etc entre local e remoto.
- **Tombstone + syncFileName em sync**: um livro ativo sempre vence disputa de `syncFileName` contra um tombstone (em `_uploadMissingEpubs` o tombstone e pulado com `skippedTombstones`; em `_autoImportOrphanFiles` o filename tombstonado e tratado como "ja conhecido" para nao ressuscitar como orfao). Qualquer codigo novo que itere `merged.books` e opere por filename deve respeitar essa invariante. Tombstones cujo filename e reivindicado por um ativo sao compactados fora do merged antes do push.
- **Sync sharded** (`library/books.json` + `library/settings.json` + `library/sessions.json`): cada shard tem seu proprio `_*ShardEquals` que compara conteudo JSON-encoded ignorando `updatedAt`/`updatedBy`. Push paraleliza writes via `Future.wait`; shards inalterados nao sobem. O monolito `library.json` antigo e migrado in-memory na primeira sync e deletado em seguida. Ao adicionar campos novos a `SyncLibraryBook`/sessions/settings, garantir que entrem no `toJson` — os equals dependem disso. Sessions sao append-only por id (merge = uniao); rating tem seu proprio `ratingUpdatedAt` pro LWW imune a bumps de outros campos.
- **`DriveSyncFolderGateway._fileIdCache`**: caches `fileId` por `(parentId, fileName)`. Populado opportunisticamente por `listFiles`, `readBytes`, e branch "create" de `writeBytes`. Consumido por todas as operacoes pra pular o `_findFile` (~500-700ms). `deleteFile` invalida a entrada; `clearCache()` no disconnect. Nao e thread-safe; assume uma unica sync em andamento por gateway (serializado pelo `LibrarySyncNotifier`).
- Testes unitarios dos core utils sao prioridade (ORP, timing, tokenizer, HTML stripper, readability). HTML stripper deve cobrir tags `_skipTags` para evitar regressao de CSS/JS vazando no texto. Logica pura de stats e engine tambem (`computeSessionAvgWpm`, `computeEffectiveWpm`, `buildSnapshot`, `buildMonthlyRecap`, `buildCompletionSummary`). Para testar o `RsvpEngineNotifier` use mocktail nas DAOs + stub do `LibrarySyncNotifier` (o real le `syncConfigProvider` no `schedulePush` e atrapalha o pending-async do flutter_test). Pra exercitar o pipeline de import sem fixture binario, use `test/fixtures/build_minimal_epub.dart` (constroi EPUB 2 valido em runtime via `archive`).
- **Share cards (recap, completion)**: paleta fixa (`_paper`, `_ink`, `_accent` etc. hardcoded nos widgets), NAO derivada de `Theme.of(context)` — exportacao deve ser consistente entre usuarios. Fonts via `GoogleFonts.inter()` / `GoogleFonts.lora()` (strings `'Inter'`/`'Lora'` nao sao asset families registrados).
- **Engine e finishTicket**: qualquer ponto novo de saida de `isPlaying=true` (alem de pause/end/ereader/dispose) deve chamar `_flushSession()` antes de zerar contadores. Fim-de-livro organico (`_advanceWord` hit end, nao seek) incrementa `state.finishTicket` para disparar a tela de completion.
- **Arquivos pequenos**: widgets extraidos em arquivos focados (1 responsabilidade). Controles do reader: `rsvp_controls.dart` compoe; subwidgets em `controls_*.dart` + `seek_slider.dart`. Biblioteca: `library_screen.dart` compoe; subwidgets em `library_*.dart`.

## Docs detalhados

- [docs/architecture.md](docs/architecture.md) — arquitetura, fluxo de dados, providers
- [docs/rsvp-engine.md](docs/rsvp-engine.md) — motor RSVP, ORP, timing, ramp-up
- [docs/article-import.md](docs/article-import.md) — pipeline de artigos web, readability, share sheet
- [docs/reading-stats.md](docs/reading-stats.md) — sessions, stats dashboard, monthly recap, book completion, pipeline de export de PNG
- [docs/library-sync.md](docs/library-sync.md) — sync via Drive, manifest, merge rules, tombstones + compactacao, cache de fileId, invariantes de DateTime
- [docs/share-extension-ios.md](docs/share-extension-ios.md) — setup do share extension iOS (Xcode)
- [docs/linux-desktop.md](docs/linux-desktop.md) — build do Linux desktop, atalhos, drag-drop, limitações
- [tasks.md](tasks.md) — bugs e features pendentes
