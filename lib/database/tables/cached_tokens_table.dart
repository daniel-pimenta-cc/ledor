import 'package:drift/drift.dart';

import 'books_table.dart';

/// Covering index: `getTokensForBook` filtra por bookId, e
/// `getAllChapterWordCounts` / `getWordCountBeforeChapter` leem só
/// (bookId, chapterIndex, wordCount) — com o índice cobrindo as três
/// colunas, o SQLite resolve essas queries sem tocar nas linhas da
/// tabela, que carregam o blob `tokensJson` (wordCount vem DEPOIS do
/// blob no record, então ler a coluna direto da tabela forçaria a
/// leitura das overflow pages de todos os capítulos da biblioteca).
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
