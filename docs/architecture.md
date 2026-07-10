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
- `LibraryList` — categorised grid (In Progress / Not Started / Read) with adaptive `SliverGrid` (2/3/4 columns). Pull-to-refresh when sync is configured.
- `BookCard` — cover or gradient fallback, title, subtitle, `ReadingProgressBar`, scale-on-press with haptic, highlight when selected in master-detail.
- `LibraryFab` — FAB with busy/idle state, action depends on the active tab (EPUB file picker / article URL dialog).
- `LibraryAppBarBottom` — TabBar plus a conditional `LibraryImportProgressBar`.
- `LibrarySkeleton` — grid of `SkeletonBookCard` with shimmer during loading.
- `LibraryEmptyState` — circular icon + serif title + subtitle + optional CTA.
- `LibrarySectionHeader` — uppercase tracked label + count badge.
- `ReaderPlaceholder` — empty panel on tablet ("Pick a book to begin").

Sub-module `data/services/book_persistence.dart` contains `persistParsedBook` — a helper shared between `epub_import` and `article_import`. **Every import must go through it**.

### epub_import
Pipeline: EPUB bytes → `epub_pro` → chapters → `HtmlStripper` → `TextTokenizer` → `List<WordToken>` → `ParsedBook` → `persistParsedBook`.

### article_import
Pipeline: URL → `http.get` → HTML → `ReadabilityExtractor` → `HtmlStripper` → `TextTokenizer` → `ParsedBook` (1 chapter) → `persistParsedBook(source: BookSource.article)`. Details in [article-import.md](article-import.md).

### library_sync
Syncs the library manifest, `reading_progress`, `DisplaySettings`, ratings, and reading sessions through an "RSVP Reader" folder the app creates in the user's Google Drive (scope `drive.file` — it only sees files the app itself created). Available on **Android** and **Linux desktop**.

Single gateway via `DriveSyncFolderGateway` (implements `SyncFolderGateway`); the per-platform auth is abstracted behind `DriveAuthBackend` (`lib/features/library_sync/data/auth/`): `GoogleSignInDriveAuthBackend` on mobile, `DesktopOAuthDriveAuthBackend` on desktop (loopback OAuth via `googleapis_auth.clientViaUserConsent`, system browser via `url_launcher`, refresh token in `flutter_secure_storage`/libsecret). `DriveAuthNotifier` only depends on the abstraction, so the gateway / sync service / manifest code is identical across platforms. `SyncConfig.driveFolderId` caches the root folder id. **Filters `source='epub'`** — articles are always local.

The manifest is sharded into three files (`library/books.json` + `library/settings.json` + `library/sessions.json`); pushes parallelise writes via `Future.wait` and skip any shard whose JSON-encoded content is unchanged (ignoring `updatedAt`/`updatedBy`). Sessions are append-only by id; rating uses a dedicated `ratingUpdatedAt` for per-field LWW so unrelated bumps don't clobber a fresh rating.

