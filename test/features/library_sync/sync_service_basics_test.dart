import 'package:flutter_test/flutter_test.dart';

import 'helpers/sync_service_harness.dart';

/// Baseline behaviour of LibrarySyncService.sync(): first push of a local
/// library, and the skip-write idempotency invariant — a second sync with
/// nothing changed must not rewrite any shard. This doubles as the
/// regression net for the isAtSameMomentAs rule: local-TZ DateTimes from
/// Drift vs UTC DateTimes from shard JSON must compare equal for the same
/// instant, otherwise every book would produce a write on every sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncServiceHarness h;

  setUp(() async {
    h = SyncServiceHarness();
    await h.init();
  });

  tearDown(() => h.dispose());

  test('unreadable folder throws StateError and writes nothing', () async {
    h.gateway.readable = false;

    await expectLater(h.runSync(), throwsStateError);
    expect(h.gateway.writeLog, isEmpty);
  });

  test('first sync pushes the local library as shards', () async {
    await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
    await h.seedLocalProgress(
        bookId: 'book-1', wordIndex: 42, readerMode: 'rsvp');

    await h.runSync();

    final shard = h.readBooksShard();
    expect(shard, isNotNull);
    final book = shard!.books.single;
    expect(book.id, 'book-1');
    expect(book.deletedAt, isNull);
    expect(book.progress?.wordIndex, 42);
    expect(book.progress?.readerMode, 'rsvp');
    // The local EPUB is uploaded to books/.
    expect(h.gateway.binFiles.keys, contains('books/book-1.epub'));
  });

  test('second sync with nothing changed rewrites no shard (idempotent)',
      () async {
    await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
    await h.seedLocalProgress(
        bookId: 'book-1', wordIndex: 42, readerMode: 'rsvp');
    await h.seedLocalBookmark(id: 'bm-1', bookId: 'book-1', label: 'mark');

    await h.runSync();
    final writesAfterFirst = h.gateway.writeLog.length;
    expect(writesAfterFirst, greaterThan(0));

    // Round two: local DB rows still carry local-TZ DateTimes, the remote
    // shards now carry the same instants as UTC. Nothing changed, so no
    // shard may be rewritten and no DB write may bump any timestamp.
    await h.runSync();

    expect(h.gateway.writeLog.length, writesAfterFirst,
        reason: 'unchanged shards must not be re-pushed');
  });

  test('articles never enter the books shard', () async {
    // seedLocalBook writes source=epub via default; insert an article row
    // through the DAO directly to mirror the app's article import.
    await h.seedLocalBook(id: 'epub-1', syncFileName: 'epub-1.epub');
    await h.db.booksDao.insertBook(
      BooksTableCompanion.insert(
        id: 'article-1',
        title: 'Some Article',
        filePath: '',
        importedAt: DateTime(2026, 1, 2),
        source: const Value('article'),
        sourceUrl: const Value('https://example.com/a'),
      ),
    );

    await h.runSync();

    final ids = h.readBooksShard()!.books.map((b) => b.id);
    expect(ids, contains('epub-1'));
    expect(ids, isNot(contains('article-1')));
  });
}
