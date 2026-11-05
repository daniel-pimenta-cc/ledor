# Ledor

Flutter reader for EPUB books and web articles built around RSVP (Rapid Serial Visual Presentation). Targets Android, iOS, tablets and Linux desktop.

**Language:** code, comments, commit messages and docs are in English. User-facing strings never live in Dart code. They go through the ARB files (`lib/l10n/app_en.arb` + `app_pt.arb`), and every new key needs both languages.

## Commands

```bash
cp .env.example .env    # or `touch .env`: pubspec bundles .env as an asset, so the build fails without it
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Drift codegen (*.g.dart are committed)
flutter gen-l10n                                          # i18n bindings (lib/l10n/generated, committed)
flutter analyze
flutter test test/                                        # Linux needs lld + libsqlite3-dev
flutter test --coverage test/ && python3 tool/check_coverage.py --min 72  # CI coverage gate
flutter run
```

Releases: bump `version:` in pubspec (with `+buildNumber`), then push a `vX.Y.Z` tag. `.github/workflows/release.yml` builds a signed APK and a Linux tar.gz.

## Architecture

Feature-based Clean Architecture with Riverpod. See [docs/architecture.md](docs/architecture.md).

**Stack:** Flutter 3.x · Riverpod 2 (`StateNotifier`, no codegen) · Drift/SQLite · SharedPreferences · epub_pro · go_router · http · receive_sharing_intent (mobile) · google_sign_in (mobile) + googleapis_auth loopback (desktop) + googleapis (Drive v3) · flutter_secure_storage + url_launcher (desktop OAuth) · flutter_dotenv · google_fonts (Lora + Inter) · fl_chart · share_plus · desktop_drop (Linux) · scrollable_positioned_list · flutter_tts + `SpeechdSocketBackend` (Linux SSIP) · audio_service. Tests: flutter_test + mocktail + archive.

## Folder layout

```
lib/
  core/
    theme/       app_colors (AppPalette light/dark), app_theme, app_typography,
                 app_spacing (4..48), app_radius, app_motion, responsive
                 (Breakpoints compact 600 / medium 840, context.isTablet etc.)
    routing/     app_router (go_router), selected_book_provider (master-detail)
    constants/   app_constants, responsive_defaults
    di/          providers.dart (appDatabaseProvider + DAO providers)
    share/       share_intent_handler (mobile), desktop_drop_handler (Linux)
    widgets/     section_card, skeleton_loader
    utils/       orp_calculator, word_timing, text_tokenizer, html_stripper,
                 readability_extractor, token_codec, progress_index,
                 sentence_boundary, bookmark_snippet, url_utils, font_mapper,
                 sync_file_name, image_export_service, platform_capabilities,
                 voice_label_formatter, keep_screen_on
  database/      app_database (schema v11), tables/, daos/
  features/
    epub_import/     EPUB -> ParsedBook; domain/entities: word_token, chapter, parsed_book
    article_import/  URL -> readability -> ParsedBook
    book_library/    library_screen (master-detail host, tabs), library_* widgets,
                     data/services: book_persistence, inline_image_storage
    library_sync/    Google Drive sync (auth/, gateways/, services/, providers/)
    rsvp_reader/
      data/services/ tts_backend, flutter_tts_backend, speechd_socket_backend,
                     tts_player, tts_audio_handler
      domain/        entities: rsvp_state, display_settings, bookmark, sentence_segment;
                     utils: sentence_extractor
      presentation/  screens: rsvp_reader_screen, bookmarks_screen, fullscreen_image_screen
                     providers: rsvp_engine_provider, display_settings_provider,
                       bookmarks_provider, reader_side_panel_provider, tts_* providers
                     widgets: rsvp_word_display, context_scroll_view, rsvp_paragraph_view,
                       rsvp_controls + controls_* + seek_slider, reader_mode_fab,
                       wpm_selector, display_settings_panel, settings/sections/*, ...
    reading_stats/   stats dashboard, monthly recap, book completion, share cards
    settings/        settings_screen, theme_mode_provider
  l10n/          app_en.arb, app_pt.arb, generated/
```

## Key concepts

