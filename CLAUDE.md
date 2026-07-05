# Ledor

Leitor de livros (EPUB) e artigos web em Flutter com RSVP (Rapid Serial Visual Presentation), para Android/iOS/tablet/Linux desktop.

## Comandos

```bash
flutter pub get                                    # instalar deps
dart run build_runner build --delete-conflicting-outputs  # gerar codigo (drift, freezed)
flutter gen-l10n                                   # gerar strings i18n
flutter analyze                                    # verificar erros
flutter test test/                                 # rodar testes (requer lld instalado)
flutter test --coverage test/ && python3 tool/check_coverage.py  # cobertura (gate do CI: --min 72)
flutter run                                        # rodar no device/emulador
```

## Arquitetura

Feature-based Clean Architecture com Riverpod. Ver [docs/architecture.md](docs/architecture.md).

**Stack:** Flutter 3.x | Riverpod 2 (sem codegen) | Drift/SQLite | SharedPreferences | epub_pro | go_router | http | receive_sharing_intent (mobile-only) | google_sign_in (mobile) + googleapis_auth loopback (desktop) + googleapis (Drive v3) | flutter_secure_storage + url_launcher (desktop OAuth) | google_fonts (Lora + Inter) | fl_chart (stats) | share_plus (export PNG) | desktop_drop (Linux) | intl (DateFormat) | flutter_tts (TTS mobile/desktop) + `SpeechdSocketBackend`/`spd-say` (TTS Linux) | audio_service (TTS background + lockscreen controls)

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
                  # token_codec (serialização compacta do tokensJson),
                  # readability_extractor, url_utils, sync_file_name, font_mapper,
                  # image_export_service (RepaintBoundary -> PNG -> share_plus),
                  # platform_capabilities (supportsShareIntent/supportsDriveSync/isDesktop),
                  # voice_label_formatter (TtsVoice -> "Inglês (Reino Unido) · Feminina 1")
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
      domain/entities/  rsvp_state (inclui finishTicket), display_settings, word_token, chapter, bookmark
      presentation/
        screens/    rsvp_reader_screen (modes, top bar, side panel host,
                    ref.listen em finishTicket -> /books/:id/completion)
        widgets/    rsvp_word_display, context_scroll_view,
                    rsvp_paragraph_view (extraido pra testar sem engine provider;
                      aceita onWordLongPress -> converte tokens em WidgetSpan
                      pra ter onTap + onLongPress independentes),
                    rsvp_controls (dock compositor),
                    controls_shell, controls_meta_row, controls_progress_row,
                    controls_transport_row, seek_slider,
                    wpm_selector (capsule + preset drawer compartilhado),
                    display_settings_panel + display_settings_widgets (part),
                    reader_settings_sheet, chapter_list_sheet, reader_side_panel,
                    bookmark_create_dialog, bookmarks_list (shared),
                    bookmarks_list_sheet (mobile),
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
- **Quatro modos de leitura** (`ReaderMode`):
  - `rsvp`: palavra unica com ORP — ativo durante play
  - `scroll`: texto completo com highlight da palavra atual — pausado, com controles
  - `ereader`: texto completo sem highlight, sem controles — leitura tradicional
  - `tts`: narracao em audio com highlight sincronizado pelo callback de word boundary do backend; reusa `ContextScrollView(showHighlight: true)`.
  - Toggle via `ReaderModeMenu` (PopupMenuButton com radio-list dos 4 modos) no top bar; dentro de rsvp/scroll, play/pause alterna entre eles; em tts, play/pause aciona o backend mantendo `mode=tts`.
  - **Persistência por livro**: cada `reading_progress` carrega a coluna `readerMode` (`'rsvp'` / `'ereader'` / `'tts'`, nullable). Engine restaura no `_loadBook` — ereader é síncrono (set state.mode), tts chama `enterTtsMode()` async com `isLoading` mantido true até o player estar pronto (evita race se o usuário tocar play durante a init). `scroll` colapsa em `'rsvp'` na serialização — espelha a mesma decisão do `ReaderModeMenu._menuModeOf`. Helpers em `domain/entities/rsvp_state.dart`: `persistedReaderMode` / `parsePersistedReaderMode`. Sync via Drive em `SyncLibraryProgress.readerMode`.
