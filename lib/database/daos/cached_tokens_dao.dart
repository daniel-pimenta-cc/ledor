import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cached_tokens_table.dart';

part 'cached_tokens_dao.g.dart';

@DriftAccessor(tables: [CachedTokensTable])
class CachedTokensDao extends DatabaseAccessor<AppDatabase>
    with _$CachedTokensDaoMixin {
  CachedTokensDao(super.db);

  Future<List<CachedTokensTableData>> getTokensForBook(String bookId) {
    return (select(cachedTokensTable)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.chapterIndex)]))
        .get();
  }

  Future<CachedTokensTableData?> getTokensForChapter(
    String bookId,
    int chapterIndex,
  ) {
    return (select(cachedTokensTable)
          ..where(
            (t) =>
                t.bookId.equals(bookId) &
                t.chapterIndex.equals(chapterIndex),
          ))
        .getSingleOrNull();
  }

  Future<void> insertChapterTokens(CachedTokensTableCompanion tokens) {
    return into(cachedTokensTable).insert(tokens);
  }

  /// Replaces the serialized token payload of one chapter. Used by the
  /// lazy v1→v2 token-format upgrade after a legacy book is opened.
  Future<void> updateChapterTokensJson({
    required String bookId,
    required int chapterIndex,
    required String tokensJson,
  }) {
    return (update(cachedTokensTable)
          ..where(
            (t) =>
                t.bookId.equals(bookId) &
                t.chapterIndex.equals(chapterIndex),
          ))
        .write(CachedTokensTableCompanion(tokensJson: Value(tokensJson)));
  }

  Future<int> deleteTokensForBook(String bookId) {
    return (delete(cachedTokensTable)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }

  /// Sum of word counts of all chapters with index < [chapterIndex] for [bookId].
  /// Used to convert a chapter-local position into a global word index.
  Future<int> getWordCountBeforeChapter(String bookId, int chapterIndex) async {
    final sumExpr = cachedTokensTable.wordCount.sum();
    final query = selectOnly(cachedTokensTable)
      ..addColumns([sumExpr])
      ..where(
        cachedTokensTable.bookId.equals(bookId) &
            cachedTokensTable.chapterIndex.isSmallerThanValue(chapterIndex),
      );
    final row = await query.getSingleOrNull();
    return row?.read(sumExpr) ?? 0;
  }

  /// Returns `(bookId, chapterIndex, wordCount)` for every chapter across the
  /// whole library in one query, skipping the heavy `tokensJson` blob.
  /// Callers aggregate in Dart to avoid N+1 queries when computing per-book
  /// reading progress for the library.
  Future<List<ChapterWordCount>> getAllChapterWordCounts() async {
    final query = selectOnly(cachedTokensTable)
      ..addColumns([
        cachedTokensTable.bookId,
        cachedTokensTable.chapterIndex,
        cachedTokensTable.wordCount,
      ]);
    final rows = await query.get();
    return [
      for (final r in rows)
        ChapterWordCount(
          bookId: r.read(cachedTokensTable.bookId)!,
          chapterIndex: r.read(cachedTokensTable.chapterIndex)!,
          wordCount: r.read(cachedTokensTable.wordCount)!,
        ),
    ];
  }
}

class ChapterWordCount {
  final String bookId;
  final int chapterIndex;
  final int wordCount;

  const ChapterWordCount({
    required this.bookId,
    required this.chapterIndex,
    required this.wordCount,
  });
}
