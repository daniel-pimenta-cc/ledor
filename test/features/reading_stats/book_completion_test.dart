import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/database/app_database.dart';
import 'package:ledor/features/reading_stats/presentation/providers/book_completion_provider.dart';

BooksTableData _book(
  String id,
  String title, {
  int totalWords = 10000,
  int? rating,
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
    rating: rating,
  );
}

ReadingSessionTableData _session({
  required String id,
  required String bookId,
  required DateTime startedAt,
  int durationMs = 60000,
  int wordsRead = 300,
  int endWordIndex = 300,
}) {
  return ReadingSessionTableData(
    id: id,
    bookId: bookId,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(milliseconds: durationMs)),
    durationMs: durationMs,
    wordsRead: wordsRead,
    startWordIndex: 0,
    endWordIndex: endWordIndex,
    avgWpm: (wordsRead * 60000 / durationMs).round(),
  );
}

void main() {
  group('buildCompletionSummary', () {
    test('empty sessions yields zeroed totals and null dates', () {
      final s = buildCompletionSummary(
        book: _book('b1', 'Book One'),
        sessions: const [],
      );
      expect(s.totalWords, 0);
      expect(s.totalDurationMs, 0);
      expect(s.sessionCount, 0);
      expect(s.avgWpm, 0);
      expect(s.firstSessionAt, isNull);
      expect(s.lastSessionAt, isNull);
      expect(s.daysSpan, 0);
      expect(s.rating, isNull);
    });

    test('sums totals and picks min/max timestamps from sessions', () {
      final s = buildCompletionSummary(
        book: _book('b1', 'Book One'),
        sessions: [
          _session(
              id: 's1',
              bookId: 'b1',
              startedAt: DateTime(2026, 4, 1, 9, 0),
              durationMs: 120000,
              wordsRead: 600),
          _session(
              id: 's2',
              bookId: 'b1',
              startedAt: DateTime(2026, 4, 5, 20, 0),
              durationMs: 60000,
              wordsRead: 200),
          _session(
              id: 's3',
              bookId: 'b1',
              startedAt: DateTime(2026, 4, 3, 14, 0),
              durationMs: 30000,
              wordsRead: 100),
        ],
      );

      expect(s.totalWords, 900);
      expect(s.totalDurationMs, 210000);
      expect(s.sessionCount, 3);
      expect(s.avgWpm, (900 * 60000 / 210000).round());
      expect(s.firstSessionAt, DateTime(2026, 4, 1, 9, 0));
      expect(s.lastSessionAt, DateTime(2026, 4, 5, 20, 1));
      expect(s.daysSpan, 5);
    });

    test('propagates book rating and cover fields', () {
      final s = buildCompletionSummary(
        book: _book('b1', 'Book One', rating: 4),
        sessions: const [],
      );
      expect(s.rating, 4);
      expect(s.title, 'Book One');
      expect(s.author, 'Author of Book One');
    });
  });
}
