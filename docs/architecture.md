# Architecture

## Pattern

Feature-based Clean Architecture with internal layers per feature:
- `domain/entities/` — pure models (plain Dart)
- `data/` — services, repository implementations
- `presentation/` — providers (Riverpod), screens, widgets

## Design System

Editorial palette with warm tones in two modes (light and dark). Orange accent #E55324 preserved in both.

**Tokens** in `lib/core/theme/`:
- `app_colors.dart` — `AppPalette.light` / `AppPalette.dark` (full palettes with `toColorScheme()`).
- `app_theme.dart` — `AppTheme.build(brightness:)` produces a complete `ThemeData` covering AppBar, Card, Button (filled/text/outlined/icon), Slider, BottomSheet, Dialog, Input, SnackBar, Divider, ListTile, FAB, TabBar, pageTransitions. Applies `AppTypography.build(colorScheme)`.
- `app_typography.dart` — Lora (serif) for display/headline/title; Inter (sans) for body/label. `sectionHeader()` for uppercase tracked dividers.
- `app_spacing.dart` — scale xs(4)/sm(8)/md(12)/base(16)/lg(24)/xl(32)/xxl(48).
- `app_radius.dart` — sm(6)/md(10)/lg(16)/xl(24) plus `BorderRadius` const helpers and `borderTopXl`.
- `app_motion.dart` — `AppDurations` (fast/base/slow) plus `AppCurves` (standard/emphasized).
- `responsive.dart` — `Breakpoints` (compact 600 / medium 840), `DeviceType` enum, extensions `context.isTablet`/`isLandscape`/`deviceType`.

**Color usage rules**:
- Library, chrome, dialogs: `Theme.of(context).colorScheme.*`
- Inside the reader and DisplaySettings panel: `DisplaySettings.wordColor` / `.backgroundColor` etc. (live preview)

**Light/dark theme**: `ThemeModeNotifier` persists to SharedPreferences. When the effective brightness changes, it calls `DisplaySettingsNotifier.applyBrightness(newBrightness)` which flips wordColor + backgroundColor to the matching palette. ORP and highlight stay intact.

## Features and responsibilities

### book_library
Main screen with responsive master-detail. `LibraryScreen` picks the layout:
- **Compact / portrait**: Scaffold with fullscreen TabBarView, navigation via `context.push('/reader/:id')`.
- **Tablet landscape**: `Row` with list (440px) + `VerticalDivider` + reader/placeholder. `selectedBookIdProvider` controls which book is open in the right panel without changing routes.

Extracted widgets:
- `LibraryList` — categorised grid (In Progress / Not Started / Read). `SliverGrid` with `maxCrossAxisExtent: 200`, so the column count follows the sliver's width (including the 440px master pane). Pull-to-refresh triggers a sync when sync is configured. Long-press opens a book action sheet (view completion, bookmarks, mark as read, delete).
- `BookCard` — cover or gradient fallback, title, subtitle, `ReadingProgressBar`, scale-on-press with haptic, highlight when selected in master-detail.
- `LibraryFab` — FAB with busy/idle state, action depends on the active tab (EPUB file picker / article URL dialog).
- `LibraryAppBarBottom` — TabBar plus a conditional `LibraryImportProgressBar`.
- `LibrarySkeleton` — grid of `SkeletonBookCard` with shimmer during loading.
- `LibraryEmptyState` — circular icon + serif title + subtitle + optional CTA.
- `LibrarySectionHeader` — uppercase tracked label + count badge.
- `ReaderPlaceholder` — empty panel on tablet ("Pick a book to begin").

Sub-module `data/services/book_persistence.dart` contains `persistParsedBook` — a helper shared between `epub_import` and `article_import`. **Every import must go through it**.

### epub_import
Pipeline: EPUB bytes → `epub_pro` → chapters → `ChapterParser` → `List<WordToken>` → `ParsedBook` → `persistParsedBook`. `ChapterParser` walks the chapter DOM directly (instead of `HtmlStripper` + `TextTokenizer`) so inline images get their own `isImage` token at their position; its text path mirrors `TextTokenizer`. `persistParsedBook` stores the images via `InlineImageStorage` and encodes tokens with `TokenCodec`.