- **TTS pipeline** (`docs/tts-mode.md`): `TtsBackend` abstrai `flutter_tts` (Android/iOS/macOS/Windows), `SpeechdSocketBackend` (Linux via socket SSIP) e o legado `SpeechDispatcherBackend` (Linux via `spd-say` quando o socket não estiver disponível). Seleção em `ttsBackendProvider`. `TtsPlayer` (em `data/services/tts_player.dart`) é a peça que orquestra fila + pipeline. Lookahead é dinâmico via `_effectiveLookahead` que respeita `backend.canPipeline`: flutter_tts + SSIP enfileiram 2 segmentos via `TtsQueueMode.add`; spd-say (que cancelaria o speak anterior em cada novo) usa 1. Settings dedup field-by-field (`_appliedEngineId` etc.) — slider de rate que re-emite mesmo valor não burna IPC. Stall detection via `_lastProgressAt` heartbeat; `restartIfStalled` (chamado no `didChangeAppLifecycleState(resumed)`) só re-inicia depois de 10s sem progresso. Engine extrai sentenças via `extractSentenceFrom` e delega tudo de speak/progress/completion pro player; callbacks `onWordAdvance`/`onBookFinished`/`onError` voltam pro engine. `_generation` no player invalida callbacks tardios (pause/seek/dispose); `_isPlaying = true` é setado **antes** do primeiro await pra que um `pause()` no mesmo tick funcione. Rate independente do WPM: usuário controla `DisplaySettings.ttsRate` (range `[0.5, 3.0]`, step 0.25) via `TtsRateCapsule` no transport row; presets fixos 0.75/1.0/1.25/.../3.0 (estilo player de audiobook). Reading sessions logam normalmente.
- **TTS background playback** (`audio_service`): `TtsAudioHandler` (data/services/tts_audio_handler.dart) é o singleton que vive pelo `main.dart` via `AudioService.init`. Engine notifier registra `TtsAudioSource` (callbacks play/pause/skip) ao entrar em TTS e `unbindIfActive` no dispose. Notificação de mídia mostra título do livro + autor (vem do `BooksDao.getBookById` carregado em `_loadBook`). Cache do handler em `_audioHandler` pra unbind funcionar mesmo após o `ProviderContainer` começar a tear down. Linux/Web: `PlatformCapabilities.supportsBackgroundAudio` retorna false, provider mantém o default null, todos os calls são no-op.
- **TTS engine picker**: `ttsEnginesProvider` lista as engines disponíveis (Google TTS / Samsung TTS / Pico no Android; espeak-ng / festival / rhvoice no Linux; lista vazia em iOS/macOS/Windows). UI em `TtsEnginePickerSheet` + `_TtsEngineRow` no painel de TTS, escondida quando `getEngines().length < 2`. Persiste em `DisplaySettings.ttsEngineId` e sincroniza via Drive — backend ignora id desconhecido sem perder o valor (round-trip preserva).
- **TTS voice picker**: nomes técnicos do `voice.name` (Android: `en-gb-x-fis-network`; Samsung: `Samsung-tts-en-us-female`) são convertidos em "Inglês (Reino Unido) · Feminina 1" via `enrichVoices` (em `voice_label_formatter.dart`). Nomes amigáveis do iOS ("Samantha") são mantidos como label principal. Picker tem `_ScopeToggle` (Idioma atual / Todos) com default no atual, search bar substring sobre a haystack que cobre label amigável + gender + tech id + locale, e `_EmptyState` com ação rápida "Mudar pra Todos" quando o filtro local está vazio. Tech id ainda aparece como caption monoespaçada pra power users.
- **DisplaySettings**: todas as configs visuais e de leitura (cores, fontes, posicoes, toggles, focus line) persistidas via SharedPreferences. Painel unico (`DisplaySettingsPanel`) usado tanto no bottom sheet do leitor quanto na tela full-screen de Settings — fonte unica de verdade para adicionar opcoes.
- **Tema light + dark**: paleta editorial com tons quentes ("ink on paper" / "paper"), accent laranja #E55324 preservado em ambos. Toggle em Settings via `SegmentedButton` (system/light/dark), persistido em `themeModeProvider`. Ao trocar de brightness, `ThemeModeNotifier` chama `DisplaySettingsNotifier.applyBrightness()` que inverte automaticamente wordColor e backgroundColor para a paleta correspondente — ORP e highlight ficam preservados.
- **Tipografia editorial**: Lora (serif) em display/headline/title; Inter (sans) em body/label. Font families para RSVP incluem monos (Roboto Mono, JetBrains Mono, Fira Code, Source Code Pro) + serifs (Lora, Source Serif 4). Mapeamento centralizado em `lib/core/utils/font_mapper.dart`.
- **Responsivo + master-detail**: breakpoints em `responsive.dart` (compact <600 / medium 600-840 / expanded >840). Grid adaptativo 2/3/4 colunas. Em tablet landscape, `LibraryScreen` renderiza split-view: lista a esquerda (440px) + reader/placeholder a direita — `selectedBookIdProvider` controla qual livro esta aberto sem trocar rota. Settings e chapter list do reader viram painel lateral (`ReaderSidePanel` + `readerSidePanelProvider`) em tablet landscape; bottom sheet em mobile/portrait. Context scroll view limita largura a 720px em telas largas (readable line-length editorial).
- **WPM selector compartilhado**: `WpmSelector` (all-in-one) usado em settings; `WpmCapsule` + `WpmPresetRow` usados separadamente nos controles. Preset drawer gera valores dinamicamente (atual ± incrementos de 50, clamped min/max), auto-centraliza o chip selecionado no scroll. Capsule com +/- faz ajuste fino de 25.
- **Biblioteca com tabs**: `LibraryScreen` separa "Livros" (source=epub) de "Artigos" (source=article) via `TabBar`. O FAB (`LibraryFab`) muda de acao conforme a tab ativa.
- **Reading sessions**: cada trecho continuo de `isPlaying=true` (play -> pause/end/ereader/dispose) vira uma row em `reading_session`. Seeks durante play nao quebram a sessao. Threshold 3s/5 words descarta taps acidentais. Ver [docs/reading-stats.md](docs/reading-stats.md).
- **Stats + recap + completion**: feature `reading_stats` consome sessions para (a) dashboard `/stats` com charts weekly/monthly (fl_chart), (b) recap mensal `/stats/recap` com PNG compartilhavel, (c) tela de conclusao `/books/:id/completion` disparada automaticamente ao chegar no final de um livro (via `RsvpState.finishTicket`). Entradas manuais: long-press num livro Lido na biblioteca reabre a tela; `FinishBookButton` (no sheet/side panel do reader) bumpa o progresso pro fim e abre completion pra livros em andamento. Rating 0-5 estrelas persiste em `books.rating` + `ratingUpdatedAt` (timestamp dedicado pro LWW de sync). Share cards usam paleta fixa (independente de tema) e capturam via `RepaintBoundary -> toImage -> share_plus`.
- **Lock + recenter no context view**: overlay flutuante (bottom-right) com toggle de lock (impede o scroll de seguir o highlight enquanto a engine avanca) + botao de recenter. O recenter mede o `RenderBox` real da palavra atual via `GlobalKey` + `getTransformTo(viewport)` em vez de estimar por fracao de caractere — centralizacao precisa em paragrafos longos. A pill em si vem do `RsvpParagraphView` que carrega o `highlightKey`.
- **Bookmarks**: tabela `bookmarks` (schema v9) com `id, bookId, globalWordIndex, chapterIndex, label?, contextSnippet?, createdAt, updatedAt, deletedAt?` (soft-delete pra tombstones de sync). DAO em `lib/database/daos/bookmarks_dao.dart`; entity + controller em `lib/features/rsvp_reader/domain/entities/bookmark.dart` + `presentation/providers/bookmarks_provider.dart`. UI: long-press numa palavra em qualquer reader mode (RSVP via `GestureDetector.onLongPress` no screen; scroll/ereader/tts via `RsvpParagraphView.onWordLongPress` propagado pelo `ContextScrollView`) abre `BookmarkCreateDialog` com snippet pré-renderizado via `buildBookmarkSnippet`. Lista compartilhada (`BookmarksList`) entre `ReaderSidePanel` (`ReaderSidePanelMode.bookmarks`) em tablet landscape e `BookmarksListSheet` em mobile/portrait. Sync via shard `library/bookmarks.json` (LWW por `updatedAt`, ver regras abaixo).

