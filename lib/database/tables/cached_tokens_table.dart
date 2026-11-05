import 'package:drift/drift.dart';

import 'books_table.dart';

/// Covering index: `getTokensForBook` filters by bookId, and
/// `getAllChapterWordCounts` / `getWordCountBeforeChapter` read only
/// (bookId, chapterIndex, wordCount). With the index covering all three
/// columns, SQLite answers those queries without touching the table rows,
/// which carry the `tokensJson` blob (wordCount comes AFTER the blob in
/// the record, so reading the column from the table would force reading
/// the overflow pages of every chapter in the library).
@TableIndex(
  name: 'cached_tokens_book_id_idx',
  columns: {#bookId, #chapterIndex, #wordCount},
)
class CachedTokensTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().references(BooksTable, #id)();
  IntColumn get chapterIndex => integer()();
  TextColumn get chapterTitle => text().withDefault(const Constant(''))();
  TextColumn get tokensJson => text()();
  IntColumn get wordCount => integer()();
  IntColumn get paragraphCount => integer().withDefault(const Constant(0))();
}