### article_import
Pipeline: URL → `http.get` → HTML → `ReadabilityExtractor` → `HtmlStripper` → `TextTokenizer` → `ParsedBook` (1 chapter) → `persistParsedBook(source: BookSource.article)`. Details in [article-import.md](article-import.md).

### library_sync
Syncs the library manifest, `reading_progress`, `DisplaySettings`, ratings, reading sessions, and bookmarks through a "Ledor" folder the app creates in the user's Google Drive (scope `drive.file` — it only sees files the app itself created). Available on **Android** and **Linux desktop**.

Single gateway via `DriveSyncFolderGateway` (implements `SyncFolderGateway`); the per-platform auth is abstracted behind `DriveAuthBackend` (`lib/features/library_sync/data/auth/`): `GoogleSignInDriveAuthBackend` on mobile, `DesktopOAuthDriveAuthBackend` on desktop (its own loopback server on `http://localhost:<port>`, consent in the system browser via `url_launcher`, code exchanged with `googleapis_auth.obtainAccessCredentialsViaCodeExchange`, refresh token in `flutter_secure_storage`/libsecret). Both need the OAuth client in `.env`; without it `PlatformCapabilities.supportsDriveSync` hides the Sync UI. `DriveAuthNotifier` only depends on the abstraction, so the gateway / sync service / manifest code is identical across platforms. `SyncConfig.driveFolderId` caches the root folder id. **Filters `source='epub'`** — articles are always local. Uploading the EPUB files themselves is optional (`SyncConfig.syncEpubs`, default on).

The manifest is sharded into four files (`library/books.json`, `library/settings.json`, `library/sessions.json`, `library/bookmarks.json`); pushes parallelise writes via `Future.wait` and skip any shard whose content is unchanged (ignoring `updatedAt`/`updatedBy`). Sessions are append-only by id; rating uses a dedicated `ratingUpdatedAt` for per-field LWW so unrelated bumps don't clobber a fresh rating; bookmarks are LWW by `updatedAt`, with soft-delete tombstones. Progress travels as a global word index and is re-anchored against the local tokenization.

