import 'package:flutter_test/flutter_test.dart';

import 'helpers/sync_service_harness.dart';

/// Tombstone behaviour of LibrarySyncService.sync(): remote deletions must
/// cascade into the local DB, the tombstone must survive in the pushed shard
/// so peers converge, and the "active book wins a syncFileName dispute against
/// a tombstone" invariant must hold across both the shard compaction step and
/// the EPUB upload/delete step. A local-only book must never be turned into a
/// tombstone by the sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncServiceHarness h;

  setUp(() async {
    h = SyncServiceHarness();
    await h.init();
  });

  tearDown(() => h.dispose());

  test(
      'remote tombstone deletes the local book and cascades to progress, '
      'tokens and bookmarks', () async {
    // Local book with progress, a cached-token chapter and a bookmark.
    await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
    await h.seedLocalProgress(bookId: 'book-1', wordIndex: 7);
    await h.db.cachedTokensDao.insertChapterTokens(
      CachedTokensTableCompanion.insert(
        bookId: 'book-1',
        chapterIndex: 0,
        tokensJson: '[]',
        wordCount: 5,
      ),
    );
    await h.seedLocalBookmark(id: 'bm-1', bookId: 'book-1', label: 'mark');

    // Remote shard carries the same id as a tombstone, with a deletedAt that
    // is strictly after the local book's updatedAt (importedAt 2026-01-01) so
    // mergeBook keeps the tombstone.
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        deletedAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      ),
    ]);

    await h.runSync();

    // The cascade: every local trace of the book is gone.
    expect(await h.db.booksDao.getBookById('book-1'), isNull);
    expect(await h.db.readingProgressDao.getProgressForBook('book-1'), isNull);
    expect(await h.db.cachedTokensDao.getTokensForBook('book-1'), isEmpty);
    // Including tombstones: deleteAllForBook hard-deletes, leaving no row.
    final bookmarks = await h.db.bookmarksDao.getAllIncludingTombstones();
    expect(bookmarks.where((b) => b.bookId == 'book-1'), isEmpty);
  });

  test('tombstone survives in the pushed books shard so peers converge',
      () async {
    await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');

    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        deletedAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      ),
    ]);

    await h.runSync();

    // The merged shard pushed back must still carry the tombstone — dropping
    // it would resurrect the book on every peer that still has it active.
    final pushed = h.readBooksShard()!;
    final entry = pushed.books.singleWhere((b) => b.id == 'book-1');
    expect(entry.deletedAt, isNotNull,
        reason: 'tombstone must remain in the pushed shard');
    expect(entry.deletedAt!.isAtSameMomentAs(DateTime.utc(2026, 2, 1)), isTrue);
  });

  test(
      'zombie tombstone disputing an active book\'s syncFileName is compacted '
      'out of the pushed shard; the active survives intact', () async {
    // Active local book claims shared.epub.
    await h.seedLocalBook(id: 'active', syncFileName: 'shared.epub');

    // Remote shard has the active book PLUS a stale tombstone (different id)
    // that claims the SAME syncFileName. _compactZombieTombstones must drop
    // the tombstone since an active entry owns that filename.
    h.putBooksShard([
      h.makeRemoteBook(id: 'active', syncFileName: 'shared.epub'),
      h.makeRemoteBook(
        id: 'zombie',
        syncFileName: 'shared.epub',
        deletedAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      ),
    ]);

    await h.runSync();

    final pushed = h.readBooksShard()!;
    expect(pushed.books.map((b) => b.id), isNot(contains('zombie')),
        reason: 'zombie tombstone losing the filename dispute is compacted');
    // The active book stays, undeleted.
    final active = pushed.books.singleWhere((b) => b.id == 'active');
    expect(active.deletedAt, isNull);
    // And the active book still exists locally.
    expect(await h.db.booksDao.getBookById('active'), isNotNull);
  });

  test(
      'tombstone whose filename is claimed by an active book does NOT delete '
      'books/<file> on the remote', () async {
    // NOTE (mutation-testing finding): today this scenario is already
    // neutralized one layer earlier — _compactZombieTombstones strips the
    // disputing tombstone from the merged shard before _uploadMissingEpubs
    // ever iterates it, so the activeFileNames guard inside the upload loop
    // is defence-in-depth (removing it is an equivalent mutant). This test
    // pins the net effect: whichever layer does the work, the active book's
    // file must survive the sync.

    // Active local book owns shared.epub; its EPUB already sits in the folder.
    await h.seedLocalBook(id: 'active', syncFileName: 'shared.epub');
    h.putRemoteEpub('shared.epub');

    // Remote shard pairs the active with a tombstone fighting for the same
    // filename. In _uploadMissingEpubs the active wins, so the file must be
    // left untouched (no delete, no clobber).
    h.putBooksShard([
      h.makeRemoteBook(id: 'active', syncFileName: 'shared.epub'),
      h.makeRemoteBook(
        id: 'zombie',
        syncFileName: 'shared.epub',
        deletedAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      ),
    ]);

    await h.runSync();

    expect(h.gateway.deleteLog, isNot(contains('books/shared.epub')),
        reason: 'active book wins the filename dispute; file is preserved');
    expect(h.gateway.binFiles.keys, contains('books/shared.epub'));
  });

  test(
      'tombstone with no active claimant deletes its existing books/<file> '
      'from the remote', () async {
    // A pre-existing EPUB in the folder that only a tombstone references.
    h.putRemoteEpub('gone.epub');
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'gone',
        syncFileName: 'gone.epub',
        deletedAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      ),
    ]);

    await h.runSync();

    // _uploadMissingEpubs sees the file present + tombstoned + unclaimed →
    // round-trips a delete.
    expect(h.gateway.deleteLog, contains('books/gone.epub'));
    expect(h.gateway.binFiles.keys, isNot(contains('books/gone.epub')));
  });

  test('a local-only book is pushed as an active entry, never a tombstone',
      () async {
    // Book exists locally but the remote shard is empty.
    await h.seedLocalBook(id: 'local-only', syncFileName: 'local-only.epub');

    await h.runSync();

    final pushed = h.readBooksShard()!;
    final entry = pushed.books.singleWhere((b) => b.id == 'local-only');
    expect(entry.deletedAt, isNull,
        reason: 'local book absent from remote must stay active, not tombstone');
    // And it survives locally (never deleted by the apply step).
    expect(await h.db.booksDao.getBookById('local-only'), isNotNull);
    // Its EPUB is uploaded to the folder.
    expect(h.gateway.binFiles.keys, contains('books/local-only.epub'));
  });
}
