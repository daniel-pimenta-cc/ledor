import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../../../database/daos/reading_session_dao.dart';
import '../../domain/entities/monthly_recap.dart';

/// Key for [monthlyRecapProvider] — a specific calendar month.
class RecapMonth {
  final int year;
  final int month;
  const RecapMonth(this.year, this.month);

  factory RecapMonth.current() {
    final n = DateTime.now();
    return RecapMonth(n.year, n.month);
  }

  /// [from, to) spanning the full month at local-date midnights.
  ({DateTime from, DateTime to}) window() {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 1);
    return (from: from, to: to);
  }

  @override
  bool operator ==(Object other) =>
      other is RecapMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Computes a [MonthlyRecap] from sessions + books for the given month.
/// Async (not streamed) — the recap screen only reads once per open.
final monthlyRecapProvider =
    FutureProvider.autoDispose.family<MonthlyRecap, RecapMonth>((ref, key) async {
  final sessionDao = ref.watch(readingSessionDaoProvider);
  final booksDao = ref.watch(booksDaoProvider);
  final window = key.window();

  final results = await Future.wait([
    sessionDao.aggregateByBookInRange(window.from, window.to),
    booksDao.getAllBooks(),
  ]);
  final aggregates = results[0] as List<BookSessionAggregate>;
  final books = results[1] as List<BooksTableData>;

  return buildMonthlyRecap(
    key: key,
    aggregates: aggregates,
    books: books,
  );
});

/// Pure aggregation — exposed for tests.
MonthlyRecap buildMonthlyRecap({
  required RecapMonth key,
  required List<BookSessionAggregate> aggregates,
  required List<BooksTableData> books,
}) {
  final bookIndex = {for (final b in books) b.id: b};

  final finished = <RecapBook>[];
  final reading = <RecapBook>[];
  int totalWords = 0;
  int totalDurationMs = 0;

  for (final agg in aggregates) {
    totalWords += agg.totalWords;
    totalDurationMs += agg.totalDurationMs;
    final book = bookIndex[agg.bookId];
    final bookTotalWords = book?.totalWords ?? 0;
    final isFinished =
        bookTotalWords > 0 && agg.maxEndWordIndex >= bookTotalWords - 1;
    final progress = bookTotalWords > 0
        ? (agg.maxEndWordIndex / bookTotalWords).clamp(0.0, 1.0)
        : 0.0;

    final entry = RecapBook(
      bookId: agg.bookId,
      title: book?.title ?? '—',
      author: book?.author,
      coverImage: book?.coverImage,
      totalDurationMs: agg.totalDurationMs,
      progressFraction: isFinished ? 1.0 : progress,
    );

    if (isFinished) {
      finished.add(entry);
    } else {
      reading.add(entry);
    }
  }

  finished.sort((a, b) => b.totalDurationMs.compareTo(a.totalDurationMs));
  reading.sort((a, b) => b.totalDurationMs.compareTo(a.totalDurationMs));

  return MonthlyRecap(
    year: key.year,
    month: key.month,
    finished: finished,
    reading: reading,
    totalWords: totalWords,
    totalDurationMs: totalDurationMs,
  );
}