`LibrarySyncService.sync()` pipeline:
1. `isReadable` probe on the folder (throws the real cause — token, network, rate limit — on hard failures).
2. Parallel reads: the four shards, the legacy `library.json` (migrated in memory and deleted on push), and `listFiles(books/)`.
3. `_autoImportOrphanFiles` — EPUBs dropped directly into the Drive folder become new local books (respecting tombstones so deletes don't resurrect).
4. Local snapshot + per-shard merge (`mergeBooksShard`, `mergeSettingsShard`, `mergeSessionsShard`, `mergeBookmarksShard`), then **zombie tombstone compaction**: a tombstone sharing `syncFileName` with an active row is dropped, so its delete can't clobber the active row's file.
5. `_applyShardsToLocal` — applies progress, lastReadAt, ratings, sessions, bookmarks, settings, and tombstone deletes. **DateTime compare via `isAtSameMomentAs`** (local comes from Drift with `isUtc=false`, remote from UTC JSON; `==` would always say different).
6. Push only the shards that changed.
7. `_uploadMissingEpubs` — uploads EPUBs missing from `books/`; tombstones that collide with an active row are skipped.

`DriveSyncFolderGateway` caches folder ids and file ids by `(parentId, fileName)`, so read/write/delete on a known file skip `_findFile` (~500-700ms each). Details in [library-sync.md](library-sync.md).

### rsvp_reader
Core feature. Widgets organised into focused files:

**Screen:**
- `RsvpReaderScreen` — hosts every `ReaderMode` (`rsvp`, its paused `scroll` view, `ereader`, `tts`). `ReaderModeFab` (bottom-left) switches modes. Accepts an `onClose` callback for master-detail. On tablet landscape it renders `ReaderSidePanel` next to the body when active. On desktop it binds keyboard shortcuts.

**Engine:**
- `RsvpEngineNotifier` — Ticker-based. Play/pause/seek/speed/ramp-up plus `ReaderMode`. Saves progress on pause and on mode changes; restores the per-book mode (`reading_progress.readerMode`) on load.

**TTS** (`data/services/`, details in [tts-mode.md](tts-mode.md)):
- `TtsBackend` with two implementations: `FlutterTtsBackend` (Android/iOS/macOS/Windows) and `SpeechdSocketBackend` (Linux, SSIP socket to speech-dispatcher), picked by `ttsBackendProvider`.
- `TtsPlayer` — sentence queue with a 2-segment lookahead; reports word progress back to the engine.
- `TtsAudioHandler` — `audio_service` handler for background playback and lockscreen controls (not on Linux).

**Bookmarks:** `BookmarksDao` + `bookmarksProvider`. Created from a long-press on the RSVP word or a text selection in `RsvpParagraphView` (`showBookmarkDialog` in `bookmark_create_dialog.dart`); listed by `BookmarksList` (side panel or `BookmarksListSheet`) and the library-wide `BookmarksScreen` (`/bookmarks`).

**RSVP display:**
- `RsvpWordDisplay` — RichText with ORP anchor. Auto-scales long words. Margins and font scale are responsive via `ResponsiveDefaults`.

**Context mode:**
- `ContextScrollView` — virtualised list of chapters + paragraphs. Highlight via a local ValueNotifier, velocity-based stepping, syncs with the engine on scroll end. `ConstrainedBox(maxWidth: 720)` on wide screens. `showHighlight: false` serves the ereader mode. A floating bottom-right overlay houses a **lock** toggle (freezes the scroll while the engine keeps advancing) and a **recenter** button that measures the highlighted word's actual `RenderBox` via `GlobalKey` + `getTransformTo(viewport)` so long-paragraph centring is pixel-accurate, not character-fraction-estimated.
- `RsvpParagraphView` — extracted public widget that renders a single paragraph's tokens with the highlight pill, as one `SelectableText.rich` whose selection toolbar offers "Save bookmark". Lives outside `ContextScrollView` so it's testable without the engine provider.

**Controls (dock):**
- `RsvpControls` — compositor. `AnimatedSize` on the column so it grows when the WPM drawer opens.
- `ControlsShell` — translucent surface with backdrop blur and a top border.
- `ControlsProgressRow` — percentage, remaining time (tabular figures) and the chapter counter, which opens the chapter list. The chapter *title* lives in the top bar, where it doubles as the chapter button.
- `ControlsTransportRow` — play 64px with `AnimatedSwitcher` (scale+fade), skips 48px, `WpmCapsule`. Layout: `LayoutBuilder` with a 520px breakpoint — `Stack` (inline, WPM on the right) on wide screens, `Column` (stacked) on narrow ones.
- `SeekSlider` — slider with chapter markers (visual-only via `IgnorePointer`), value indicator with the chapter title.

**WPM selector (shared):**
- `WpmSelector` — all-in-one: capsule + AnimatedSize drawer. Used in Settings.
- `WpmCapsule` — pill with minus / clickable label / plus. Tapping the label opens the drawer.
- `WpmPresetRow` — horizontal scrollable chip row. Presets are generated dynamically (current ± increments of 50, clamped to min/max). Auto-scrolls to centre the selected chip on open.
- Used in the controls (capsule + drawer kept separate) and in settings (all-in-one `WpmSelector`).

**Reader settings:**
- `DisplaySettingsPanel` — composes the sections in `widgets/settings/sections/` (speed & timing, RSVP display, reader view, typography, audio, chrome). `compact: true` (reader sheet/side panel) shows only `quickCategoriesFor(mode)` and the rows each section keeps outside `if (!compact)`; `compact: false` (Settings screen) shows everything. Shared row widgets live in `widgets/settings/settings_controls.dart`.
- `ReaderSettingsSheet` — bottom sheet (via `ReaderSheetShell`) wrapping `DisplaySettingsPanel(compact: true)`.
- `ChapterListSheet` — chapter list for navigation.
- `ReaderSidePanel` — right-hand side panel on tablet landscape (settings, chapters, or bookmarks), driven by `readerSidePanelProvider`.
- `FinishBookButton` — manual "Finish book" action surfaced in the reader settings sheet and side panel for books still in progress. Confirms via dialog, bumps progress to the last word, and routes to the completion screen — useful for books whose tail is acknowledgements or references.

### settings
Full-screen screen: Appearance section (`SegmentedButton<ThemeMode>`) + `DisplaySettingsPanel()` + `SyncSettingsSection` + About. Background and colours come from `DisplaySettings` (live preview), except Appearance which uses the global theme.

### reading_stats
Local telemetry with three presentation surfaces:

- **`ReadingStatsScreen` (`/stats`)** — TabBar Weekly (7d) / Monthly (30d). Summary cards, stacked bar "words per day" (coloured per book), bar "time per day", line "wpm trend" (fl_chart). Book breakdown ordered by time. 2-column layout on tablet landscape.
- **`MonthlyRecapScreen` (`/stats/recap`)** — preview of the 9:16 `MonthlyRecapCard` + Share button. Card with a highlighted "Finished" section, an "In progress" section below, and a footer with totals.
- **`BookCompletionScreen` (`/books/:id/completion`)** — fired automatically by the reader at end-of-book (via `RsvpState.finishTicket`), and also reachable manually: long-press a Read book in the library to reopen it, or use the reader's "Finish book" button on an in-progress book. Star picker 0-5 (persists to `books.rating` + `ratingUpdatedAt` for sync), detailed stats block, "Include stats in the image" toggle, shareable 9:16 `BookCompletionCard`.

Pure aggregations (`buildSnapshot`, `buildMonthlyRecap`, `buildCompletionSummary`) live alongside the `StreamProvider.family` / `FutureProvider.family`. **Share cards use a fixed palette (theme-independent)** so the exported PNG looks the same for everyone. Details in [reading-stats.md](reading-stats.md).

## Share sheet and top-level integration

Two components live above `MaterialApp.router` in `lib/app.dart`:

- **ShareIntentHandler**: listens to `ReceiveSharingIntent`, filters URLs, dispatches `ArticleImportNotifier.importFromUrl`. Works on Android; iOS needs the share extension from [share-extension-ios.md](share-extension-ios.md).
- **DesktopDropHandler** (inside `MaterialApp.router`'s builder): drag-and-drop of EPUB files / URLs on desktop.
- **_ArticleImportCoordinator**: `ref.listen(articleImportProvider)` at the app level. Snackbar during fetch/process, navigates to the reader on done.

## State Management

**Riverpod 2 without code generation**.

Main providers:
- `appDatabaseProvider` — Drift DB instance, overridden in main
- `booksDaoProvider`, `readingProgressDaoProvider`, `readingSessionDaoProvider`, `cachedTokensDaoProvider`, `syncImportFailuresDaoProvider`, `bookmarksDaoProvider` — DAOs
- `rsvpEngineProvider(bookId)` — `StateNotifierProvider.autoDispose.family`, the RSVP engine per book. Writes a `reading_session` row on each flush and emits an incremented `finishTicket` on organic end-of-book.
- `displaySettingsProvider` — DisplaySettings persisted via SharedPreferences
- `themeModeProvider` — ThemeMode (system/light/dark) persisted; inverts the reader colours when brightness flips
- `selectedBookIdProvider` — `StateProvider<String?>` for master-detail on tablet landscape; `libraryPanelVisibleProvider` toggles the master pane (Ctrl+B on desktop)
- `readerSidePanelProvider` — `StateProvider<ReaderSidePanelMode>` for the reader's side panel
- `bookLibraryProvider` — StreamProvider with the list of books
- `categorizedLibraryProvider(LibraryKind)` — `FutureProvider.family` that filters and groups by progress
- `epubImportProvider`, `articleImportProvider` — StateNotifiers for the import flows
- `librarySyncProvider` — StateNotifier orchestrating push/pull/auto-import
- `driveAuthProvider` — StateNotifier for Google Drive sign-in (connected email, busy, error)
- `driveSyncFolderGatewayProvider` — `DriveSyncFolderGateway` with the authenticated `http.Client` factory
- `statsSnapshotProvider(StatsRange)` — `StreamProvider.family` that aggregates sessions by day/book
- `monthlyRecapProvider(RecapMonth)` — `FutureProvider.family` that classifies books into finished/reading for the month
- `bookCompletionProvider(bookId)` — `StreamProvider.family` with aggregate stats for a book (time, words, sessions, avgWpm, rating)
- `bookmarksProvider(bookId)` — `StreamProvider.family` with a book's live bookmarks
- `ttsBackendProvider`, `ttsEnginesProvider`, `ttsVoicesProvider` — TTS backend for the platform and its engine/voice lists

## Database (Drift/SQLite)

Schema version **11**. Tables:
- `BooksTable` — metadata: id, title, author, filePath, coverImage, totalWords, chapterCount, importedAt, lastReadAt, syncFileName, **source** (BookSource.epub|article), **sourceUrl**, **siteName**, **rating** (nullable int 0-5, v6), **ratingUpdatedAt** (nullable, v7 — sync's per-field LWW clock for rating).
- `ReadingProgressTable` — position per book (bookId PK, chapterIndex, wordIndex, wpm, updatedAt, **readerMode** — nullable `'rsvp'`/`'ereader'`/`'tts'`, v8).
- `ReadingSessionTable` (v5) — one row per continuous stretch of `isPlaying=true`. Fields: id, bookId, startedAt, endedAt, durationMs, wordsRead, startWordIndex, endWordIndex, avgWpm. No FK on `bookId` (history survives a delete). Indices on `startedAt` and `bookId`.
- `CachedTokensTable` — pre-processed tokens per chapter (bookId, chapterIndex, chapterTitle, tokensJson, wordCount, paragraphCount). `tokensJson` is always read/written through `TokenCodec` (compact v2 format; v1 still readable). Covering index `cached_tokens_book_id_idx` (bookId, chapterIndex, wordCount, v11) lets word-count queries skip the blob.
- `SyncImportFailuresTable` — EPUBs from Drive that failed to auto-import.
- `BookmarksTable` (v9) — id, bookId, globalWordIndex, chapterIndex, endGlobalWordIndex/endChapterIndex (range end, v10), label, contextSnippet, createdAt, updatedAt, deletedAt (soft delete, a sync tombstone).

`BookSource` (`lib/database/tables/book_source.dart`) is a set of string constants (not a Dart enum).

**Migrations**: every bump increments `schemaVersion` and adds an `if (from < N)` block in `MigrationStrategy`. Each step must be idempotent (`addColumnIfMissing` / `createIndexIfMissing`), because an aborted upgrade leaves DDL committed while `user_version` stays put. The bumps so far: v2 syncFileName on books, v3 sync_import_failures table, v4 article source fields on books, v5 reading_session + indices, v6 rating on books, v7 ratingUpdatedAt on books, v8 readerMode on reading_progress, v9 bookmarks, v10 bookmark range end, v11 cached_tokens covering index.

## Data flow

```
Import EPUB:    EPUB file   → epub_pro → ChapterParser ──────────────── → ParsedBook ─┐
Import Article: URL → http → readability → HtmlStripper → TextTokenizer → ParsedBook ─┤
                                                                                      ├─→ persistParsedBook → SQLite
Share sheet:    Android intent → ShareIntentHandler → ArticleImportNotifier          ─┘

Reading:        SQLite cache → Chapter[] → RsvpEngine (Ticker) → RsvpWordDisplay / ContextScrollView
Config:         SharedPreferences ↔ DisplaySettingsNotifier ↔ RsvpEngine.displaySettings
Theme:          ThemeModeNotifier ↔ DisplaySettingsNotifier.applyBrightness() → reader palette swap
Sync (EPUB):    SQLite (source=epub) ↔ library/*.json shards + books/ in Ledor/ on Drive
Telemetry:      RsvpEngine._flushSession() on pause/end/ereader/dispose → reading_session row
Stats:          reading_session[] → buildSnapshot / buildMonthlyRecap / buildCompletionSummary → UI + PNG
Completion:     engine end-of-book (_advanceWord) → finishTicket++ → ref.listen → context.push(/completion)
```

## Routes (go_router)

```
/                          LibraryScreen (with stats icon in the AppBar)
/reader/:bookId            RsvpReaderScreen (fullscreenDialog)
/settings                  SettingsScreen
/stats                     ReadingStatsScreen (TabBar weekly/monthly)
/stats/recap               MonthlyRecapScreen (current month's recap)
/books/:bookId/completion  BookCompletionScreen (star rating + share card)
/bookmarks                 BookmarksScreen (all bookmarks, grouped by book)
```

## i18n

ARB files in `lib/l10n/` (app_en.arb, app_pt.arb). Generated into `lib/l10n/generated/`. Import: `import '...l10n/generated/app_localizations.dart'`. Use `AppLocalizations.of(context)!`.
