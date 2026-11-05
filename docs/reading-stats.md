# Reading stats, monthly recap and completion

Local-first reading telemetry. No backend of its own: everything lives in
Drift (sessions also sync through Drive — see
[library-sync.md](library-sync.md)). It feeds three user-facing surfaces:

1. **Stats dashboard** (`/stats`) — charts for the last 7/30 days.
2. **Monthly recap** (`/stats/recap`) — shareable 9:16 image of the current month.
3. **Book completion** (`/books/:bookId/completion`) — completion screen with rating and shareable card, opened automatically when a book is finished.

## Session model

A **session** is one continuous stretch of reading, logged by the engine in
`lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart`.
Two flavours:

- **Playback** (RSVP or TTS): a continuous stretch of `isPlaying=true`.
  Opens in `play()` (`_startSession`); closes on `pause()`, end of book
  (`_advanceWord` / TTS `_onPlayerBookFinished`), auto-pause on an inline
  image, TTS error, a mode change (`enterEreaderMode` / `enterTtsMode` /
  `exitTtsMode`) or engine dispose. `seekToWord` during play does **not**
  split the session, and skipped words don't count: `_wordsInSession` only
  grows in `_onTick` (RSVP; one extra when a dialogue dash is merged into
  the next word) and `_onPlayerWordAdvance` (TTS).
- **Manual (ereader)**: opens in `enterEreaderMode()` (or when `_loadBook`
  auto-restores ereader mode) and closes on `exitEreaderMode()`,
  `enterTtsMode()`, `play()` or dispose. Words come from the seeks fired by
  the scroll position sync (`ContextScrollView` → `seekToWord`): positive
  deltas up to `_maxManualReadDelta` (500) count as read; larger ones are
  navigation (chapter jump, slider) and don't count; scrolling back doesn't
  subtract. Manual sessions above 700 wpm are dropped as skimming
  (`computeSessionAvgWpm(..., manual: true)`).

Schema (`lib/database/tables/reading_session_table.dart`):

| Column | Meaning |
|---|---|
| `id` | UUID |
| `bookId` | book (no FK — survives book deletion) |
| `startedAt` / `endedAt` | wall clock |
| `durationMs` | wall-clock time since `_startSession` (not the ticker's `_elapsed`) |
| `wordsRead` | `_wordsInSession` at flush time |
| `startWordIndex` / `endWordIndex` | global cursor at start/end |
| `avgWpm` | `wordsRead * 60000 / durationMs`, rounded |

Indexes on `startedAt` and `bookId` via `@TableIndex` (created by the v5
migration).

`_flushSession` inserts the row fire-and-forget (pause doesn't wait on the
DB) and clears `_sessionStartedAt`, so calling it twice is harmless.

### Noise threshold

`computeSessionAvgWpm` (top-level in `rsvp_engine_provider.dart`) drops
sessions with `durationMs < 3000` OR `wordsRead < 5`, so accidental taps on
play don't pollute the charts. Returns `null` to drop, the rounded WPM to
persist.

### Why `bookId` has no FK

Sessions outlive book deletion: history (and monthly recaps) stay valid even
if the user clears the library. In aggregates, missing books render with the
title `—`.

## Stats dashboard

`lib/features/reading_stats/presentation/screens/reading_stats_screen.dart`
hosts a Weekly/Monthly `TabController`. Each tab is fed by
`statsSnapshotProvider(StatsRange)` — a `StreamProvider.autoDispose.family`
that listens to `watchSessionsInRange(from, to)` and joins
`booksDao.getAllBooks()` on every emission. `StatsRange.window()` returns a
`[from, to)` window snapped to local midnights, with `to` = start of
tomorrow so today is included.

### `StatsSnapshot`

Aggregate consumed by the widgets:
- `dailyBuckets: List<DailyBucket>` — one per day in the range, with `perBook` slices (stacked chart) and totals; `avgWpm` is null on empty days.
- `bookBreakdowns: List<BookBreakdown>` — per book over the whole range, sorted by `totalDurationMs` desc.
- `totalWords` / `totalDurationMs` / `avgWpm` (duration-weighted) / `booksTouched` (getter).

Sessions are bucketed by the local day of `startedAt`. All aggregation is in
`buildSnapshot` (pure, tested).

### Charts (fl_chart)

- `stats_words_per_day_chart.dart` — `BarChart` stacked by book. Colours from `StatsColorPalette.forBooks(orderedBookIds:, scheme:)` — HSL hue rotation of `scheme.primary`; the top 5 books (`maxDistinctBooks`) get distinct colours, the rest collapse into "Other" (`scheme.outlineVariant`).
- `stats_time_per_day_chart.dart` — plain `BarChart`, minutes per day.
- `stats_wpm_trend_chart.dart` — `LineChart` of daily weighted avg WPM. Days without sessions emit no spot (the line joins real days directly).

### Responsive layout

`context.isTablet && context.isLandscape` → two columns (summary + breakdown on the left, charts stacked on the right). Otherwise a single scrolling column.

## Monthly recap

Opened from the `recapGenerateCta` button, shown only on the Monthly tab;
the route always builds `RecapMonth.current()`.
`monthlyRecapProvider(RecapMonth)` aggregates via `aggregateByBookInRange`
(SQL `GROUP BY bookId` with `SUM`/`MAX`/`COUNT`) and classifies each book as:

- **Finished**: `maxEndWordIndex >= totalWords - 1` (the cursor reached the last word).
- **Reading**: any session in the month, not finished.

Both lists are sorted by time spent. The preview screen
(`MonthlyRecapScreen`) wraps `MonthlyRecapCard` in a `RepaintBoundary` with
a `GlobalKey` inside a `FittedBox(BoxFit.contain)`. Share calls the
top-level `shareWidgetAsPng()` (in `image_export_service.dart`).

## Book completion

Automatic trigger: reaching the end of the book organically (`_advanceWord`
in RSVP, `_onPlayerBookFinished` in TTS — not a seek) increments
`RsvpState.finishTicket`. `RsvpReaderScreen` `ref.listen`s for
`next.finishTicket > prev.finishTicket` and calls `context.push` inside
`addPostFrameCallback` (lets the last RSVP frame settle before pushing the
celebratory screen).

A counter rather than a `didFinish` bool: it re-fires if the user seeks back
and finishes again, and never needs resetting.

Manual entry points push the route directly, without the ticket: long-press
on a Read book in the library, and `FinishBookButton` in the reader
sheet/side panel (bumps progress to the end via `markBookAsReadProvider`
first).

`bookCompletionProvider` watches the book row and reloads its sessions, so a
rating change re-renders the card.

### Screen and card

`book_completion_screen.dart` shows, in order:
1. `BookCompletionCard` preview inside a `FittedBox`.
2. `StarRatingPicker` (tapping the current star clears it). Each change persists via `booksDao.updateRating(bookId, value)`, which also stamps `ratingUpdatedAt` for sync LWW (columns added in schema v6 and v7). Rating changes don't schedule a sync push on their own.
3. `_StatsBlock` with time / words / sessions / avg WPM.
4. Day span ("finished in X days") when `daysSpan > 0` — i.e. whenever the book has sessions; a single day counts as 1.
5. `SwitchListTile` "include stats in image" → toggles the card's `showStats` (doesn't affect the screen).
6. Share button.

