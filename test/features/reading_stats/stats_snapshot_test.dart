import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/database/app_database.dart';
import 'package:ledor/features/reading_stats/domain/entities/stats_range.dart';
import 'package:ledor/features/reading_stats/presentation/providers/reading_stats_provider.dart';

ReadingSessionTableData _session({
  required String id,
  required String bookId,
  required DateTime startedAt,
  int durationMs = 60000,
  int wordsRead = 300,
}) {
  return ReadingSessionTableData(
    id: id,
    bookId: bookId,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(milliseconds: durationMs)),
    durationMs: durationMs,
    wordsRead: wordsRead,
    startWordIndex: 0,
    endWordIndex: wordsRead,
    avgWpm: (wordsRead * 60000 / durationMs).round(),
  );
}

BooksTableData _book(String id, String title) {
  return BooksTableData(
    id: id,
    title: title,
    author: 'Author of $title',
    filePath: '/tmp/$id.epub',
    totalWords: 10000,
    chapterCount: 10,
    importedAt: DateTime(2026, 1, 1),
    source: 'epub',
  );
}

void main() {
  group('buildSnapshot', () {
    final now = DateTime(2026, 4, 21, 10, 0);
    final weeklyWindow = StatsRange.weekly.window(now: now);

    test('returns empty snapshot when no sessions', () {
      final snap = buildSnapshot(
        range: StatsRange.weekly,
        from: weeklyWindow.from,
        to: weeklyWindow.to,
        sessions: const [],
        books: const [],
      );
      expect(snap.isEmpty, isTrue);
      expect(snap.dailyBuckets, hasLength(7));
      expect(snap.totalWords, 0);
      expect(snap.totalDurationMs, 0);
      expect(snap.avgWpm, 0);
      expect(snap.bookBreakdowns, isEmpty);
    });

    test('buckets sessions by local calendar day', () {
      final today = DateTime(2026, 4, 21, 9, 30);
      final yesterday = DateTime(2026, 4, 20, 23, 45);
      final snap = buildSnapshot(
        range: StatsRange.weekly,
        from: weeklyWindow.from,
        to: weeklyWindow.to,
        sessions: [
          _session(id: 's1', bookId: 'b1', startedAt: today),
          _session(id: 's2', bookId: 'b1', startedAt: yesterday),
        ],
        books: [_book('b1', 'Book One')],
      );

      final byDay = {for (final b in snap.dailyBuckets) b.day: b};
      expect(byDay[DateTime(2026, 4, 21)]?.totalWords, 300);
      expect(byDay[DateTime(2026, 4, 20)]?.totalWords, 300);
      expect(byDay[DateTime(2026, 4, 19)]?.totalWords, 0);
    });

    test('aggregates book breakdowns ordered by total duration desc', () {
      final day = DateTime(2026, 4, 21, 9, 0);
      final snap = buildSnapshot(
        range: StatsRange.weekly,
        from: weeklyWindow.from,
        to: weeklyWindow.to,
        sessions: [
          _session(id: 's1', bookId: 'b1', startedAt: day, durationMs: 30000),
          _session(
              id: 's2', bookId: 'b2', startedAt: day, durationMs: 120000),
          _session(
              id: 's3', bookId: 'b2', startedAt: day, durationMs: 60000),
        ],
        books: [_book('b1', 'Short'), _book('b2', 'Long')],
      );

      expect(snap.bookBreakdowns, hasLength(2));
      expect(snap.bookBreakdowns.first.bookId, 'b2');
      expect(snap.bookBreakdowns.first.sessionCount, 2);
      expect(snap.bookBreakdowns.first.totalDurationMs, 180000);
      expect(snap.bookBreakdowns.last.bookId, 'b1');
    });

    test('computes weighted avgWpm across sessions', () {
      final day = DateTime(2026, 4, 21, 9, 0);
      final snap = buildSnapshot(
        range: StatsRange.weekly,
        from: weeklyWindow.from,
        to: weeklyWindow.to,
        sessions: [
          // 100 words in 60s = 100 wpm
          _session(
              id: 's1',
              bookId: 'b1',
              startedAt: day,
              durationMs: 60000,
              wordsRead: 100),
          // 500 words in 60s = 500 wpm. Combined: 600 words in 120s = 300 wpm
          _session(
              id: 's2',
              bookId: 'b1',
              startedAt: day,
              durationMs: 60000,
              wordsRead: 500),
        ],
        books: [_book('b1', 'Book')],
      );

      expect(snap.totalWords, 600);
      expect(snap.totalDurationMs, 120000);
      expect(snap.avgWpm, 300);
    });

    test('falls back to placeholder title for deleted books', () {
      final day = DateTime(2026, 4, 21, 9, 0);
      final snap = buildSnapshot(
        range: StatsRange.weekly,
        from: weeklyWindow.from,
        to: weeklyWindow.to,
        sessions: [_session(id: 's1', bookId: 'ghost', startedAt: day)],
        books: const [],
      );

      expect(snap.bookBreakdowns.single.bookId, 'ghost');
      expect(snap.bookBreakdowns.single.title, '—');
    });
  });

  group('StatsRange.window', () {
    test('weekly covers 7 days ending at start-of-tomorrow', () {
      final now = DateTime(2026, 4, 21, 14, 30);
      final win = StatsRange.weekly.window(now: now);
      expect(win.to, DateTime(2026, 4, 22));
      expect(win.from, DateTime(2026, 4, 15));
      expect(win.to.difference(win.from).inDays, 7);
    });

    test('monthly covers 30 days', () {
      final now = DateTime(2026, 4, 21, 14, 30);
      final win = StatsRange.monthly.window(now: now);
      expect(win.to.difference(win.from).inDays, 30);
    });
  });
}
