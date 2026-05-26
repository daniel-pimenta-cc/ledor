import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/features/library_sync/domain/entities/sync_library.dart';

DateTime _t(int offsetSec) =>
    DateTime.utc(2026, 1, 1).add(Duration(seconds: offsetSec));

SyncLibraryBookmark _bm({
  required String id,
  String bookId = 'book-1',
  int globalWordIndex = 100,
  int chapterIndex = 0,
  String? label,
  String? contextSnippet,
  int createdAtSec = 0,
  required int updatedAtSec,
  int? deletedAtSec,
}) {
  return SyncLibraryBookmark(
    id: id,
    bookId: bookId,
    globalWordIndex: globalWordIndex,
    chapterIndex: chapterIndex,
    label: label,
    contextSnippet: contextSnippet,
    createdAt: _t(createdAtSec),
    updatedAt: _t(updatedAtSec),
    deletedAt: deletedAtSec == null ? null : _t(deletedAtSec),
  );
}

void main() {
  group('mergeBookmark', () {
    test('picks the side with the newer updatedAt', () {
      final older = _bm(id: 'a', label: 'old', updatedAtSec: 10);
      final newer = _bm(id: 'a', label: 'new', updatedAtSec: 20);
      expect(mergeBookmark(older, newer).label, 'new');
      expect(mergeBookmark(newer, older).label, 'new');
    });

    test('newer tombstone wins over older live row', () {
      final live = _bm(id: 'a', label: 'kept', updatedAtSec: 10);
      final tombstone =
          _bm(id: 'a', updatedAtSec: 20, deletedAtSec: 20);
      final result = mergeBookmark(live, tombstone);
      expect(result.deletedAt, isNotNull);
    });

    test('older tombstone loses to newer revival (edge: undelete)', () {
      // If a peer somehow updated the row after the tombstone, the newer
      // update wins. Not a normal flow but the merge must be timestamp-only.
      final tombstone =
          _bm(id: 'a', label: 'old', updatedAtSec: 10, deletedAtSec: 10);
      final revived = _bm(id: 'a', label: 'new', updatedAtSec: 20);
      final result = mergeBookmark(tombstone, revived);
      expect(result.deletedAt, isNull);
      expect(result.label, 'new');
    });
  });

  group('mergeBookmarksShard', () {
    test('unions ids and applies LWW per record', () {
      final local = SyncBookmarksShard(
        updatedAt: _t(0),
        updatedBy: 'dev-a',
        bookmarks: [
          _bm(id: 'a', label: 'a-old', updatedAtSec: 5),
          _bm(id: 'b', label: 'b-local', updatedAtSec: 30),
        ],
      );
      final remote = SyncBookmarksShard(
        updatedAt: _t(0),
        updatedBy: 'dev-b',
        bookmarks: [
          _bm(id: 'a', label: 'a-new', updatedAtSec: 50),
          _bm(id: 'c', label: 'c-only', updatedAtSec: 10),
        ],
      );
      final merged = mergeBookmarksShard(local, remote, 'dev-a');
      expect(merged.bookmarks.length, 3);
      final byId = {for (final b in merged.bookmarks) b.id: b};
      expect(byId['a']!.label, 'a-new');
      expect(byId['b']!.label, 'b-local');
      expect(byId['c']!.label, 'c-only');
    });

    test('output is sorted by id deterministically', () {
      final local = SyncBookmarksShard(
        updatedAt: _t(0),
        updatedBy: 'dev-a',
        bookmarks: [
          _bm(id: 'z', updatedAtSec: 5),
          _bm(id: 'a', updatedAtSec: 5),
        ],
      );
      final remote = SyncBookmarksShard(
        updatedAt: _t(0),
        updatedBy: 'dev-b',
        bookmarks: [_bm(id: 'm', updatedAtSec: 5)],
      );
      final merged = mergeBookmarksShard(local, remote, 'dev-x');
      expect(merged.bookmarks.map((b) => b.id).toList(), ['a', 'm', 'z']);
    });

    test('encode/decode round-trips tombstone fields', () {
      final shard = SyncBookmarksShard(
        updatedAt: _t(100),
        updatedBy: 'dev-a',
        bookmarks: [
          _bm(
            id: 'x',
            label: 'note',
            contextSnippet: '… foo [bar] baz …',
            updatedAtSec: 100,
            deletedAtSec: 100,
          ),
        ],
      );
      final decoded = SyncBookmarksShard.decode(shard.encode());
      expect(decoded.bookmarks.length, 1);
      final bm = decoded.bookmarks.single;
      expect(bm.id, 'x');
      expect(bm.label, 'note');
      expect(bm.contextSnippet, '… foo [bar] baz …');
      expect(bm.deletedAt, isNotNull);
    });
  });
}
