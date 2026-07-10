import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reading_session_table.dart';

part 'reading_session_dao.g.dart';

/// Aggregated per-book totals over a time range.
class BookSessionAggregate {
  final String bookId;
  final int totalDurationMs;
  final int totalWords;
  final int sessionCount;
  final int maxEndWordIndex;

  const BookSessionAggregate({
    required this.bookId,
    required this.totalDurationMs,
    required this.totalWords,
    required this.sessionCount,
    required this.maxEndWordIndex,
  });
}

@DriftAccessor(tables: [ReadingSessionTable])
class ReadingSessionDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingSessionDaoMixin {
  ReadingSessionDao(super.db);

  Future<void> insertSession(ReadingSessionTableCompanion session) {
    return into(readingSessionTable).insert(session);
  }

  Stream<List<ReadingSessionTableData>> watchSessionsInRange(
    DateTime from,
    DateTime to,
  ) {
    return (select(readingSessionTable)
          ..where((t) => t.startedAt.isBiggerOrEqualValue(from))
          ..where((t) => t.startedAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .watch();
  }

  /// Aggregates sessions in range grouped by bookId. Used for monthly recap
  /// ranking and the stats screen's book breakdown.
  Future<List<BookSessionAggregate>> aggregateByBookInRange(
    DateTime from,
    DateTime to,
  ) async {
    final durationSum = readingSessionTable.durationMs.sum();
    final wordsSum = readingSessionTable.wordsRead.sum();
    final sessionCount = readingSessionTable.id.count();
    final maxEnd = readingSessionTable.endWordIndex.max();

    final query = selectOnly(readingSessionTable)
      ..addColumns([
        readingSessionTable.bookId,
        durationSum,
        wordsSum,
        sessionCount,
        maxEnd,
      ])
      ..where(readingSessionTable.startedAt.isBiggerOrEqualValue(from) &
          readingSessionTable.startedAt.isSmallerThanValue(to))
      ..groupBy([readingSessionTable.bookId]);

    final rows = await query.get();
    return rows
        .map(
          (row) => BookSessionAggregate(
            bookId: row.read(readingSessionTable.bookId)!,
            totalDurationMs: row.read(durationSum) ?? 0,
            totalWords: row.read(wordsSum) ?? 0,
            sessionCount: row.read(sessionCount) ?? 0,
            maxEndWordIndex: row.read(maxEnd) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<List<ReadingSessionTableData>> getAllSessionsForBook(String bookId) {
    return (select(readingSessionTable)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  /// All sessions, ordered by [startedAt]. Used by sync to ship the full
  /// session log; rows are append-only so the count grows only with reading
  /// activity (a few KB per book in JSON).
  Future<List<ReadingSessionTableData>> getAllSessions() {
    return (select(readingSessionTable)
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  /// Returns the set of session ids that already exist locally. Used by sync
  /// when applying remote rows to skip the ones we already have without
  /// fetching them one-by-one.
  Future<Set<String>> existingSessionIds() async {
    final query = selectOnly(readingSessionTable)
      ..addColumns([readingSessionTable.id]);
    final rows = await query.get();
    return rows.map((r) => r.read(readingSessionTable.id)!).toSet();
  }
}
