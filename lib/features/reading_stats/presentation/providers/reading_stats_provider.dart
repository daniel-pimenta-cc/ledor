import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../domain/entities/stats_range.dart';
import '../../domain/entities/stats_snapshot.dart';

/// Streams a [StatsSnapshot] for the requested [StatsRange], recomputing
/// whenever sessions are added/deleted. Books are joined in-memory from a
/// single `getAllBooks` call per emission.
final statsSnapshotProvider = StreamProvider.autoDispose
    .family<StatsSnapshot, StatsRange>((ref, range) async* {
  final sessionDao = ref.watch(readingSessionDaoProvider);
  final booksDao = ref.watch(booksDaoProvider);
  final window = range.window();

  await for (final sessions
      in sessionDao.watchSessionsInRange(window.from, window.to)) {
    final books = await booksDao.getAllBooks();
    yield buildSnapshot(
      range: range,
      from: window.from,
      to: window.to,
      sessions: sessions,
      books: books,
    );
  }
});

/// Pure aggregation — exposed for unit tests.
StatsSnapshot buildSnapshot({
  required StatsRange range,
  required DateTime from,
  required DateTime to,
  required List<ReadingSessionTableData> sessions,
  required List<BooksTableData> books,
}) {
  final bookIndex = {for (final b in books) b.id: b};

  // Daily buckets keyed by midnight DateTime.
  final daysCount = to.difference(from).inDays;
  final bucketMap = <DateTime, _MutableDailyBucket>{};
  for (int i = 0; i < daysCount; i++) {
    final day = DateTime(from.year, from.month, from.day + i);
    bucketMap[day] = _MutableDailyBucket(day);
  }

  final bookAggMap = <String, _MutableBookAgg>{};

  for (final s in sessions) {
    final dayKey = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
    final bucket = bucketMap[dayKey];
    if (bucket == null) continue; // safety: session outside window
    bucket.addSession(s);

    final agg = bookAggMap.putIfAbsent(s.bookId, () => _MutableBookAgg(s.bookId));
    agg.addSession(s);
  }

  final breakdowns = bookAggMap.values
      .map((a) {
        final book = bookIndex[a.bookId];
        return BookBreakdown(
          bookId: a.bookId,
          title: book?.title ?? _fallbackTitle,
          totalDurationMs: a.totalDurationMs,
          sessionCount: a.sessionCount,
        );
      })
      .toList()
    ..sort((a, b) => b.totalDurationMs.compareTo(a.totalDurationMs));

  final totalWords = sessions.fold<int>(0, (sum, s) => sum + s.wordsRead);
  final totalDurationMs = sessions.fold<int>(0, (sum, s) => sum + s.durationMs);
  final avgWpm = totalDurationMs > 0
      ? (totalWords * 60000 / totalDurationMs).round()
      : 0;

  return StatsSnapshot(
    range: range,
    dailyBuckets: bucketMap.values.map((b) => b.freeze()).toList(growable: false),
    bookBreakdowns: breakdowns,
    totalWords: totalWords,
    totalDurationMs: totalDurationMs,
    avgWpm: avgWpm,
  );
}

const _fallbackTitle = '—';

class _MutableDailyBucket {
  final DateTime day;
  final Map<String, _MutableBookSlice> perBook = {};
  int totalWords = 0;
  int totalDurationMs = 0;

  _MutableDailyBucket(this.day);

  void addSession(ReadingSessionTableData s) {
    totalWords += s.wordsRead;
    totalDurationMs += s.durationMs;
    final slice =
        perBook.putIfAbsent(s.bookId, () => _MutableBookSlice(s.bookId));
    slice.wordsRead += s.wordsRead;
  }

  DailyBucket freeze() {
    final slices = perBook.values
        .map((m) => DailyBookSlice(
              bookId: m.bookId,
              wordsRead: m.wordsRead,
            ))
        .toList(growable: false);
    return DailyBucket(
      day: day,
      perBook: slices,
      totalWords: totalWords,
      totalDurationMs: totalDurationMs,
      avgWpm: totalDurationMs > 0
          ? (totalWords * 60000 / totalDurationMs).round()
          : null,
    );
  }
}

class _MutableBookSlice {
  final String bookId;
  int wordsRead = 0;
  _MutableBookSlice(this.bookId);
}

class _MutableBookAgg {
  final String bookId;
  int totalDurationMs = 0;
  int sessionCount = 0;
  _MutableBookAgg(this.bookId);

  void addSession(ReadingSessionTableData s) {
    totalDurationMs += s.durationMs;
    sessionCount++;
  }
}
