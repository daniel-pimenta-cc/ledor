import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/bookmarks_table.dart';

part 'bookmarks_dao.g.dart';

@DriftAccessor(tables: [BookmarksTable])
class BookmarksDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarksDaoMixin {
  BookmarksDao(super.db);

  /// Live list of non-tombstoned bookmarks for a book, ordered by their
  /// position inside the book (top of the book at the top of the list).
  Stream<List<BookmarksTableData>> watchForBook(String bookId) {
    return (select(bookmarksTable)
          ..where((t) => t.bookId.equals(bookId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.globalWordIndex)]))
        .watch();
  }

  Future<List<BookmarksTableData>> getForBook(String bookId) {
    return (select(bookmarksTable)
          ..where((t) => t.bookId.equals(bookId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.globalWordIndex)]))
        .get();
  }

  /// Live list of every non-tombstoned bookmark across the library,
  /// ordered most-recent first. Feeds the global `/bookmarks` screen.
  Stream<List<BookmarksTableData>> watchAll() {
    return (select(bookmarksTable)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<BookmarksTableData?> getById(String id) {
    return (select(bookmarksTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsert(BookmarksTableCompanion entry) {
    return into(bookmarksTable).insertOnConflictUpdate(entry);
  }

  /// Soft-delete: stamp [deletedAt] and bump [updatedAt] so sync can ship
  /// the tombstone with the correct LWW timestamp.
  Future<int> softDelete(String id, {DateTime? when}) {
    final ts = when ?? DateTime.now();
    return (update(bookmarksTable)..where((t) => t.id.equals(id))).write(
      BookmarksTableCompanion(
        deletedAt: Value(ts),
        updatedAt: Value(ts),
      ),
    );
  }

  /// All rows including tombstones — used by sync to ship deletions.
  Future<List<BookmarksTableData>> getAllIncludingTombstones() {
    return (select(bookmarksTable)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Used by sync when applying a remote payload. Replaces the local row
  /// verbatim — caller has already decided who wins the LWW match.
  Future<void> applyFromSync(BookmarksTableCompanion entry) {
    return into(bookmarksTable).insertOnConflictUpdate(entry);
  }

  /// Hard-delete every bookmark for a book. Called when the user removes
  /// the book locally — the books deletion already triggers a tombstone
  /// in `library/books.json`, so we don't need to ship per-bookmark
  /// tombstones for a vanished parent.
  Future<int> deleteAllForBook(String bookId) {
    return (delete(bookmarksTable)..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}