`LibrarySyncService.sync()` pipeline:
1. 3 parallel reads: `isReadable` + `readManifest` + `listFiles(books/)` — these used to run serially; now they only pay the `max()` of their latencies (~1.5s instead of ~4.5s).
2. `_autoImportOrphanFiles` — EPUBs dropped directly into the Drive folder become new local books (respecting tombstones so deletes don't resurrect).
3. Local snapshot + per-shard LWW merge (`mergeBooksShard` etc.).
4. **Zombie tombstone compaction**: if a tombstone shares `syncFileName` with an active row in merged, the tombstone is dropped — prevents the flip-flop where the tombstone's delete would clobber the active row's file.
5. `_applyToLocal` — applies progress + lastReadAt + tombstone deletes. **DateTime compare via `isAtSameMomentAs`** to normalise TZ (local comes from Drift with `isUtc=false`, remote comes from UTC JSON; default `==` would always say `!=`).
6. `_libraryContentEquals(merged, remote)` — if identical ignoring meta `updatedAt`/`updatedBy`, **skip the write** (saves ~2-3s on an idle sync).
7. `_uploadMissingEpubs` — uploads missing EPUBs while respecting the shared `listFiles` Set; tombstones that collide with an active row are skipped (`skippedTombstones`).

`DriveSyncFolderGateway` keeps `folderId` and `fileId` caches populated across operations — read/write/delete on the same file skip `_findFile` (~500-700ms each). All phases emit `[sync]`/`[drive]` debug prints with timings. Details in [library-sync.md](library-sync.md).

### rsvp_reader
Core feature. Widgets organised into focused files:

**Screen:**
- `RsvpReaderScreen` — hosts all 3 modes. Accepts an `onClose` callback for master-detail. On tablet landscape it renders `ReaderSidePanel` next to the body when active.

**Engine:**
- `RsvpEngineNotifier` — Ticker-based. Play/pause/seek/speed/ramp-up plus `ReaderMode`. Saves progress on pause.

**RSVP display:**
- `RsvpWordDisplay` — RichText with ORP anchor. Auto-scales long words. Margins and font scale are responsive via `ResponsiveDefaults`.

**Context mode:**
- `ContextScrollView` — virtualised list of chapters + paragraphs. Highlight via a local ValueNotifier, velocity-based stepping, syncs with the engine on scroll end. `ConstrainedBox(maxWidth: 720)` on wide screens. `showHighlight: false` serves the ereader mode. A floating bottom-right overlay houses a **lock** toggle (freezes the scroll while the engine keeps advancing) and a **recenter** button that measures the highlighted word's actual `RenderBox` via `GlobalKey` + `getTransformTo(viewport)` so long-paragraph centring is pixel-accurate, not character-fraction-estimated.
- `RsvpParagraphView` — extracted public widget that renders a single paragraph's tokens with the highlight pill. Lives outside `ContextScrollView` so it's testable without the engine provider.

**Controls (dock):**
- `RsvpControls` — compositor. `AnimatedSize` on the column so it grows when the WPM drawer opens.
- `ControlsShell` — translucent surface with backdrop blur and a top border.
- `ControlsMetaRow` — chapter title + remaining time (tabular figures).
- `ControlsProgressRow` — percentage + chapter navigation.
- `ControlsTransportRow` — play 64px with `AnimatedSwitcher` (scale+fade), skips 48px, `WpmCapsule`. Layout: `LayoutBuilder` with a 520px breakpoint — `Stack` (inline, WPM on the right) on wide screens, `Column` (stacked) on narrow ones.
- `SeekSlider` — slider with chapter markers (visual-only via `IgnorePointer`), value indicator with the chapter title.

**WPM selector (shared):**
- `WpmSelector` — all-in-one: capsule + AnimatedSize drawer. Used in Settings.
- `WpmCapsule` — pill with minus / clickable label / plus. Tapping the label opens the drawer.
- `WpmPresetRow` — horizontal scrollable chip row. Presets are generated dynamically (current ± increments of 50, clamped to min/max). Auto-scrolls to centre the selected chip on open.
- Used in the controls (capsule + drawer kept separate) and in settings (all-in-one `WpmSelector`).

**Reader settings:**
- `DisplaySettingsPanel` — single column with ALL the configs. Accepts an optional `bookId` for live preview via the engine.
- `display_settings_widgets.dart` (`part of`) — components: `_SectionHeader`, `_SettingRow`, `_SwitchRow`, `_PlusMinusControl`, `_ColorRow`, `_FontSelector`.
- `ReaderSettingsSheet` — DraggableScrollableSheet wrapping DisplaySettingsPanel.
- `ChapterListSheet` — chapter list for navigation.
- `ReaderSidePanel` — right-hand side panel on tablet landscape (settings or chapters), driven by `readerSidePanelProvider`.
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

- **ShareIntentHandler**: listens to `ReceiveSharingIntent`, filters URLs, dispatches `ArticleImportNotifier.importFromUrl`. Android-only.
- **_ArticleImportCoordinator**: `ref.listen(articleImportProvider)` at the app level. Snackbar during fetch/process, navigates to the reader on done.

## State Management

**Riverpod 2 without code generation**.

Main providers:
- `appDatabaseProvider` — Drift DB instance, overridden in main
- `booksDaoProvider`, `readingProgressDaoProvider`, `readingSessionDaoProvider`, `cachedTokensDaoProvider`, `syncImportFailuresDaoProvider` — DAOs
- `rsvpEngineProvider(bookId)` — `StateNotifierProvider.family`, the RSVP engine per book. Writes a `reading_session` row on each flush and emits an incremented `finishTicket` on organic end-of-book.
- `displaySettingsProvider` — DisplaySettings persisted via SharedPreferences
- `themeModeProvider` — ThemeMode (system/light/dark) persisted; inverts the reader colours when brightness flips
- `selectedBookIdProvider` — `StateProvider<String?>` for master-detail on tablet landscape
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

## Database (Drift/SQLite)

Schema version **7**. Tables:
- `BooksTable` — metadata: id, title, author, filePath, coverImage, totalWords, chapterCount, importedAt, lastReadAt, syncFileName, **source** (BookSource.epub|article), **sourceUrl**, **siteName**, **rating** (nullable int 0-5, v6), **ratingUpdatedAt** (nullable, v7 — sync's per-field LWW clock for rating).
- `ReadingProgressTable` — position per book (bookId PK, chapterIndex, wordIndex, wpm, updatedAt).
- `ReadingSessionTable` (v5) — one row per continuous stretch of `isPlaying=true`. Fields: id, bookId, startedAt, endedAt, durationMs, wordsRead, startWordIndex, endWordIndex, avgWpm. No FK on `bookId` (history survives a delete). Indices on `startedAt` and `bookId`.
- `CachedTokensTable` — pre-processed tokens per chapter (bookId, chapterIndex, chapterTitle, tokensJson, wordCount, paragraphCount).
- `SyncImportFailuresTable` — EPUBs from Drive that failed to auto-import.

`BookSource` (`lib/database/tables/book_source.dart`) is a set of string constants (not a Dart enum).

**Migrations**: every bump increments `schemaVersion` and adds an `if (from < N)` block in `MigrationStrategy`. The bumps so far: v2 syncFileName on books, v3 sync_import_failures table, v4 article source fields on books, v5 reading_session + indices, v6 rating on books, v7 ratingUpdatedAt on books (per-field LWW for sync).

## Data flow

```
Import EPUB:    EPUB file   → epub_pro → HtmlStripper → TextTokenizer → ParsedBook ─┐
Import Article: URL → http → readability → HtmlStripper → TextTokenizer → ParsedBook ─┤
                                                                                      ├─→ persistParsedBook → SQLite
Share sheet:    Android intent → ShareIntentHandler → ArticleImportNotifier          ─┘

Reading:        SQLite cache → Chapter[] → RsvpEngine (Ticker) → RsvpWordDisplay / ContextScrollView
Config:         SharedPreferences ↔ DisplaySettingsNotifier ↔ RsvpEngine.displaySettings
Theme:          ThemeModeNotifier ↔ DisplaySettingsNotifier.applyBrightness() → reader palette swap
Sync (EPUB):    SQLite (source=epub) ↔ library.json manifest + books/ in RSVP Reader/ on Drive
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
```

## i18n

ARB files in `lib/l10n/` (app_en.arb, app_pt.arb). Generated into `lib/l10n/generated/`. Import: `import '...l10n/generated/app_localizations.dart'`. Use `AppLocalizations.of(context)!`.
