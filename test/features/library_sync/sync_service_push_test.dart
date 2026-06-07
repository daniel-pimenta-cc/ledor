import 'package:flutter_test/flutter_test.dart';

import 'helpers/sync_service_harness.dart';

/// Push-side end-to-end behaviour of LibrarySyncService.sync():
///   - legacy `library.json` migration into the sharded layout,
///   - append-only session merge (union by id, no duplicates),
///   - bookmark LWW (label update, tombstone-in, unknown-tombstone skip,
///     local-wins, local-tombstone-ships),
///   - EPUB upload (missing -> uploaded, present -> not re-written).
///
/// Timestamp convention mirrors the real app: remote shard JSON carries UTC
/// instants (DateTime.utc), the local DB carries local-TZ DateTimes (DateTime)
/// — the isAtSameMomentAs invariants exist precisely because these two cross.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncServiceHarness h;

  setUp(() async {
    h = SyncServiceHarness();
    await h.init();
  });

  tearDown(() => h.dispose());

  // -----------------------------------------------------------------------
  // 1 & 2. Legacy monolith migration
  // -----------------------------------------------------------------------

  group('legacy migration', () {
    test('lone library.json migrates into the DB and is deleted', () async {
      // Build a valid legacy monolith referencing one EPUB, drop the EPUB
      // bytes in books/ so the import-from-remote path can populate the row.
      h.putRemoteEpub('legacy-book.epub', title: 'Legacy Title');
      final legacy = SyncLibrary(
        updatedAt: DateTime.utc(2026, 1, 1),
        updatedBy: 'device-remote',
        books: [
          h.makeRemoteBook(
            id: 'legacy-1',
            title: 'Legacy Title',
            author: 'Legacy Author',
            syncFileName: 'legacy-book.epub',
            lastReadAt: DateTime.utc(2026, 1, 2),
          ),
        ],
      );
      h.gateway.textFiles[kLegacyLibraryFile] = legacy.encode();

      await h.runSync();

      // Invariant: the legacy book is migrated into the local DB.
      final book = await h.db.booksDao.getBookById('legacy-1');
      expect(book, isNotNull);
      expect(book!.title, 'Legacy Title');

      // Invariant: the legacy monolith is deleted from the folder so peers
      // adopt the sharded layout without re-migrating.
      expect(h.gateway.textFiles.containsKey(kLegacyLibraryFile), isFalse);
      expect(h.gateway.deleteLog, contains(kLegacyLibraryFile));

      // The new books shard is NOT written on the first sync: at the moment
      // _buildLocalShards runs the DB is still empty (import happens later in
      // apply), so merged books == the legacy-derived remote shard and the
      // skip-write optimization suppresses the push. A second sync — when the
      // DB now holds the migrated book — materializes library/books.json.
      expect(h.readBooksShard(), isNull);

      await h.runSync();
      final shard = h.readBooksShard();
      expect(shard, isNotNull);
      expect(shard!.books.map((b) => b.id), contains('legacy-1'));
    });

    test('library.json alongside fresh shards is ignored but still deleted',
        () async {
      // A new shard is present -> legacy is treated as already-migrated. Its
      // book must NOT leak into the merged library, yet the file is removed.
      h.putBooksShard([
        h.makeRemoteBook(
          id: 'shard-book',
          title: 'Shard Book',
          syncFileName: 'shard-book.epub',
        ),
      ]);
      h.putRemoteEpub('shard-book.epub');
      final legacy = SyncLibrary(
        updatedAt: DateTime.utc(2025, 1, 1),
        updatedBy: 'device-remote',
        books: [
          h.makeRemoteBook(id: 'legacy-stale', title: 'Stale Legacy Book'),
        ],
      );
      h.gateway.textFiles[kLegacyLibraryFile] = legacy.encode();

      await h.runSync();

      // Invariant: legacy contents are NOT migrated when shards already exist.
      expect(await h.db.booksDao.getBookById('legacy-stale'), isNull);
      final ids = h.readBooksShard()!.books.map((b) => b.id);
      expect(ids, isNot(contains('legacy-stale')));
      expect(ids, contains('shard-book'));

      // Invariant: the stale legacy file is still removed.
      expect(h.gateway.textFiles.containsKey(kLegacyLibraryFile), isFalse);
      expect(h.gateway.deleteLog, contains(kLegacyLibraryFile));
    });
  });

  // -----------------------------------------------------------------------
  // 3. Sessions: append-only, union by id, idempotent
  // -----------------------------------------------------------------------

  group('sessions append-only merge', () {
    test('local session ships, remote session inserts, twice = no dupes',
        () async {
      // A book so both sessions have a plausible parent (sessions have no FK
      // but it keeps the fixture honest).
      await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
      await seedLocalSession(h, id: 'sess-local', bookId: 'book-1');

      // Remote shard already carries a different session id.
      h.putSessionsShard([
        makeRemoteSession(id: 'sess-remote', bookId: 'book-1'),
      ]);

      await h.runSync();

      // Invariant: the remote session is now in the local DB.
      final localIds = await h.db.readingSessionDao.existingSessionIds();
      expect(localIds, containsAll(<String>{'sess-local', 'sess-remote'}));

      // Invariant: the pushed shard is the union of both sessions.
      final shardIds =
          h.readSessionsShard()!.sessions.map((s) => s.id).toSet();
      expect(shardIds, {'sess-local', 'sess-remote'});

      // Invariant: running sync again imports nothing new (existingSessionIds
      // dedup) — exactly two rows remain.
      await h.runSync();
      final after = await h.db.readingSessionDao.getAllSessions();
      expect(after.map((s) => s.id).toSet(), {'sess-local', 'sess-remote'});
      expect(after.length, 2);
    });

    test('id collision keeps a single row (merge is a set union)', () async {
      await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
      // Same id locally and remotely with different payloads. Append-only
      // merge keeps one row; the local copy is never overwritten.
      await seedLocalSession(h, id: 'shared', bookId: 'book-1', wordsRead: 10);
      h.putSessionsShard([
        makeRemoteSession(id: 'shared', bookId: 'book-1', wordsRead: 999),
      ]);

      await h.runSync();

      final rows = await h.db.readingSessionDao.getAllSessions();
      expect(rows.length, 1);
      // Local row stays put — the apply path skips ids it already has.
      expect(rows.single.wordsRead, 10);
    });
  });

  // -----------------------------------------------------------------------
  // 4. Bookmarks LWW end-to-end
  // -----------------------------------------------------------------------

  group('bookmarks LWW', () {
    test('remote newer updates the label locally', () async {
      await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
      await h.seedLocalBookmark(
        id: 'bm-1',
        bookId: 'book-1',
        label: 'old label',
        updatedAt: DateTime(2026, 1, 1),
      );
      h.putBookmarksShard([
        makeRemoteBookmark(
          id: 'bm-1',
          bookId: 'book-1',
          label: 'new label',
          updatedAt: DateTime.utc(2026, 2, 1), // newer
        ),
      ]);

      await h.runSync();

      // Invariant: a remote bookmark with a later updatedAt overwrites the
      // local label verbatim.
      final row = await h.db.bookmarksDao.getById('bm-1');
      expect(row, isNotNull);
      expect(row!.label, 'new label');
      expect(row.deletedAt, isNull);
    });

    test('remote tombstone (newer) soft-deletes the local bookmark', () async {
      await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
      await h.seedLocalBookmark(
        id: 'bm-1',
        bookId: 'book-1',
        label: 'alive',
        updatedAt: DateTime(2026, 1, 1),
      );
      h.putBookmarksShard([
        makeRemoteBookmark(
          id: 'bm-1',
          bookId: 'book-1',
          label: 'alive',
          updatedAt: DateTime.utc(2026, 2, 1),
          deletedAt: DateTime.utc(2026, 2, 1),
        ),
      ]);

      await h.runSync();

      // Invariant: tombstone hides the row from getForBook ...
      final visible = await h.db.bookmarksDao.getForBook('book-1');
      expect(visible.map((b) => b.id), isNot(contains('bm-1')));
      // ... but the soft-deleted row is still present for sync.
      final all = await h.db.bookmarksDao.getAllIncludingTombstones();
      final tomb = all.firstWhere((b) => b.id == 'bm-1');
      expect(tomb.deletedAt, isNotNull);
    });

    test('remote tombstone for an unknown bookmark inserts nothing', () async {
      await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
      // No local bm-ghost row. Remote ships a tombstone-only record.
      h.putBookmarksShard([
        makeRemoteBookmark(
          id: 'bm-ghost',
          bookId: 'book-1',
          updatedAt: DateTime.utc(2026, 2, 1),
          deletedAt: DateTime.utc(2026, 2, 1),
        ),
      ]);

      await h.runSync();

      // Invariant: a tombstone the local DB never knew about is not
      // materialised — the originating peer already carries it.
      expect(await h.db.bookmarksDao.getById('bm-ghost'), isNull);
      final all = await h.db.bookmarksDao.getAllIncludingTombstones();
      expect(all.map((b) => b.id), isNot(contains('bm-ghost')));
    });

    test('local bookmark newer wins: DB intact, shard carries local version',
        () async {
      await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
      await h.seedLocalBookmark(
        id: 'bm-1',
        bookId: 'book-1',
        label: 'local fresh',
        updatedAt: DateTime(2026, 3, 1), // newer than remote
      );
      h.putBookmarksShard([
        makeRemoteBookmark(
          id: 'bm-1',
          bookId: 'book-1',
          label: 'remote stale',
          updatedAt: DateTime.utc(2026, 1, 1), // older
        ),
      ]);

      await h.runSync();

      // Invariant: local row is untouched ...
      final row = await h.db.bookmarksDao.getById('bm-1');
      expect(row!.label, 'local fresh');
      // ... and the pushed shard carries the local (winning) version.
      final shardBm =
          h.readBookmarksShard()!.bookmarks.firstWhere((b) => b.id == 'bm-1');
      expect(shardBm.label, 'local fresh');
    });

    test('local tombstone is shipped in the pushed shard', () async {
      await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
      // A locally soft-deleted bookmark. Peers need the deletedAt to converge.
      await h.seedLocalBookmark(
        id: 'bm-dead',
        bookId: 'book-1',
        label: 'gone',
        updatedAt: DateTime(2026, 1, 5),
        deletedAt: DateTime(2026, 1, 5),
      );

      await h.runSync();

      // Invariant: the tombstone (deletedAt set) appears in the pushed shard.
      final shardBm = h
          .readBookmarksShard()!
          .bookmarks
          .firstWhere((b) => b.id == 'bm-dead');
      expect(shardBm.deletedAt, isNotNull);
      expect(shardBm.deletedAt!.isAtSameMomentAs(DateTime(2026, 1, 5)), isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // 5. EPUB upload
  // -----------------------------------------------------------------------

  group('epub upload', () {
    test('local EPUB missing from remote is uploaded to books/', () async {
      await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');

      await h.runSync();

      // Invariant: the local file's bytes land at books/<syncFileName>.
      expect(h.gateway.binFiles.keys, contains('books/book-1.epub'));
      expect(h.gateway.writeLog, contains('books/book-1.epub'));
    });

    test('EPUB already present remotely is not re-written', () async {
      // Remote books/ already holds this file (and the matching shard entry
      // so it is not treated as an orphan import).
      h.putBooksShard([
        h.makeRemoteBook(
          id: 'book-1',
          title: 'Local Book',
          syncFileName: 'book-1.epub',
          importedAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      h.putRemoteEpub('book-1.epub');
      await h.seedLocalBook(
        id: 'book-1',
        title: 'Local Book',
        syncFileName: 'book-1.epub',
        importedAt: DateTime(2026, 1, 1),
      );

      await h.runSync();

      // Invariant: an already-present EPUB is never re-uploaded — the
      // _uploadMissingEpubs guard skips files in remoteEpubFiles.
      expect(h.gateway.writeLog, isNot(contains('books/book-1.epub')));
    });
  });
}

// ---------------------------------------------------------------------------
// Local-only helpers (kept here, not in the harness, since they're specific
// to this file's session/bookmark fixtures).
// ---------------------------------------------------------------------------

/// Seeds a reading_session row the way the engine writes one: local-TZ
/// DateTimes (Drift), so cross-TZ comparisons stay faithful.
Future<void> seedLocalSession(
  SyncServiceHarness h, {
  required String id,
  required String bookId,
  int wordsRead = 50,
  int durationMs = 10000,
}) async {
  await h.db.readingSessionDao.insertSession(
    ReadingSessionTableCompanion.insert(
      id: id,
      bookId: bookId,
      startedAt: DateTime(2026, 1, 1, 9),
      endedAt: DateTime(2026, 1, 1, 9, 5),
      durationMs: durationMs,
      wordsRead: wordsRead,
      startWordIndex: 0,
      endWordIndex: wordsRead,
      avgWpm: 300,
    ),
  );
}

/// A remote session record with UTC timestamps (shard JSON convention).
SyncReadingSession makeRemoteSession({
  required String id,
  required String bookId,
  int wordsRead = 50,
}) {
  return SyncReadingSession(
    id: id,
    bookId: bookId,
    startedAt: DateTime.utc(2026, 1, 2, 9),
    endedAt: DateTime.utc(2026, 1, 2, 9, 5),
    durationMs: 10000,
    wordsRead: wordsRead,
    startWordIndex: 0,
    endWordIndex: wordsRead,
    avgWpm: 300,
  );
}

/// A remote bookmark record with UTC timestamps (shard JSON convention).
SyncLibraryBookmark makeRemoteBookmark({
  required String id,
  required String bookId,
  int globalWordIndex = 0,
  String? label,
  required DateTime updatedAt,
  DateTime? createdAt,
  DateTime? deletedAt,
}) {
  return SyncLibraryBookmark(
    id: id,
    bookId: bookId,
    globalWordIndex: globalWordIndex,
    chapterIndex: 0,
    label: label,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}
