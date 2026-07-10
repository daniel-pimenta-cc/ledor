# Ponytail Audit — 2026-07-04

Auditoria de over-engineering no repo inteiro (só complexidade; correção/segurança/perf fora do escopo).
Todos os achados verificados com grep de callers em `lib/` e `test/`. Ranking do maior corte pro menor.

Tags: `delete` código morto · `stdlib` já existe no SDK/pacote instalado · `native` a plataforma já faz · `yagni` abstração sem uso · `shrink` mesma lógica em menos linhas.

## Achados

- [x] `delete` SpeechDispatcherBackend (spd-say CLI) — só alcançável na janela "daemon ainda não spawnado" da 1ª sessão; ~10 linhas de autospawn no `SpeechdSocketBackend.init` substituem o backend + fallback + teste; cascade: `canPipeline` vira sempre true → `_lookaheadSequential`/`largeChunks`/`kSentenceMaxTokensLargeChunk` caem junto. [lib/features/rsvp_reader/data/services/speech_dispatcher_backend.dart] (~445+45) — **contraria decisão documentada no CLAUDE.md; aprovado em 2026-07-04**
- [x] `yagni` toolchain freezed inteira (freezed, freezed_annotation, json_serializable, json_annotation) pra UMA classe (`WordToken`). Classe imutável à mão (~80 linhas), some o `.freezed.dart`/`.g.dart`. [lib/features/epub_import/domain/entities/word_token.dart] (−4 deps)
- [x] `shrink` TtsRateCapsule + `_StepIcon` + `_PresetChip` = cópia byte a byte de WpmCapsule/`_StepIcon`/`_PresetChip`. `WpmCapsule(label: formatTtsRate(rate))` + exportar o chip do wpm_selector. [lib/features/rsvp_reader/presentation/widgets/tts_rate_selector.dart] (~145)
- [x] `shrink` 5 bottom sheets repetem o mesmo scaffold (DraggableScrollableSheet + drag handle + título + Divider). Um `ReaderSheetShell(title, child)`. [reader_settings_sheet.dart, chapter_list_sheet.dart, bookmarks_list_sheet.dart, tts_voice_picker_sheet.dart, tts_engine_picker_sheet.dart] (~120)
- [x] `delete` `mergeLibraries()` — só teste chama; o fluxo real usa merge por shard. Cortar função + grupo de teste. [lib/features/library_sync/domain/entities/sync_library.dart:319] (~95)
- [x] `delete` dep `riverpod_annotation` — zero imports. [pubspec.yaml] (−1 dep)
- [x] `delete` dev dep `integration_test` + diretório `integration_test/` vazio. [pubspec.yaml] (−1 dep)
- [x] `delete` dep direta `json_annotation` — nunca importada direto; `freezed_annotation` re-exporta. [pubspec.yaml] (−1 dep)
- [x] `delete` `AppShadows` inteiro (level1..4) — zero callers. [lib/core/theme/app_elevations.dart] (~59)
- [x] `native` `_detectExtension` (magic bytes PNG/JPG/GIF/BMP/WEBP) — o decoder do Flutter detecta formato pelos bytes e ninguém lê a extensão; sufixo fixo `.img`. [lib/features/book_library/data/services/inline_image_storage.dart:69] (~50)
- [x] `shrink` bloco `bottomTitles`/`getTitlesWidget` duplicado nos 3 charts → `dayAxisTitles(buckets, scheme)` compartilhado. [stats_words_per_day_chart.dart:146, stats_time_per_day_chart.dart:92, stats_wpm_trend_chart.dart:114] (~48)
- [x] `delete` `Bookmark.copyWith` (6 flags `clear*`) + getters `isRange`/`isTombstone` — zero callers. [lib/features/rsvp_reader/domain/entities/bookmark.dart:44] (~42)
- [x] `shrink` `_Cover`/`_FallbackCover` duplicados entre os 2 share cards → widget compartilhado com 2 params (paleta fixa preservada). [monthly_recap_card.dart:289, book_completion_card.dart:291] (~40)
- [x] `shrink` `_ChapterList` do side panel duplica o ListTile-builder do `ChapterListSheet` → `ChapterTile` compartilhado. [reader_side_panel.dart:158] (~40)
- [x] `native` `_FocusLine` (Stack + 2 ColoredBox + LayoutBuilder) → `LinearProgressIndicator(value:, minHeight:)`. [lib/features/rsvp_reader/presentation/widgets/rsvp_word_display.dart:315] (~35)
- [x] `shrink` ~40 linhas idênticas nos 2 `DriveAuthBackend` (keys, scopes, `_hasCredentials`, `signOut` etc) → base class abstrata. [google_sign_in_drive_auth_backend.dart:31, desktop_oauth_drive_auth_backend.dart:38] (~30)
- [x] `yagni` `TtsPlayerSettings` espelha 5 campos de `DisplaySettings` (value class pura) → player recebe `DisplaySettings` direto; `largeChunks` vira param do ctor. [lib/features/rsvp_reader/data/services/tts_player.dart:14] (~30)
- [x] `shrink` `_booksShardEquals`/`_sessionsShardEquals`/`_bookmarksShardEquals` = mesmo algoritmo 3x → genérico `_rowsEqual<T>`. [lib/features/library_sync/data/services/library_sync_service.dart:961] (~28)
- [x] `stdlib` 4 formatadores de número à mão → `NumberFormat.compact(locale:)` / `.decimalPattern()` (intl já é dep). [stats_summary_cards.dart:51, monthly_recap_card.dart:113, book_completion_card.dart:213, book_completion_screen.dart:243] (~28)
- [x] `delete` `SyncFolderGateway.fileExists` — zero callers de produção (interface, gateway, fake, teste). [lib/features/library_sync/domain/repositories/sync_folder_gateway.dart:26] (~26)
- [x] `delete` cadeia `onStart` do TtsBackend — único assinante é método vazio no player. [lib/features/rsvp_reader/data/services/tts_backend.dart:154] (~25)
- [x] `delete` `TtsBackend.getLanguages()` — zero callers (interface + 3 impls + 3 stubs). [lib/features/rsvp_reader/data/services/tts_backend.dart:107] (~22)
- [x] `delete` `WordToken.imageWidth/imageHeight` + `ResolvedImage.width/height` + `'w'/'h'` no codec — produção sempre passa null, nenhum widget lê. [word_token.dart:38, chapter_parser.dart:14, token_codec.dart:100] (~20)
- [x] `delete` 10 dos 13 params de `SyncLibraryBook.copyWith` nunca passados → só deletedAt/updatedAt/progress. [lib/features/library_sync/domain/entities/sync_library.dart:87] (~20)
- [x] `delete` campos de stats nunca lidos: `DailyBookSlice.durationMs`, `BookBreakdown.author/totalWords`, `StatsSnapshot.from/to` + acumuladores. [stats_snapshot.dart:6, reading_stats_provider.dart:66] (~19)
- [x] `delete` `ReadingSessionDao.getSessionsInRange` — só o próprio teste; produção usa `watchSessionsInRange`. [lib/database/daos/reading_session_dao.dart:45] (~19)
- [x] `delete` `toggleEreaderMode()` — só teste chama; o menu usa enter/exit direto. [lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart:371] (~19)
- [x] `stdlib` `charOffsetToTokenIndex` (busca binária manual) → `lowerBound(o, t + 1) - 1` (package:collection). [lib/features/rsvp_reader/domain/utils/sentence_extractor.dart:137] (~18)
- [x] `delete` wrappers `@visibleForTesting` sem teste usando (`parseEngineListForTest`, `parseEngineLinesForTest`, `parseVoiceLinesForTest`, `wordCharOffsetsForTest` x2). [speechd_socket_backend.dart:564, speech_dispatcher_backend.dart:287] (~18)
- [x] `delete` `ImportState.errorMessage` + `ArticleImportState.errorMessage` — nenhuma UI mostra (toasts usam l10n genérico). [epub_import_provider.dart:24, article_import_provider.dart:19] (~17)
- [x] `delete` `SyncLibrary.empty` (0 callers) + `encode`/`toJson` (só fixture de teste — o app só decoda o monolito legado). [lib/features/library_sync/domain/entities/sync_library.dart:201] (~14)
- [x] `shrink` `_LocalShards` e `_MergedShards` idênticas → uma classe/record. [lib/features/library_sync/data/services/library_sync_service.dart:1092] (~14)
- [x] `delete` `ReadingSessionDao.deleteSessionsForBook` — só teste; delete de livro preserva sessions de propósito. [lib/database/daos/reading_session_dao.dart:119] (~14)
- [x] `yagni` `DriveAuthState.copyWith` com flags clear* usado 2x → construtor direto. [lib/features/library_sync/presentation/providers/drive_auth_provider.dart:22] (~14)
- [x] `native` `createTableIfMissing` + `_tableExists` — `Migrator.createTable` do drift já emite `CREATE TABLE IF NOT EXISTS` (guards de índice/coluna FICAM). [lib/database/app_database.dart:98] (~13)
- [x] `stdlib` `_orpIndicatorFromName`/`_timeRemainingModeFromName` → `values.asNameMap()[raw]`. [lib/features/library_sync/data/services/library_sync_service.dart:109] (~13)
- [x] `delete` `RecapBook.avgWpm`/`totalWords`/`isFinished` — card não lê. [monthly_recap.dart:9, monthly_recap_provider.dart:79] (~12)
- [x] `shrink` cálculo hours/minutes + ternário de l10n copiado 3x → helper `formatDuration(l10n, ms)`. [stats_summary_cards.dart:16, book_completion_screen.dart:100, book_completion_card.dart:172] (~12)
- [x] `stdlib` `_parseOrpIndicator`/`_parseTimeRemainingMode` → `values.asNameMap()`. [display_settings_provider.dart:90] (~12)
- [x] `yagni` `WpmSelector` expõe min/max/smallStep/presetStep/presetRadius e nenhum caller seta → hardcodar. [wpm_selector.dart:44] (~12)
- [x] `delete` branch fallback do `SkeletonBox` sem `SkeletonHost` → `maybeOf` vira `of`. [lib/core/widgets/skeleton_loader.dart:71] (~12)
- [x] `stdlib` extensão `isLetterOrDigit` com ranges Latin hardcoded → `RegExp(r'[\p{L}\p{N}]', unicode: true)` (padrão que word_timing.dart já usa). [lib/core/extensions/string_extensions.dart] (~11)
- [x] `shrink` Companion de progresso remoto montado 3x → `_applyRemoteProgress(bookId, p)`. [library_sync_service.dart:528,749,795] (~11)
- [x] `delete` `LibraryEmptyState.ctaLabel/onCta` — único caller não passa CTA. [library_empty_state.dart:11] (~10)
- [x] `stdlib` switch string→ThemeMode → `ThemeMode.values.asNameMap()[raw] ?? system`. [theme_mode_provider.dart:20] (~10)
- [x] `yagni` `DriveSignInResult` embrulha uma String → `Future<String?>` direto. [drive_auth_backend.dart:5] (~10)
- [x] `shrink` `ChapterWordCount` → record typedef `({String bookId, int chapterIndex, int wordCount})`. [cached_tokens_dao.dart:96] (~10)
- [x] `delete` `allBookmarksProvider` — a tela global usa o próprio join provider. [bookmarks_provider.dart:29] (~10)
- [x] `delete` classe `AppColors` back-compat — zero callers e o CLAUDE.md já proíbe. [app_colors.dart:98] (~10)
- [x] `stdlib` while-loop em `_findNextBoundary` → `lowerBound(boundaries, pos + 1)`. [context_scroll_view.dart:511] (~9)
- [x] `delete` `TtsVoice.engineId` — nunca setado nem lido. [tts_backend.dart:11] (~9)
- [x] `yagni` params `coverImage`/`imageStorage` de `persistParsedBook`/`persistChaptersWithImages` — nenhum caller passa. [book_persistence.dart:34] (~8)
- [x] `shrink` loop skip-whitespace em `TokenCodec.isCompact` → `s.trimLeft().startsWith('{')`. [token_codec.dart:32] (~8)
- [x] `delete` `BookmarksDao.getForBook` — só teste; trocar por `watchForBook(id).first`. [bookmarks_dao.dart:22] (~8)
- [x] `delete` `PlatformCapabilities.isAndroid` — zero callers. [platform_capabilities.dart:49] (~7)
- [x] `delete` params mortos: `SyncConfig.copyWith(deviceId, clearLastSyncedAt)`, `LibrarySyncState.copyWith(lastSyncedAt)`. [sync_config.dart:27, library_sync_provider.dart:113] (~7)
- [x] `delete` `TtsPlayer.currentGlobalIndex` + `isPlaying` — zero callers de produção. [tts_player.dart:183] (~7)
- [x] `native` override no-op `TtsAudioHandler.seek` — `BaseAudioHandler` já é no-op. [tts_audio_handler.dart:149] (~7)
- [x] `stdlib` `_isSentenceEnd` reimplementa `wordEndsSentence` (CLAUDE.md manda usar; a cópia nem cobre `…`). [context_scroll_view.dart:497] (~6)
- [x] `delete` `SentenceSegment.length` — doc diz "o engine usa", zero callers. [sentence_segment.dart:44] (~6)
- [x] `stdlib` fold-max à mão nos charts → `.max`/`maxOrNull` (package:collection). [stats_wpm_trend_chart.dart:34, stats_time_per_day_chart.dart:17, stats_words_per_day_chart.dart:99] (~6)
- [x] `delete` `BookmarksDao.applyFromSync` — corpo idêntico ao `upsert`. [bookmarks_dao.dart:79] (~6)
- [x] `yagni` classe `ImageExportService` sem estado → função top-level `shareWidgetAsPng`. [image_export_service.dart:16] (~6)
- [x] `delete` `BookmarksDao.getById` — só testes. [bookmarks_dao.dart:38] (~5)
- [x] `delete` `appDocumentsDirProvider` + imports órfãos. [lib/core/di/providers.dart:42] (~5)
- [x] `delete` `AppConstants.rsvpWordMargin` — obsoleto pelo homônimo em ResponsiveDefaults. [app_constants.dart:61] (~5)
- [x] `delete` `clampTtsRate` — o engine clampa inline e nunca chama. [tts_rate_selector.dart:269] (~5)
- [x] `native` guard de set vazio em `retainOnly` — drift converte `isNotIn([])` em `Constant(true)`. [sync_import_failures_dao.dart:49] (~4)
- [x] `delete` `AppTheme.buildDark` ("fallback for tests" sem teste). [app_theme.dart:212] (~3)
- [x] `delete` `ImportStatus.picking` — setado e nunca lido. [epub_import_provider.dart:20] (~3)
- [x] `delete` `AppDurations.page` + `AppCurves.decelerate` — zero callers. [app_motion.dart:7] (~2)
- [x] `yagni` `RecapMonth.current({DateTime? now})` — `now` nunca passado. [monthly_recap_provider.dart:14] (~2)
- [x] `delete` `Breakpoints.expanded` — zero callers. [responsive.dart:6] (~1)
- [x] `delete` `rsvp_reader.iml` — resto de IntelliJ com nome antigo. [rsvp_reader.iml] (~17)

## Notas

- Dep `collection` hoje tem zero imports — os achados `stdlib` de `lowerBound`/`.max` passam a usá-la; se não fossem aplicados, seria o 7º corte de dep.
- CLAUDE.md cita `gridCrossAxisCount()`/`gridAspectRatio()` que não existem mais (drift de doc) — corrigir junto.
- CLAUDE.md/docs mencionam `app_elevations`/`AppShadows` e `SpeechDispatcherBackend`/spd-say — atualizar após os cortes.

**net: ~-1.800 linhas, -6 deps.**
