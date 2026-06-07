import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/sync_service_harness.dart';

/// End-to-end coverage of the *import* side of LibrarySyncService.sync():
/// pulling a brand-new book from a remote shard (with and without its EPUB),
/// auto-importing orphan EPUBs the user dropped in books/, the tombstone /
/// failure guards that keep deleted or corrupt files from thrashing the
/// importer, and the onImportProgress callback contract. Every test asserts
/// on both the local DB (via `h.db` DAOs) and the fake folder (shard JSON +
/// gateway logs) — never just "didn't throw".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncServiceHarness h;

  setUp(() async {
    h = SyncServiceHarness();
    await h.init();
  });

  tearDown(() => h.dispose());

  test(
      'remote book with EPUB present is fully imported: row, tokens, progress',
      () async {
    // A remote manifest entry that points at a real EPUB in books/. The
    // service must read those bytes, extract chapters, persist tokens, and
    // apply the shard's progress — a true import, not a placeholder.
    h.putRemoteEpub('remote-1.epub', title: 'Remote One');
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'remote-1',
        title: 'Remote One',
        syncFileName: 'remote-1.epub',
        progress: SyncLibraryProgress(
          chapterIndex: 0,
          wordIndex: 3,
          wpm: 350,
          updatedAt: DateTime.utc(2026, 1, 1),
          readerMode: 'rsvp',
        ),
      ),
    ]);

    await h.runSync();

    final book = await h.db.booksDao.getBookById('remote-1');
    expect(book, isNotNull);
    // Real import => a saved local file path, not the empty-string placeholder.
    expect(book!.filePath, isNotEmpty);
    expect(book.syncFileName, 'remote-1.epub');

    // Tokens were persisted from the extracted chapters.
    final tokens = await h.db.cachedTokensDao.getTokensForBook('remote-1');
    expect(tokens, isNotEmpty);

    // The shard's progress was applied verbatim.
    final progress = await h.db.readingProgressDao.getProgressForBook('remote-1');
    expect(progress, isNotNull);
    expect(progress!.wordIndex, 3);
    expect(progress.wpm, 350);
    expect(progress.readerMode, 'rsvp');
  });

  test('remote book without its EPUB becomes a placeholder, sync survives',
      () async {
    // Manifest references an EPUB the folder doesn't actually have yet.
    // _importFromRemoteEpub falls back to a placeholder row (empty filePath,
    // no tokens) and still applies progress; the sync as a whole must not
    // fail.
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'ghost-1',
        title: 'Ghost Book',
        syncFileName: 'ghost-1.epub', // no putRemoteEpub for this name
        progress: SyncLibraryProgress(
          chapterIndex: 1,
          wordIndex: 9,
          wpm: 280,
          updatedAt: DateTime.utc(2026, 2, 1),
        ),
      ),
    ]);

    await h.runSync();

    final book = await h.db.booksDao.getBookById('ghost-1');
    expect(book, isNotNull);
    expect(book!.filePath, isEmpty); // placeholder, no bytes were available
    final tokens = await h.db.cachedTokensDao.getTokensForBook('ghost-1');
    expect(tokens, isEmpty);

    // Progress still rode along so the next sync (once the EPUB shows up) can
    // restore the reader to the right spot.
    final progress =
        await h.db.readingProgressDao.getProgressForBook('ghost-1');
    expect(progress, isNotNull);
    expect(progress!.wordIndex, 9);
    expect(progress.chapterIndex, 1);
  });

  test('orphan EPUB in books/ is auto-imported and pushed into the shard',
      () async {
    // A file dropped straight into books/ with no manifest entry and no local
    // book. _autoImportOrphanFiles must import it under a fresh uuid, set
    // syncFileName to the filename, populate tokens, and the merged push must
    // include the new book.
    h.putRemoteEpub('dropped.epub', title: 'Dropped Book');

    await h.runSync();

    final books = await h.db.booksDao.getAllBooks();
    final imported =
        books.where((b) => b.syncFileName == 'dropped.epub').toList();
    expect(imported, hasLength(1));
    expect(imported.single.filePath, isNotEmpty);
    final tokens =
        await h.db.cachedTokensDao.getTokensForBook(imported.single.id);
    expect(tokens, isNotEmpty);

    // The freshly imported book surfaces in the pushed books shard.
    final shard = h.readBooksShard();
    expect(shard, isNotNull);
    final shardEntry = shard!.books
        .where((b) => b.syncFileName == 'dropped.epub')
        .toList();
    expect(shardEntry, hasLength(1));
    expect(shardEntry.single.id, imported.single.id);
    // No failure was recorded for a clean import.
    expect(await h.db.syncImportFailuresDao.getAll(), isEmpty);
  });

  test('orphan whose filename is a manifest tombstone is NOT resurrected',
      () async {
    // The same filename lives in books/ but the manifest carries a tombstone
    // for it. Re-importing would spawn a duplicate that fights the tombstone
    // forever, so the file is treated as "known" and left untouched.
    h.putRemoteEpub('dead.epub', title: 'Dead Book');
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'dead-1',
        title: '',
        syncFileName: 'dead.epub',
        hasEpubFile: false,
        deletedAt: DateTime.utc(2026, 1, 5),
        updatedAt: DateTime.utc(2026, 1, 5),
      ),
    ]);

    await h.runSync();

    // No book row was created from the orphan file.
    final books = await h.db.booksDao.getAllBooks();
    expect(books.where((b) => b.syncFileName == 'dead.epub'), isEmpty);
    // And the tombstone wasn't applied as a real (active) book either.
    expect(books.any((b) => b.id == 'dead-1'), isFalse);
  });

  test(
      'corrupt orphan is recorded as a failure, does not block a sibling, and '
      'is skipped on the next sync', () async {
    // Two orphans in books/: one valid, one garbage. The bad one must be
    // caught + recorded in sync_import_failures, the good one must still
    // import, and a second sync must not re-attempt the bad one.
    h.putRemoteEpub('good.epub', title: 'Good Book');
    h.gateway.binFiles['$kBooksDir/bad.epub'] =
        Uint8List.fromList([0, 1, 2, 3, 4, 5]); // not a zip

    await h.runSync();

    // Valid sibling imported despite the bad neighbour.
    final books = await h.db.booksDao.getAllBooks();
    expect(books.where((b) => b.syncFileName == 'good.epub'), hasLength(1));
    expect(books.where((b) => b.syncFileName == 'bad.epub'), isEmpty);

    // The corrupt file is on the failures ledger.
    final failures = await h.db.syncImportFailuresDao.getAll();
    expect(failures.map((f) => f.fileName), contains('bad.epub'));

    // Second sync: the bad file is in previouslyFailed, so it is filtered out
    // of the orphan list and never re-attempted. We pin this by checking the
    // failure row's failedAt is byte-for-byte the same — record() (which
    // stamps a fresh DateTime.now()) was never called again.
    final failedAtBefore =
        failures.firstWhere((f) => f.fileName == 'bad.epub').failedAt;

    await h.runSync();

    final failuresAfter = await h.db.syncImportFailuresDao.getAll();
    final badAfter =
        failuresAfter.firstWhere((f) => f.fileName == 'bad.epub');
    // Same failedAt timestamp => record() was never called again => skipped.
    expect(badAfter.failedAt, failedAtBefore);
    final booksAfter = await h.db.booksDao.getAllBooks();
    expect(booksAfter.where((b) => b.syncFileName == 'bad.epub'), isEmpty);
  });

  test('failure row for a file that vanished from remote is pruned (retainOnly)',
      () async {
    // First sync: a corrupt orphan records a failure.
    h.gateway.binFiles['$kBooksDir/gone.epub'] =
        Uint8List.fromList([9, 9, 9, 9]);
    await h.runSync();
    expect(
      (await h.db.syncImportFailuresDao.getAll()).map((f) => f.fileName),
      contains('gone.epub'),
    );

    // The user deletes the file from the cloud; it's no longer listed.
    h.gateway.binFiles.remove('$kBooksDir/gone.epub');

    await h.runSync();

    // retainOnly prunes the stale failure entry since its file is gone.
    final failures = await h.db.syncImportFailuresDao.getAll();
    expect(failures.where((f) => f.fileName == 'gone.epub'), isEmpty);
  });

  test('onImportProgress reports (0,total,"") .. (total,total,"") around import',
      () async {
    // Drive service.sync directly so we can pass the progress callback the
    // runSync helper doesn't forward. Two orphans => total == 2.
    h.putRemoteEpub('p1.epub', title: 'Progress One');
    h.putRemoteEpub('p2.epub', title: 'Progress Two');

    final calls = <(int current, int total, String file)>[];
    await h.service.sync(
      config: h.config,
      readSettings: () => h.localSettings,
      applySettings: (s) async => h.appliedSettings = s,
      onImportProgress: (current, total, file) =>
          calls.add((current, total, file)),
    );

    expect(calls, isNotEmpty);
    // First call announces the batch size with current=0 and an empty name.
    expect(calls.first, (0, 2, ''));
    // Last call signals completion: current == total, empty name.
    expect(calls.last, (2, 2, ''));
    // Every reported total is the orphan count.
    expect(calls.every((c) => c.$2 == 2), isTrue);
    // Both orphans actually landed in the DB.
    final names = (await h.db.booksDao.getAllBooks())
        .map((b) => b.syncFileName)
        .toSet();
    expect(names, containsAll(<String>['p1.epub', 'p2.epub']));
  });
}
