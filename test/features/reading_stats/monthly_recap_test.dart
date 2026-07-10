import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/database/app_database.dart';
import 'package:ledor/database/daos/reading_session_dao.dart';
import 'package:ledor/features/reading_stats/presentation/providers/monthly_recap_provider.dart';

BooksTableData _book(
  String id,
  String title, {
  int totalWords = 10000,
}) {
  return BooksTableData(
    id: id,
    title: title,
    author: 'Author of $title',
    filePath: '/tmp/$id.epub',
    totalWords: totalWords,
    chapterCount: 10,
    importedAt: DateTime(2026, 1, 1),
    source: 'epub',
  );
}

BookSessionAggregate _agg({
  required String bookId,
  int totalDurationMs = 120000,
  int totalWords = 600,
  int sessionCount = 2,
  int maxEndWordIndex = 500,
}) {
  return BookSessionAggregate(
    bookId: bookId,
    totalDurationMs: totalDurationMs,
    totalWords: totalWords,
    sessionCount: sessionCount,
    maxEndWordIndex: maxEndWordIndex,
  );
}

void main() {
  group('buildMonthlyRecap', () {
    final key = const RecapMonth(2026, 4);

    test('empty when no aggregates', () {
      final recap = buildMonthlyRecap(
        key: key,
        aggregates: const [],
        books: const [],
      );
      expect(recap.isEmpty, isTrue);
      expect(recap.totalWords, 0);
      expect(recap.totalDurationMs, 0);
    });

    test('classifies finished when maxEndWordIndex >= totalWords - 1', () {
      final recap = buildMonthlyRecap(
        key: key,
        aggregates: [
          _agg(bookId: 'b1', maxEndWordIndex: 9999), // totalWords 10000 -> finished
        ],
        books: [_book('b1', 'Done', totalWords: 10000)],
      );
      expect(recap.finished, hasLength(1));
      expect(recap.reading, isEmpty);
      expect(recap.finished.single.progressFraction, 1.0);
    });

    test('classifies reading when progress is partial', () {
      final recap = buildMonthlyRecap(
        key: key,
        aggregates: [_agg(bookId: 'b1', maxEndWordIndex: 2500)],
        books: [_book('b1', 'Halfway', totalWords: 10000)],
      );
      expect(recap.reading, hasLength(1));
      expect(recap.finished, isEmpty);
      expect(recap.reading.single.progressFraction, closeTo(0.25, 0.001));
    });

    test('orders both lists by total duration desc', () {
      final recap = buildMonthlyRecap(
        key: key,
        aggregates: [
          _agg(
              bookId: 'b1',
              totalDurationMs: 60000,
              maxEndWordIndex: 2000),
          _agg(
              bookId: 'b2',
              totalDurationMs: 180000,
              maxEndWordIndex: 9999),
          _agg(
              bookId: 'b3',
              totalDurationMs: 30000,
              maxEndWordIndex: 500),
          _agg(
              bookId: 'b4',
              totalDurationMs: 240000,
              maxEndWordIndex: 9999),
        ],
        books: [
          _book('b1', 'Short reading'),
          _book('b2', 'Quick win'),
          _book('b3', 'Tiny reading'),
          _book('b4', 'Marathon'),
        ],
      );
      expect(recap.finished.map((b) => b.bookId).toList(), ['b4', 'b2']);
      expect(recap.reading.map((b) => b.bookId).toList(), ['b1', 'b3']);
    });

    test('sums totals across all aggregates', () {
      final recap = buildMonthlyRecap(
        key: key,
        aggregates: [
          _agg(bookId: 'b1', totalWords: 300, totalDurationMs: 60000),
          _agg(bookId: 'b2', totalWords: 900, totalDurationMs: 180000),
        ],
        books: [_book('b1', 'A'), _book('b2', 'B')],
      );
      expect(recap.totalWords, 1200);
      expect(recap.totalDurationMs, 240000);
    });

    test('handles missing book with fallback title', () {
      final recap = buildMonthlyRecap(
        key: key,
        aggregates: [_agg(bookId: 'gone', maxEndWordIndex: 500)],
        books: const [],
      );
      // No book record -> totalWords is 0 -> treated as reading (not finished)
      // and progressFraction is 0 (can't know total).
      expect(recap.reading.single.title, '—');
      expect(recap.reading.single.progressFraction, 0);
    });
  });

  group('RecapMonth.window', () {
    test('spans exactly the month at midnight boundaries', () {
      final win = const RecapMonth(2026, 4).window();
      expect(win.from, DateTime(2026, 4, 1));
      expect(win.to, DateTime(2026, 5, 1));
    });

    test('wraps December into January of the next year', () {
      final win = const RecapMonth(2026, 12).window();
      expect(win.from, DateTime(2026, 12, 1));
      expect(win.to, DateTime(2027, 1, 1));
    });
  });
}