- **WordToken** (`epub_import/domain/entities/word_token.dart`): the unit of reading. ORP index and timing multiplier are computed at import, so the RSVP loop only multiplies in user settings (`computeWordIntervalMultiplier`). Tokens can also be images (`isImage`, shown by `RsvpImageView`).
- **ORP (Optimal Recognition Point)**: the focus letter at ~30% of the word, drawn in the accent color. See [docs/rsvp-engine.md](docs/rsvp-engine.md).
- **Long words in RSVP**: `RsvpWordDisplay` shrinks the font to keep the ORP letter on the anchor, but only down to `AppConstants.rsvpAnchorHoldMinScale` (70%). Below that, it shrinks only until the word fits (floor `rsvpMinFontSize`, 16) and shifts the word, and the indicator marks follow the letter.
- **Dialogue dashes**: a standalone dash (`—`, `–`, ...) is merged with the next word at display time by `mergeDialogueDash` (in `rsvp_engine_provider.dart`). This is intentionally not done at import, so token indices (progress, bookmarks, sync) never shift.
- **Two content sources, one pipeline** (`BookSource`): `epub` (file picker or Drive sync) and `article` (URL dialog or share sheet). Both become a `ParsedBook` -> `persistParsedBook` -> `books` + `cached_tokens`. Reading, progress and the engine are identical. See [docs/article-import.md](docs/article-import.md).
- **Reader modes** (`ReaderMode`): `rsvp` (single word, active while playing), `scroll` (full text with the current word highlighted, the paused view of RSVP), `ereader` (full text, no highlight, no controls) and `tts` (narration with highlight driven by the backend's word-boundary callback, rendered by `ContextScrollView(showHighlight: true)`). Users see three modes: `scroll` is not a separate choice (`menuModeOf` in `reader_mode_fab.dart`). In rsvp/scroll, play/pause switches between the two. In tts it drives the backend and keeps `mode=tts`.
  - `ReaderModeFab` is a floating pill at the bottom-left (bottom-right belongs to the lock pill). It hides during play and while the user scrolls down (`UserScrollNotification` in `rsvp_reader_screen`, so engine auto-scroll doesn't count).
  - **Per-book persistence**: `reading_progress.readerMode` (`'rsvp'`/`'ereader'`/`'tts'`, nullable). `scroll` collapses to `'rsvp'`. The helpers are `persistedReaderMode` / `parsePersistedReaderMode` in `rsvp_state.dart`. `_loadBook` restores it: ereader synchronously, tts via async `enterTtsMode()` with `isLoading` kept true until the player is ready. Synced as `SyncLibraryProgress.readerMode`.
- **TTS pipeline** ([docs/tts-mode.md](docs/tts-mode.md)): `TtsBackend` wraps `flutter_tts` (Android/iOS/macOS/Windows) and `SpeechdSocketBackend` (Linux, SSIP socket; if the socket is missing, `init` runs `speech-dispatcher --spawn` and retries). `ttsBackendProvider` picks the backend. `TtsPlayer` (`data/services/tts_player.dart`) owns the queue: a fixed lookahead of 2 segments via `TtsQueueMode.add`, segments from `extractSentenceFrom`, and callbacks `onWordAdvance`/`onBookFinished`/`onError` back to the engine.
  - Settings are applied field by field (`_applied*`), so a slider re-emitting the same value costs no IPC.
  - `_generation` invalidates late callbacks after pause, seek or dispose. `_isPlaying = true` is set **before** the first await so a same-tick `pause()` works.
  - Stall detection: a `_lastProgressAt` heartbeat. `restartIfStalled()` (called on app resume) restarts after 10s without progress.
  - Rate is independent of WPM: `DisplaySettings.ttsRate` (range `[0.5, 3.0]`, audiobook-style presets) is shown in the transport row as a `WpmCapsule` labelled by `formatTtsRate`. Reading sessions are logged normally.
- **TTS background playback** (`audio_service`): `main.dart` creates the `TtsAudioHandler` singleton via `AudioService.init`. The engine registers a `TtsAudioSource` (play/pause/skip) on entering TTS and calls `unbindIfActive` on dispose. The media notification shows title and author. On Linux/Web, `PlatformCapabilities.supportsBackgroundAudio` is false, the provider stays null and every call is a no-op.
- **TTS engine and voice pickers**: `ttsEnginesProvider` lists the engines. The picker row in `audio_section.dart` only shows with 2+ engines, outside compact mode. The choice persists in `DisplaySettings.ttsEngineId` and syncs. Backends ignore unknown ids but keep the value, so it survives the round trip. `enrichVoices` (`voice_label_formatter.dart`) turns technical voice names (`en-gb-x-fis-network`) into readable labels. Friendly iOS names are kept. `TtsVoicePickerSheet` has a current-language/all toggle and substring search.
- **DisplaySettings**: every visual and reading option, persisted via SharedPreferences. One `DisplaySettingsPanel` serves both the reader sheet/side panel and the full-screen Settings page.
- **Theme**: warm editorial palette (light "paper" / dark "ink"). The accent `#E55324` is the same in both. `themeModeProvider` stores system/light/dark. On a brightness change, `ThemeModeNotifier` calls `DisplaySettingsNotifier.applyBrightness()`, which swaps word and background colors and keeps ORP/highlight colors.
- **Typography**: Lora (serif) for display/headline/title, Inter for body/label. The RSVP font choices (Roboto Mono, JetBrains Mono, Fira Code, Source Code Pro, Lora, Source Serif 4) are mapped by `mapFontFamily()`.
- **Responsive / master-detail**: breakpoints in `responsive.dart`. The library grid uses `SliverGridDelegateWithMaxCrossAxisExtent` (200px), sized from the sliver's width. In tablet landscape, `LibraryScreen` splits into a 440px list plus the reader/placeholder, with `selectedBookIdProvider` choosing the book without a route change. Reader settings, chapters and bookmarks then open in `ReaderSidePanel` (`readerSidePanelProvider`) instead of bottom sheets. The context view caps line width (720px) on wide screens.
- **WPM selector**: `WpmSelector` (all-in-one, used in settings) or `WpmCapsule` + `WpmPresetRow` (reader controls). Presets are generated around the current value in steps of 50. The capsule's +/- buttons use `AppConstants.wpmStep`.
- **Library tabs**: `LibraryScreen` splits Books (`epub`) and Articles (`article`) with a `TabBar`, and `LibraryFab` changes its action per tab.
- **Reading sessions**: each continuous `isPlaying=true` stretch (play -> pause/end/ereader/dispose) becomes a `reading_session` row. Seeks during play don't break the session. `computeSessionAvgWpm` drops sessions under 3s or 5 words. **Ereader** logs manual sessions too: they open on entering or restoring the mode, count words from scroll-sync seeks (positive deltas ≤ 500), and close on exit, mode change or dispose. Sessions above 700 wpm are dropped as skimming. Always flush BEFORE mutating `state.mode`. See [docs/reading-stats.md](docs/reading-stats.md).
- **Stats, recap, completion** (`reading_stats`): `/stats` dashboard (weekly/monthly tabs, fl_chart), `/stats/recap` monthly recap with a shareable PNG, and `/books/:bookId/completion`, opened automatically at the organic end of a book (`RsvpState.finishTicket`). It can also be opened manually from "View completion" in the library long-press menu, or from `FinishBookButton` in the reader, which moves progress to the end. The 0-5 star rating is stored in `books.rating` + `ratingUpdatedAt` (its own LWW timestamp). Share cards are captured with `RepaintBoundary -> toImage -> share_plus`.
- **Lock + recenter** (`context_scroll_view.dart`): a floating pill at the bottom-right with a lock toggle (the scroll stops following the highlight) and recenter. Recenter measures the real `RenderBox` of the current word via the `highlightKey` passed into `RsvpParagraphView` + `getTransformTo(viewport)`, so it stays accurate in long paragraphs.
- **Bookmarks**: `bookmarks` table with `id, bookId, globalWordIndex, chapterIndex, endGlobalWordIndex?, endChapterIndex?, label?, contextSnippet?, createdAt, updatedAt, deletedAt?`. The end anchor is set for multi-word ranges. `deletedAt` is a soft-delete tombstone for sync. The code lives in `BookmarksDao` and in `bookmarks_provider.dart` (`bookmarksControllerProvider`).
  - **Creating a bookmark**:
    - RSVP: long-press the current word (`GestureDetector` in `rsvp_reader_screen`).
    - scroll/ereader/tts: `RsvpParagraphView` is a `SelectableText.rich`. Long-press selects text, and its `contextMenuBuilder` adds a "Save bookmark" item to the native selection toolbar. That item calls `onBookmarkRange(first, last)`, passed down through `ContextScrollView`.
    - Both paths go to `_onBookmarkRange` -> `showBookmarkDialog` with a snippet from `buildBookmarkSnippet` / `buildBookmarkRangeSnippet`.
  - **Bookmark lists**: `BookmarksList` is shared by `ReaderSidePanel` (`ReaderSidePanelMode.bookmarks`) and `BookmarksListSheet`. There is also a global `/bookmarks` screen.

## Rules

- **No hardcoded UI text**: every string goes through the ARB files. Run `flutter gen-l10n` after editing them.
- **Reader and DisplaySettings panel colors come from `DisplaySettings`, never `Theme.of(context)`**, so previews are live. The only exception is the Appearance section of `settings_screen.dart` (ThemeMode toggle).
- **Library and app chrome colors** (AppBar, cards, FAB, empty states, dialogs) come from `Theme.of(context).colorScheme`, never `AppColors.*` directly.
- **New display/reading option**: add the field to `DisplaySettings` + `copyWith` + load/save in `DisplaySettingsNotifier`, then add the UI in the matching file under `rsvp_reader/presentation/widgets/settings/sections/` (TTS options go in `audio_section.dart`). The reader sheet and the Settings page update together.
- **The settings panel has two modes**: `DisplaySettingsPanel(compact: true)` in the reader renders only `quickCategoriesFor(mode)`, and within those only rows that change mid-reading (each section gates the rest with `if (!compact)`). `compact: false` shows everything. By default, a new option appears only on the full page, which is right for set-once settings.
- **Sentence ends**: use `wordEndsSentence` from `lib/core/utils/sentence_boundary.dart` (used by `computeWordIntervalMultiplier` and `context_scroll_view`). Don't reimplement it.
- **New TTS exit path in the engine**: any path that cancels in-flight speech must call `_ttsPlayer?.pause()` (bumps the generation, drains the queue, stops the backend). If it came from `isPlaying=true`, it must also call `_flushSession` + `_saveProgress` + `_pushPlaybackState(false)`.
- **New TTS setting in the player**: the player reads `DisplaySettings` directly. Add an `_applied*` field and handle it in `_applySettingsIfChanged`. Each `await` advances its own `_applied*` only on success, so a partial abort doesn't force a full re-apply.
- **New TTS backends must queue natively**: `TtsPlayer` assumes a fixed 2-segment lookahead via `TtsQueueMode.add` (flutter_tts `setQueueMode(1)`, the SSIP daemon queue). A backend that cancels the previous utterance on each new one (like the removed `spd-say` CLI backend) causes overlapping audio or stop loops. Don't add one without making the lookahead configurable.
- **flutter_tts rate scale: 0.5 = normal speed** (Android doubles it internally; iOS maps 0.5 to the AVSpeech default). `FlutterTtsBackend.setRate` converts the audiobook scale with `flutterTtsRate()` (÷2, clamp [0.1, 1.5]). Passing `ttsRate` raw makes Android speak at 2x.
- **Every `FlutterTtsBackend` op goes through the `_enqueue` queue**: a concurrent `setEngine` corrupts the plugin (single Result slot; `onInit` clobbers language and voice). New backend methods must be enqueued too, and calls inside an enqueued op use `_tts.*` directly, never the public method, which would deadlock the queue.
- **Engine TTS callbacks** (`_onPlayerWordAdvance` / `_onPlayerBookFinished` / `_onPlayerError`) ALWAYS start with `if (!mounted) return`. Late callbacks after the notifier's autoDispose would make `ref.read` throw.
- **Audio handler unbind**: on any dispose-adjacent path, use the cached `_audioHandler`, not `_ref.read(ttsAudioHandlerProvider)`. Riverpod may be mid-teardown, and `ref.read` throws there.
- **Leaving `isPlaying=true` and finishTicket**: any new path out of `isPlaying=true` (besides pause/end/ereader/dispose) must call `_flushSession()` before resetting counters. Only an organic end of book (`_advanceWord` reaching the end, not a seek) increments `state.finishTicket`.
- **Mode changes in the engine**: a new `ReaderMode` transition (like `enterEreaderMode` / `enterTtsMode`) calls `unawaited(_saveProgress())` at the END, after mutating `state.mode`, because the save captures `state.mode` at call time. `_saveProgress` dedups on both `globalWordIndex` and `persistedReaderMode(state.mode)`, so mode-only changes persist without redundant writes.
- **Drift**: after changing tables or DAOs, run `build_runner`. Schema changes need a `schemaVersion` bump plus an idempotent step in `onUpgrade` (use the existing `addColumnIfMissing` / `createIndexIfMissing` helpers). There is no freezed/json_serializable: entities are hand-written Dart.
- **Persisting books/articles**: always via `persistParsedBook` (`lib/features/book_library/data/services/book_persistence.dart`). Never duplicate the insert-book + token fan-out flow.
- **`tokensJson`**: always serialize/deserialize via `TokenCodec` (`lib/core/utils/token_codec.dart`), never `jsonEncode(t.toJson())`.
  - The compact v2 format (`{"v":2,"g":...,"p":[...]}`) derives `globalIndex`/`paragraphIndex`/`isParagraphStart`/`isChapterStart` from the structure, which makes the JSON ~8-10x smaller. The encoder validates those invariants and falls back to v1 (a list of maps) when they don't hold.
  - v1 books stay readable and are re-encoded to v2 in the background on first open (`_upgradeTokenCache` in the engine).
  - If the `WordToken` structure changes, update the codec and `test/core/utils/token_codec_test.dart`.
- **`cached_tokens` queries that don't need the blob** (`getAllChapterWordCounts` etc.) must select only columns covered by the `cached_tokens_book_id_idx` index (bookId, chapterIndex, wordCount). `wordCount` sits after `tokensJson` in the SQLite record, so reading it from the table pulls every chapter's blob overflow pages.
- **Comparing `source`**: use the `BookSource` constants (`lib/database/tables/book_source.dart`), never `'epub'`/`'article'` literals.
- **URLs**: use `UrlUtils.extractHttpUrl` / `UrlUtils.parseWithHttpsFallback` (`lib/core/utils/url_utils.dart`).
- **Fonts**: use `mapFontFamily()` (`lib/core/utils/font_mapper.dart`). In widgets, use `GoogleFonts.*`: the strings `'Inter'`/`'Lora'` are not registered asset families.
- **Platform checks**: use `PlatformCapabilities` (`lib/core/utils/platform_capabilities.dart`: `supportsShareIntent`, `supportsDriveSync`, `supportsTts`, `supportsBackgroundAudio`, `isDesktop`, `isMobile`, `isLinux`) instead of scattering `Platform.isX`. Linux has drag-drop (`DesktopDropHandler`) and reader keyboard shortcuts. See [docs/linux-desktop.md](docs/linux-desktop.md).
- **Drive sync** ([docs/library-sync.md](docs/library-sync.md)): `DriveSyncFolderGateway` implements `SyncFolderGateway` with the `drive.file` scope (it only sees files the app created), in a "Ledor" root folder whose id is cached in `SyncConfig.driveFolderId`.
  - Auth sits behind `DriveAuthBackend` (`library_sync/data/auth/`): `GoogleSignInDriveAuthBackend` on mobile and `DesktopOAuthDriveAuthBackend` on desktop.
  - The desktop backend uses its own loopback server with `access_type=offline&prompt=consent`, redirects to https://ledor.app/auth/ after consent, exchanges the code via `obtainAccessCredentialsViaCodeExchange`, and stores the refresh token in `flutter_secure_storage`.
  - Everything above the auth layer is platform-agnostic.
  - OAuth credentials come from `.env` (`LEDOR_OAUTH_CLIENT_ID`/`SECRET`, template in `.env.example`), loaded in `main.dart` before any `supportsDriveSync` read. Without them, sync UI is hidden. Sync is only available on Android and Linux. Desktop setup: [docs/linux-desktop.md#google-drive-sync](docs/linux-desktop.md#google-drive-sync).
- **Only EPUBs sync**: `LibrarySyncService` keeps `source == BookSource.epub`. Articles are always local.
- **Sync DateTime compare: ALWAYS `isAtSameMomentAs`, never `==`**. Local DateTimes come from Drift with `isUtc=false`, remote ones from JSON with `isUtc=true`. `DateTime.==` compares `(micros, isUtc)`, so the same instant looks different and every sync writes every book. This applies to any local/remote compare (lastReadAt, progress.updatedAt, ...).
- **Sync progress travels as a GLOBAL cursor, never a raw `(chapterIndex, wordIndex)`**. The pair only means something within the tokenization that produced it. The same EPUB parsed by a newer build can split into a different number of chapters (image tokens, front-matter sections), so progress would land in the wrong place.
  - `SyncLibraryProgress.globalWordIndex` carries the cursor. `_applyRemoteProgress` re-anchors it with `globalToLocalWordIndex` over the LOCAL `cached_tokens`, and `_sameCursor` compares in global space.
  - Conversions live in `lib/core/utils/progress_index.dart`. The field is nullable on purpose: shards from old builds fall back to the raw pair.
  - Accepted residual: if two tokenizations differ by N tokens before the cursor, the position shifts by N words.
- **Tombstones vs `syncFileName`**: an active book always wins a `syncFileName` clash with a tombstone. `_compactZombieTombstones` drops tombstones whose filename an active book claims before the push. `_uploadMissingEpubs` never deletes a file an active book claims. `_autoImportOrphanFiles` treats tombstoned filenames as known, so they don't come back as orphans. New code that iterates `merged.books` by filename must keep this invariant.
- **Sharded sync**: the shards are `library/books.json`, `settings.json`, `sessions.json` and `bookmarks.json`.
  - A shard is pushed (in parallel via `Future.wait`) only if its content changed: `_rowsEqual` compares rows by id via JSON-encoded `toJson()`, and `_settingsShardEquals` handles settings. Shard envelope `updatedAt`/`updatedBy` are ignored. **New fields on `SyncLibraryBook`/sessions/settings/bookmarks must be in `toJson`**, or changes never push.
  - The legacy `library.json` monolith is migrated in memory on first sync, then deleted.
  - Sessions are append-only by id (merge = union). Rating has its own `ratingUpdatedAt` LWW.
  - **Bookmarks** are pure LWW by `updatedAt`, `deletedAt` included. The local snapshot comes from `BookmarksDao.getAllIncludingTombstones()` so deletes reach peers. Remote tombstones for bookmarks never seen locally are skipped in `_applyShardsToLocal`. `_deleteBookLocally` cascades via `_bookmarksDao.deleteAllForBook`: the book tombstone carries the delete, so no per-bookmark tombstones are needed.
- **`DriveSyncFolderGateway._fileIdCache`** caches `fileId` by `(parentId, fileName)`. It is filled by `listFiles`, `readBytes` and the create branch of `writeBytes`, and lets every op skip `_findFile` (~500-700ms). `deleteFile` invalidates an entry, and `clearCache()` runs on disconnect. It is not thread-safe: `LibrarySyncNotifier` serializes syncs, one per gateway.
- **Share cards (recap, completion)** use a fixed palette (`_paper`, `_ink`, ... hardcoded in the widgets), NOT `Theme.of(context)`, so exports look the same for everyone.
- **Tests**: unit-test core utils (ORP, timing, tokenizer, HTML stripper incl. `_skipTags` so CSS/JS never leaks into text, readability) and pure stats/engine logic (`computeSessionAvgWpm`, `computeEffectiveWpm`, `mergeDialogueDash`, the `build*` functions in the `reading_stats` providers).
  - To test `RsvpEngineNotifier`, use mocktail for the DAOs and stub `LibrarySyncNotifier`. The real one reads `syncConfigProvider` in `schedulePush` and breaks flutter_test's pending-async check.
  - Fixtures in `test/fixtures/`: `build_minimal_epub.dart` builds a valid EPUB 2 at runtime, and `fake_sync_folder_gateway.dart` is an in-memory Drive.
- **Small files**: extract widgets into focused files. `rsvp_controls.dart` composes `controls_*.dart` + `seek_slider.dart`, and `library_screen.dart` composes `library_*.dart`.

## Docs

- [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md)
- [docs/architecture.md](docs/architecture.md): architecture, data flow, providers
- [docs/rsvp-engine.md](docs/rsvp-engine.md): engine, ORP, timing, ramp-up, word display, dialogue dashes
- [docs/article-import.md](docs/article-import.md): web article pipeline, readability, share sheet
- [docs/reading-stats.md](docs/reading-stats.md): sessions, stats, recap, completion, PNG export
- [docs/library-sync.md](docs/library-sync.md): Drive sync, merge rules, tombstones, fileId cache, DateTime invariants
- [docs/tts-mode.md](docs/tts-mode.md): TTS mode, backends, engine integration, sentence extraction
- [docs/linux-desktop.md](docs/linux-desktop.md): Linux build, shortcuts, drag-drop, Drive setup
- [docs/share-extension-ios.md](docs/share-extension-ios.md): iOS share extension setup (Xcode)
