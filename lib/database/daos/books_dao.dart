import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/books_table.dart';

part 'books_dao.g.dart';

@DriftAccessor(tables: [BooksTable])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  Future<List<BooksTableData>> getAllBooks() {
    return (select(booksTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastReadAt)]))
        .get();
  }

  Stream<List<BooksTableData>> watchAllBooks() {
    return (select(booksTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastReadAt)]))
        .watch();
  }

  Future<BooksTableData?> getBookById(String id) {
    return (select(booksTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<BooksTableData?> watchBookById(String id) {
    return (select(booksTable)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<void> insertBook(BooksTableCompanion book) {
    return into(booksTable).insert(book);
  }

  Future<void> updateLastReadAt(String bookId) {
    return setLastReadAt(bookId, DateTime.now());
  }

  /// Sets `lastReadAt` to a specific value. Used by sync when applying a
  /// remote timestamp — [updateLastReadAt] would stamp the sync time here,
  /// which shuffles already-read books to the top of the list.
  Future<void> setLastReadAt(String bookId, DateTime when) {
    return (update(booksTable)..where((t) => t.id.equals(bookId))).write(
      BooksTableCompanion(lastReadAt: Value(when)),
    );
  }

  /// Pass `null` to clear a previously set rating. Any out-of-range value
  /// is clamped at the call site (we don't enforce here so the rating
  /// picker can stay the source of truth on validation).
  ///
  /// Stamps [ratingUpdatedAt] on every write (including clears) so sync's
  /// per-field LWW can compare rating recency across devices independently
  /// of progress updates.
  Future<void> updateRating(String bookId, int? rating) {
    return (update(booksTable)..where((t) => t.id.equals(bookId))).write(
      BooksTableCompanion(
        rating: Value(rating),
        ratingUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sync uses this to apply a rating coming from a remote device. The
  /// remote timestamp is preserved verbatim so subsequent LWW comparisons
  /// against other devices stay consistent.
  Future<void> applySyncedRating(
    String bookId,
    int? rating,
    DateTime? ratingUpdatedAt,
  ) {
    return (update(booksTable)..where((t) => t.id.equals(bookId))).write(
      BooksTableCompanion(
        rating: Value(rating),
        ratingUpdatedAt: Value(ratingUpdatedAt),
      ),
    );
  }

  Future<int> deleteBook(String id) {
    return (delete(booksTable)..where((t) => t.id.equals(id))).go();
  }
}
