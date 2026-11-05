# Library sync

EPUBs, reading progress, ratings, reading sessions, bookmarks and display
settings are synced through Google Drive. Available on Android (native
`google_sign_in`) and Linux desktop (loopback OAuth flow — see
[linux-desktop.md](linux-desktop.md#google-drive-sync)). Opt-in, scope
`drive.file` (the app only sees files it created itself).

Auth is abstracted by `DriveAuthBackend`
(`lib/features/library_sync/data/auth/`), with two implementations:
`GoogleSignInDriveAuthBackend` (mobile) and `DesktopOAuthDriveAuthBackend`
(desktop). Everything below `DriveAuthNotifier` — gateway, sync service,
shards — is identical across platforms; only the `AuthClient` provider
changes.

## Overview

Sync uses a `Ledor/` folder in the user's Drive with four metadata shards
plus a folder of EPUBs:

```
Ledor/
  library/
    books.json          ← per-book metadata + progress + rating + tombstones
    settings.json       ← display settings
    sessions.json       ← reading_session rows (append-only)
    bookmarks.json      ← bookmarks + bookmark tombstones
  books/
    <user-chosen>.epub  ← one EPUB per active book
    ...
```

Each concern lives in its own file and a sync only rewrites the shards whose
content changed (typical case: progress only → only `books.json` is
uploaded). Older builds used a single monolithic `library.json`; it is
migrated once in memory and then deleted (see [Legacy](#legacy-libraryjson)).

`books.json` is the source of truth for which books exist; the EPUBs are
payload. A book exists when it has an entry in `books.json`; the matching
file in `books/` is optional.

EPUB file sync is optional (`SyncConfig.syncEpubs`, default on). Without it,
only the shards are synced; books that arrive from remote are inserted as
placeholder rows (no tokens).

Only EPUBs take part: `_buildLocalShards` filters `source == BookSource.epub`.
Articles are always local — the shards describe an EPUB library and articles
depend on fetching a URL.

## Shards

Serialized in `lib/features/library_sync/domain/entities/sync_library.dart`.
Every shard carries `schemaVersion` (`syncShardSchemaVersion = 1`) plus a
meta block (`updatedAt`/`updatedBy`) that changes on every push and is
ignored by the skip-write check.

### `library/books.json`

```jsonc
{
  "schemaVersion": 1,
  "updatedAt": "2026-04-23T...Z",
  "updatedBy": "<deviceId>",
  "books": [
    {
      "id": "<uuid>",
      "title": "...",
      "author": "...",
      "totalWords": 12345,
      "chapterCount": 10,
      "importedAt": "...",
      "lastReadAt": "...",
      "hasEpubFile": true,
      "syncFileName": "user-visible.epub",
      "progress": {
        "chapterIndex": 3, "wordIndex": 512, "wpm": 425, "updatedAt": "...",
        "globalWordIndex": 20871,   // optional; absent in rows from older builds
        "readerMode": "ereader"     // optional; 'rsvp' | 'ereader' | 'tts'
      },
      "deletedAt": null,
      "updatedAt": "...",
      "rating": 4,                  // 1..5 or null
      "ratingUpdatedAt": "..."     // dedicated timestamp for rating LWW
    }
  ]
}
```

A local book's `updatedAt` is `lastReadAt ?? importedAt`; local rows always
set `hasEpubFile: true`.

### `library/settings.json`

Envelope + `"settings": { "values": {...}, "updatedAt": "..." }`. `values` is a plain map (`displaySettingsToMap` / `displaySettingsFromMap` in
`library_sync_service.dart`) so new `DisplaySettings` fields don't need a
schema bump — but a new field must be added to both functions to sync.
`ttsVoiceName` / `ttsEngineId` are written even when null so "use default"
propagates; an id unknown on this device is kept and ignored by the backend.

### `library/sessions.json`

Rows of `SyncReadingSession`, mirroring the `reading_session` table: `id,
bookId, startedAt, endedAt, durationMs, wordsRead, startWordIndex,
endWordIndex, avgWpm`. Append-only by id.

### `library/bookmarks.json`

Rows of `SyncLibraryBookmark`: `id, bookId, globalWordIndex, chapterIndex,
endGlobalWordIndex?, endChapterIndex?, label?, contextSnippet?, createdAt,
updatedAt, deletedAt?`. The local snapshot comes from
`BookmarksDao.getAllIncludingTombstones()` so peers receive deletes.

### Legacy `library.json`

The old monolith (`books` + `settings`, decoded by `SyncLibrary`) is only
read when **none** of the shards exist remotely. Its contents are loaded into
in-memory books/settings shards (sessions and bookmarks start empty) and the
file is deleted (best-effort) in the same sync, before the shard writes.
When shards already exist, a leftover `library.json` is ignored for merging
but still deleted.

## Merge rules

`mergeBooksShard` / `mergeSettingsShard` / `mergeSessionsShard` /
`mergeBookmarksShard` (built on `mergeBook` / `mergeProgress` /
`mergeBookmark`) in `sync_library.dart`. All merge code is pure (no I/O);
tests in `test/features/library_sync/sync_library_test.dart` and
`bookmark_merge_test.dart`.

**Per book** (`mergeBook(a, b)`):
- `updatedAt`: the later of the two; the side with the later one is "newer".
- `title` from newer; `author` and `syncFileName` from newer, falling back to
  older when null; `totalWords` / `chapterCount` from newer unless it is 0.
- `importedAt`: the **earlier** (keeps the original import date).
- `lastReadAt`: the **later**.
- `hasEpubFile`: `a.hasEpubFile || b.hasEpubFile`.
- `progress`: `mergeProgress` — LWW by `updatedAt`, except when the two are
  within 60s of each other (clock-skew tolerance): then the one further into
  the book wins, compared by `globalWordIndex` when both sides have it,
  otherwise by `(chapterIndex, wordIndex)`.
- `deletedAt`: the later non-null — **tombstones are monotonic**. Once one
  side is deleted, the merged book stays tombstoned. No resurrection.
- `rating` / `ratingUpdatedAt`: LWW **by `ratingUpdatedAt`**, not the book's
  `updatedAt`. Otherwise an unrelated change (progress, lastReadAt) on another
  device would bump `updatedAt` and overwrite a newer rating. A side without
  a timestamp (pre-v7 data) loses to a side with one.

**Books shard**: union by `id`, collisions go through `mergeBook`. Output is
sorted by id for stable serialization.

**Settings shard**: the side with the later `settings.updatedAt` wins; a
non-null side wins over a null one. The local timestamp is the persisted
"settings dirty" stamp (`sync_settingsDirtyAt`, set by `markSettingsDirty`);
when settings weren't touched locally, the remote timestamp is reused so the
local copy never wins by accident.

**Sessions shard**: union by `id`. Sessions never change after insert, so an
id collision is the same row (side `a` is kept). Apply only inserts ids the
local DB doesn't have.

**Bookmarks shard**: union by `id`, LWW by `updatedAt` per bookmark,
including its `deletedAt`. On apply, a remote tombstone for a bookmark the
local DB never had is skipped (the shard already carries it).
`_deleteBookLocally` cascades through `BookmarksDao.deleteAllForBook`, so a
deleted book needs no per-bookmark tombstones.

## Progress travels as a global cursor

`(chapterIndex, wordIndex)` only means something within the tokenization
that produced it. The same EPUB parsed by a different build can split into a
different number of chapters (image tokens, front-matter sections), so the
raw pair lands on the wrong word on the other device. Therefore:

- `_buildLocalShards` fills `globalWordIndex` via `localToGlobalWordIndex`
  over the local `cached_tokens` chapter word counts.
- `_applyRemoteProgress` re-anchors with `globalToLocalWordIndex` over the
  **local** counts; it falls back to the raw pair when `globalWordIndex` is
  null (rows from older builds) or the book has no tokens.
- `_sameCursor` compares in global space when both sides have it; comparing
  the pair would rewrite the same position on every sync.

Conversions live in `lib/core/utils/progress_index.dart`. Accepted residual:
if two tokenizations differ by N tokens before the cursor, the position
shifts by N words.

## Tombstones

Deleting a book (`deleteBookProvider`) hard-deletes it locally and calls
`LibrarySyncNotifier.pushDelete`, which appends a `PendingDelete` to a queue
persisted in SharedPreferences (`sync_pendingDeletes`) **before** any network
I/O. At the start of every `triggerSync`, `_flushPendingDeletes` calls
`LibrarySyncService.pushTombstone` for each entry:

1. Reads `library/books.json` (returns false if the folder isn't readable).
2. Stamps the book's entry with `deletedAt` and `updatedAt` = the queued
   delete time, or appends a bare tombstone entry if it isn't there.
3. Rewrites `books.json`.
4. When `syncEpubs` is on, deletes the EPUB in `books/`.

Entries leave the queue only after a successful push. If any remain, the
sync **aborts**: running the full merge without the tombstone would
re-import the deleted book from the still-active remote entry.
`resetForDisconnect` clears the queue so tombstones never leak into another
account's folder.

Other devices see the tombstoned entry on their next sync and run
`_deleteBookLocally` (tokens, progress, bookmarks, local EPUB, book row,
inline images).

### Zombie tombstone compaction

"Zombie" tombstones share a `syncFileName` with an active book. Typical
origin: book X is deleted but the Drive `deleteFile` fails, leaving the file
orphaned; the next sync auto-imports it as book Y with a **new UUID** and the
**same `syncFileName`**. `_uploadMissingEpubs` then deleted X's file
(physically Y's) and re-uploaded Y on the following sync — forever.

Two guards:
- `_compactZombieTombstones` (in `sync()`, right after `mergeBooksShard`)
  drops every tombstone whose filename (`syncFileName ?? '<id>.epub'`) is
  claimed by an active merged book. The active book owns the filename.
- `_uploadMissingEpubs` skips a tombstone's delete when an active book
  claims the same filename, and only calls `deleteFile` when the file is
  actually in the `books/` listing.

**Invariant:** an active book always wins a `syncFileName` dispute against a
tombstone. New code that iterates merged books and acts per filename must
respect it.

Legitimate tombstones (no filename collision) stay forever; there is no
age-based GC.

### No re-import of tombstoned files

`_autoImportOrphanFiles` treats a filename tombstoned in the remote shard as
"known", so an orphan file with that name never becomes a new book; the
next `_uploadMissingEpubs` honours the tombstone and deletes the file.

## Sync pipeline

`LibrarySyncService.sync()`:

```
1. await isReadable(folder)   ← retries transient errors 3x, rethrows the real
                                cause; false only on 404
┌ in parallel ─────────────────────────────────────┐
│ readText(library.json)          ← legacy probe   │
│ readText(library/books.json)                     │
│ readText(library/settings.json)                  │
│ readText(library/sessions.json)                  │
│ readText(library/bookmarks.json)                 │
│ listFiles(books/)               ← only if syncEpubs │
└──────────────────────────────────────────────────┘
2. _loadRemoteShards (legacy migrated in memory only if no shard exists)
3. _autoImportOrphanFiles       ← only if syncEpubs
4. _buildLocalShards (books + settings + sessions + bookmarks)
5. merge*Shard + _compactZombieTombstones (books)
6. _applyShardsToLocal (progress, lastReadAt, rating, new sessions,
   bookmarks, tombstones, settings)
7. delete library.json if present, then parallel writes (Future.wait):
   - books.json      ← skipped if _rowsEqual(merged, remote)
   - settings.json   ← skipped if _settingsShardEquals(merged, remote)
   - sessions.json   ← skipped if _rowsEqual(merged, remote)
   - bookmarks.json  ← skipped if _rowsEqual(merged, remote)
8. _uploadMissingEpubs          ← only if syncEpubs
```

`isReadable` is awaited before the parallel reads so a thrown error doesn't
leave them as unhandled rejections.

### Per-shard write skip

`_rowsEqual` sorts both row lists by id and compares each row's JSON
encoding; `_settingsShardEquals` compares the encoded `settings` payload.
Both ignore the meta block (`updatedAt`/`updatedBy`). An idle sync writes
nothing; a progress-only change uploads only `books.json`. Because these
compare `toJson()` output, **every new field on a shard row must be added to
its `toJson`**, or changes to it never get pushed.

## DateTime comparison

**Trap**: `DateTime.==` compares `(microsecondsSinceEpoch, isUtc)`. In sync:

- **Local** times come from Drift (unix seconds) → `isUtc: false`.
- **Remote** times come from shard JSON; `toJson` calls `toUtc()` before
  `toIso8601String()`, so they parse back with `isUtc: true`.

Same instant, different `isUtc` → `==` is `false`. In the apply step this
once caused a DB write per book on every sync. **Always use
`isAtSameMomentAs` for DateTimes that cross the local/remote boundary.**

The skip-write checks are immune because they compare JSON, which already
goes through `toUtc()`.

## DriveSyncFolderGateway caches

Any operation on a Drive file needs its `fileId`, and resolving it costs a
name-filtered `files.list` (~500-700ms, `_findFile`).

`_fileIdCache` (keyed by `"<parentId>/<fileName>"`) is filled by:
- `_findFile` (when it has to resolve)
- `listFiles` (free — the response already has id + name)
- the create branch of `writeBytes`

`readBytes`, `writeBytes` and `deleteFile` skip `_findFile` on a cache hit.

Invalidation:
- `deleteFile` removes the entry.
- `clearCache()` drops everything (called on disconnect, together with
  `resetForDisconnect`).
- No detection of concurrent renames by another device.

Folders are cached in `_folderIdCache`, and concurrent resolves of the same
path share one in-flight future (`_pendingResolves`). Without that, the
parallel shard writes on a fresh Drive each ran find-or-create and created
duplicate `library/` folders. When duplicates already exist, `_pickStable`
picks the one with the lowest id so every device converges on the same one.

The caches are not thread-safe; they assume one sync at a time per gateway,
which `LibrarySyncNotifier` guarantees.

## Orphans in `books/`

`_autoImportOrphanFiles` imports EPUBs in `books/` that no book entry
claims. Under `drive.file` the app can't see files the user drops in
manually, so in practice these are EPUBs uploaded by the app on another
device whose shard entry is missing or lost:
- Keeps `.epub` files (extension check is case-insensitive; name matching
  is exact and case-sensitive).
- Excludes filenames already known: active or tombstoned in the remote
  shard, or a local book's `syncFileName`.
- Excludes files that failed before (`SyncImportFailuresDao`, so a corrupt
  EPUB isn't retried every sync; `retainOnly` prunes records for files no
  longer in the folder; the user can retry from Settings).
- Imports the rest as new books (fresh local UUID), storing the filename in
  `syncFileName` so it isn't imported twice.

Known limitation: renaming a file in Drive looks like "delete + new orphan"
and produces a duplicate book.

## Scheduling, concurrency and offline

`LibrarySyncNotifier` (`library_sync_provider.dart`):
- `schedulePush()` debounces local changes (progress, settings, bookmarks,
  imports, mark-as-read) into one sync 2s later; it is a no-op unless
  `SyncConfig.isActive` (configured + auto-sync) and signed in. Rating
  changes don't call it — they ship with the next sync.
- `triggerSync()` serializes runs: a call during a running sync sets a flag
  and re-runs once afterwards.

Network errors (`SocketException` / `TlsException` / `http.ClientException`)
are not sync errors: the notifier moves to `SyncStage.offline` (no snackbar,
no `errorMessage`) and retries every minute with `triggerSync(quiet: true)`,
which doesn't flip back to `syncing` (the hairline would flash every
minute). User-initiated attempts (AppBar icon, pull-to-refresh, "Sync now")
go through `syncNowWithFeedback`, which shows a snackbar only if that
attempt ends offline. The library AppBar shows a `cloud_off` icon while
offline.

Nothing needs a queue besides deletes: progress, sessions, bookmarks and
ratings carry timestamps in the DB, so the next successful sync pushes them.
Settings used to be the exception — the dirty stamp lived only in memory; it
is now persisted as `sync_settingsDirtyAt` and cleared only after a
successful sync (a change that lands mid-sync keeps its stamp for the
re-run).

While syncing, the library shows a 2px hairline under the TabBar
(`LibraryAppBarBottom`, `stage == SyncStage.syncing`); during orphan
auto-import it becomes the detailed `LibraryImportProgressBar`.

## Key files

- `lib/features/library_sync/data/services/library_sync_service.dart` —
  `sync()`, `pushTombstone()`, `_loadRemoteShards`, `_buildLocalShards`,
  `_applyShardsToLocal`, `_applyRemoteProgress`, `_uploadMissingEpubs`,
  `_autoImportOrphanFiles`, `_compactZombieTombstones`, `_rowsEqual` /
  `_settingsShardEquals`, `displaySettingsToMap` / `displaySettingsFromMap`.
- `lib/features/library_sync/data/gateways/drive_sync_folder_gateway.dart`
  — Drive API wrapper with folder + file caches.
- `lib/features/library_sync/domain/entities/sync_library.dart` — shard
  schemas (`SyncBooksShard`, `SyncSettingsShard`, `SyncSessionsShard`,
  `SyncBookmarksShard`) and pure merges. `SyncLibrary` is kept only to
  decode the legacy monolith.
- `lib/features/library_sync/presentation/providers/library_sync_provider.dart`
  — debounce, sync serialization, pending-delete queue, offline retry.
- `lib/features/library_sync/presentation/providers/drive_auth_provider.dart`
  — silent sign-in at startup, authenticated `AuthClient`.
- Tests: `test/features/library_sync/` (merge, gateway, pending deletes,
  service apply/import/push/tombstones). `helpers/sync_service_harness.dart`
  runs the service against a real in-memory Drift DB and
  `test/fixtures/fake_sync_folder_gateway.dart`.