## Regras

- Todas as strings de UI devem usar i18n (ARB files em `lib/l10n/`). Nunca hardcodar texto PT ou EN.
- **Cores no leitor e painel de DisplaySettings vem de `DisplaySettings`, nunca de `Theme.of(context)`** — para permitir preview "ao vivo". A unica excecao e a secao Appearance em `settings_screen.dart` (toggle de ThemeMode), que usa o theme global.
- **Cores na biblioteca e chrome do app** (AppBar, cards, FAB, empty states, dialogs) vem de `Theme.of(context).colorScheme`, nunca de `AppColors.*` diretamente.
- Para adicionar/remover uma opcao de display ou leitura: editar `display_settings_panel.dart` (afeta automaticamente o bottom sheet no leitor E a tela full-screen de settings). Adicionar tambem o campo em `DisplaySettings` + `copyWith` + load/save no `DisplaySettingsNotifier`. Pra options TTS, ir na seção `_buildTtsSection` do mesmo painel.
- **`wordEndsSentence`**: usar a utility de `lib/core/utils/sentence_boundary.dart` (compartilhada por `computeWordIntervalMultiplier`, `sentence_extractor`, e `context_scroll_view`). Não reimplementar detecção de fim de sentença.
- **TTS engine novo ponto de saída**: qualquer caminho que cancele um speak em andamento deve chamar `_ttsPlayer?.pause()` (o player bumpa generation, drena fila, stopa backend) e — se vinha de `isPlaying=true` — chamar `_flushSession` + `_saveProgress` + `_pushPlaybackState(false)`. Pra adicionar settings TTS novos no player: estender `TtsPlayerSettings` + adicionar um campo `_applied*` correspondente + atualizar `_currentTtsSettings()` no engine + tratar no `_applySettingsIfChanged` do player (cada `await` avança seu próprio `_applied*` após sucesso pra que aborts parciais não force re-aplicação total).
- **TTS backend `canPipeline`**: backends novos precisam declarar se conseguem enfileirar (`flutter_tts` → true via `setQueueMode`; SSIP socket → true via daemon; spd-say CLI → false porque cada speak spawn cancela o anterior). `TtsPlayer._effectiveLookahead` lê isso; um backend false-positive geraria audio sobreposto ou stop-loops invisíveis ao usuário.
- **TTS player callbacks no engine**: `_onPlayerWordAdvance` / `_onPlayerBookFinished` / `_onPlayerError` SEMPRE começam com `if (!mounted) return` — callbacks tardios chegando após autoDispose do engine notifier fariam ref.read explodir.
- **TTS audio handler unbind**: usar a referência cacheada em `_audioHandler` (não `_ref.read(ttsAudioHandlerProvider)`) em qualquer caminho dispose-adjacent. Riverpod pode ter tear down em andamento e `ref.read` levanta no meio do dispose.
- Apos alterar tables do Drift ou classes com `@freezed`: rodar `build_runner`.
- Apos alterar ARB files: rodar `flutter gen-l10n` (l10n.yaml ja configurado).
- **Persistir livros/artigos**: sempre via `persistParsedBook` (em `lib/features/book_library/data/services/book_persistence.dart`). Nunca duplicar o fluxo insert-book + fan-out de tokens.
- **Serializar/desserializar `tokensJson`**: sempre via `TokenCodec` (`lib/core/utils/token_codec.dart`) — nunca `jsonEncode(t.toJson())` direto. O formato v2 compacto (`{"v":2,"g":...,"p":[...]}`) deriva `globalIndex`/`paragraphIndex`/`isParagraphStart`/`isChapterStart` da estrutura (JSON ~8-10x menor, abertura de livro proporcionalmente mais rápida); o encode valida essas invariantes e cai no formato v1 (lista de maps) quando não valem. Livros antigos em v1 continuam legíveis e são re-encodados pra v2 em background na primeira abertura (`_upgradeTokenCache` no engine). Se mudar a estrutura do `WordToken`, atualizar codec + testes em `test/core/utils/token_codec_test.dart`.
- **Queries em `cached_tokens` que não precisam do blob** (`getAllChapterWordCounts` etc.) devem selecionar apenas colunas cobertas pelo índice `cached_tokens_book_id_idx` (bookId, chapterIndex, wordCount) — `wordCount` vem DEPOIS de `tokensJson` no record do SQLite, então ler a coluna direto da tabela força a leitura das overflow pages do blob de cada capítulo.
- **Comparar `source`**: usar as constantes de `BookSource` (`lib/database/tables/book_source.dart`), nunca literais `'epub'`/`'article'`.
- **URLs**: usar `UrlUtils.extractHttpUrl` / `parseWithHttpsFallback` em `lib/core/utils/url_utils.dart` — nao reimplementar parsing ad-hoc.
- **Font mapping**: usar `mapFontFamily()` de `lib/core/utils/font_mapper.dart` — nao reimplementar switch de nomes em cada widget.
- **Sync via Google Drive**: `DriveSyncFolderGateway` implementa `SyncFolderGateway` usando googleapis com scope `drive.file` (so enxerga arquivos que o proprio app criou). Auth abstraida por `DriveAuthBackend` (em `lib/features/library_sync/data/auth/`): `GoogleSignInDriveAuthBackend` em mobile, `DesktopOAuthDriveAuthBackend` em desktop (loopback OAuth via `googleapis_auth.clientViaUserConsent`, browser do sistema via `url_launcher`, refresh token em `flutter_secure_storage`/libsecret). `DriveAuthNotifier` so depende da abstracao — qualquer codigo abaixo (gateway, sync service, manifest) e identico entre plataformas. Silent sign-in no startup, connect explicito em Settings. Root folder "RSVP Reader" criada sob demanda; id cacheado em `SyncConfig.driveFolderId`. UI de sync escondida via `PlatformCapabilities.supportsDriveSync` quando credenciais OAuth nao foram baked-in (Linux sem `.env` preenchido). `.env` (gitignored) carregado em `main.dart` via `flutter_dotenv` antes de qualquer leitura de `supportsDriveSync`; template em `.env.example`. Pipeline detalhada em [docs/library-sync.md](docs/library-sync.md); setup desktop em [docs/linux-desktop.md](docs/linux-desktop.md#google-drive-sync).
- **Capacidades por plataforma**: usar `PlatformCapabilities` (`lib/core/utils/platform_capabilities.dart`) em vez de espalhar `Platform.isAndroid` / `Platform.isLinux`. Getters: `supportsShareIntent`, `supportsDriveSync`, `isDesktop`, `isMobile`. Linux usa `DesktopDropHandler` (drag-drop de EPUB/URL) e atalhos de teclado no reader (`Space`/`←→`/`↑↓`/`Esc`); detalhes em [docs/linux-desktop.md](docs/linux-desktop.md).
- **Sync de biblioteca so inclui EPUB**: `LibrarySyncService` filtra `source=='epub'`. Artigos sao sempre locais.
- **DateTime compare no sync: SEMPRE `isAtSameMomentAs`, nunca `==`**: local DateTime vem do Drift com `isUtc=false`, remote vem de JSON UTC com `isUtc=true`. `DateTime.==` compara `(micros, isUtc)` — mesmo instante registra como diferente, causando um write de DB por livro todo sync. Afeta qualquer code path que compare lastReadAt/progress.updatedAt/etc entre local e remoto.
- **Tombstone + syncFileName em sync**: um livro ativo sempre vence disputa de `syncFileName` contra um tombstone (em `_uploadMissingEpubs` o tombstone e pulado com `skippedTombstones`; em `_autoImportOrphanFiles` o filename tombstonado e tratado como "ja conhecido" para nao ressuscitar como orfao). Qualquer codigo novo que itere `merged.books` e opere por filename deve respeitar essa invariante. Tombstones cujo filename e reivindicado por um ativo sao compactados fora do merged antes do push.
- **Sync sharded** (`library/books.json` + `library/settings.json` + `library/sessions.json` + `library/bookmarks.json`): cada shard tem seu proprio `_*ShardEquals` que compara conteudo JSON-encoded ignorando `updatedAt`/`updatedBy`. Push paraleliza writes via `Future.wait`; shards inalterados nao sobem. O monolito `library.json` antigo e migrado in-memory na primeira sync e deletado em seguida. Ao adicionar campos novos a `SyncLibraryBook`/sessions/settings/bookmarks, garantir que entrem no `toJson` — os equals dependem disso. Sessions sao append-only por id (merge = uniao); rating tem seu proprio `ratingUpdatedAt` pro LWW imune a bumps de outros campos. **Bookmarks**: LWW puro por `updatedAt` (mais recente vence, incluindo seu `deletedAt`); o local snapshot vem de `BookmarksDao.getAllIncludingTombstones()` pra peers receberem deletes; remote tombstones de bookmarks que o DB local nunca viu sao ignorados em `_applyShardsToLocal` (peer ja shipa); e `_deleteBookLocally` cascateia em `_bookmarksDao.deleteAllForBook` — o tombstone do livro propaga a delecao, nao precisamos de tombstones por bookmark de um livro deletado.
- **`DriveSyncFolderGateway._fileIdCache`**: caches `fileId` por `(parentId, fileName)`. Populado opportunisticamente por `listFiles`, `readBytes`, e branch "create" de `writeBytes`. Consumido por todas as operacoes pra pular o `_findFile` (~500-700ms). `deleteFile` invalida a entrada; `clearCache()` no disconnect. Nao e thread-safe; assume uma unica sync em andamento por gateway (serializado pelo `LibrarySyncNotifier`).
- Testes unitarios dos core utils sao prioridade (ORP, timing, tokenizer, HTML stripper, readability). HTML stripper deve cobrir tags `_skipTags` para evitar regressao de CSS/JS vazando no texto. Logica pura de stats e engine tambem (`computeSessionAvgWpm`, `computeEffectiveWpm`, `buildSnapshot`, `buildMonthlyRecap`, `buildCompletionSummary`). Para testar o `RsvpEngineNotifier` use mocktail nas DAOs + stub do `LibrarySyncNotifier` (o real le `syncConfigProvider` no `schedulePush` e atrapalha o pending-async do flutter_test). Pra exercitar o pipeline de import sem fixture binario, use `test/fixtures/build_minimal_epub.dart` (constroi EPUB 2 valido em runtime via `archive`).
- **Share cards (recap, completion)**: paleta fixa (`_paper`, `_ink`, `_accent` etc. hardcoded nos widgets), NAO derivada de `Theme.of(context)` — exportacao deve ser consistente entre usuarios. Fonts via `GoogleFonts.inter()` / `GoogleFonts.lora()` (strings `'Inter'`/`'Lora'` nao sao asset families registrados).
- **Engine e finishTicket**: qualquer ponto novo de saida de `isPlaying=true` (alem de pause/end/ereader/dispose) deve chamar `_flushSession()` antes de zerar contadores. Fim-de-livro organico (`_advanceWord` hit end, nao seek) incrementa `state.finishTicket` para disparar a tela de completion.
- **Engine mode-change save**: ao adicionar uma nova transição de `ReaderMode` no engine (analogo a `enterEreaderMode` / `enterTtsMode` / etc), chamar `unawaited(_saveProgress())` no FIM, depois de mutar `state.mode`. `_saveProgress` dedup interno cobre `globalWordIndex` E `persistedReaderMode(state.mode)`, então uma mudança só de modo (sem progresso de palavra) ainda persiste, mas auto-restore + dois clicks no mesmo modo não geram writes redundantes. Não chamar `_saveProgress` ANTES da mutação — o save captura o `state.mode` no momento da chamada.
- **Arquivos pequenos**: widgets extraidos em arquivos focados (1 responsabilidade). Controles do reader: `rsvp_controls.dart` compoe; subwidgets em `controls_*.dart` + `seek_slider.dart`. Biblioteca: `library_screen.dart` compoe; subwidgets em `library_*.dart`.

## Docs detalhados

- [docs/architecture.md](docs/architecture.md) — arquitetura, fluxo de dados, providers
- [docs/rsvp-engine.md](docs/rsvp-engine.md) — motor RSVP, ORP, timing, ramp-up
- [docs/article-import.md](docs/article-import.md) — pipeline de artigos web, readability, share sheet
- [docs/reading-stats.md](docs/reading-stats.md) — sessions, stats dashboard, monthly recap, book completion, pipeline de export de PNG
- [docs/library-sync.md](docs/library-sync.md) — sync via Drive, manifest, merge rules, tombstones + compactacao, cache de fileId, invariantes de DateTime
- [docs/share-extension-ios.md](docs/share-extension-ios.md) — setup do share extension iOS (Xcode)
- [docs/linux-desktop.md](docs/linux-desktop.md) — build do Linux desktop, atalhos, drag-drop, limitações
- [docs/tts-mode.md](docs/tts-mode.md) — modo TTS, backend cross-platform (`flutter_tts` + `spd-say`), integração com engine, sentence extraction, WPM→rate, sync de settings
- [tasks.md](tasks.md) — bugs e features pendentes