### 9:16 card

Fixed 360×640 dp. **Theme-independent** palette (ink on paper, hardcoded
`_paper` / `_ink` / ... in the widget) so exports look the same for every
user. Fonts via `GoogleFonts.lora()` / `GoogleFonts.inter()` — the strings
`'Lora'` / `'Inter'` don't resolve in the exported PNG because fonts come
from the `google_fonts` package, not bundled assets.

Large central cover (220 with stats, 260 without). With `showStats = false`
the footer becomes "Finished on {date}" (`lastSessionAt`, via
`DateFormat.yMMMd(locale)`). Stars only show when `rating != null`.

## Image export pipeline

`lib/core/utils/image_export_service.dart`:

`shareWidgetAsPng({boundaryKey, filename, shareText, pixelRatio = 3.0})`:
`await endOfFrame` → `RenderRepaintBoundary.toImage` → PNG in the temp dir →
`SharePlus.instance.share(ShareParams(files: [XFile(...)]))`.

Non-obvious points:
- **`await endOfFrame`**: makes sure the boundary has painted at least once. Without it, the first capture after navigation can come out blank.
- **`pixelRatio: 3.0`** on 360dp → ~1080px wide PNG. Good for Stories/feed.
- **`FittedBox` around the `RepaintBoundary` in the preview**: the capture uses the child's logical size (360×640), not the scaled one. Small preview on screen, full-resolution export.

## Maintenance notes

- **Changing the Drift schema**: bump `schemaVersion` in `app_database.dart` (currently 11) and add an `if (from < N)` block to `onUpgrade`. Every step must be idempotent — use the `addColumnIfMissing` / `createIndexIfMissing` helpers there, since an aborted upgrade can leave a DB partially migrated at the old version. Then run `dart run build_runner build --delete-conflicting-outputs`.
- **Share cards**: never read `Theme.of(context)` for colours; keep the fixed palette and `GoogleFonts` calls.
- **Changing the engine**: any new exit from `isPlaying=true` (beyond the ones listed above) must call `_flushSession()` before resetting the counters. Same for any new exit from ereader mode (open manual session) — and the flush must run **before** mutating `state.mode`, because `_flushSession` reads `state.mode` to decide whether to apply the manual skimming cap.
- **New session columns**: also add them to `SyncReadingSession` (`toJson`/`fromJson`) and the sync service, or they won't sync.
- **Tests**: `computeSessionAvgWpm` (thresholds, rounding, skim cap) in `test/features/rsvp_reader/session_flush_test.dart`; `buildSnapshot`, `buildMonthlyRecap`, `buildCompletionSummary` in `test/features/reading_stats/`; DAO queries in `test/database/reading_session_dao_test.dart`.
