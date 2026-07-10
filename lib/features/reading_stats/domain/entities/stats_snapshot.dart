import 'stats_range.dart';

/// Per-book contribution within a single day.
class DailyBookSlice {
  final String bookId;
  final int wordsRead;

  const DailyBookSlice({
    required this.bookId,
    required this.wordsRead,
  });
}

/// One bucket per calendar day in the stats window. `perBook` holds the
/// stacked-chart slices for the day; `totalWords`/`totalDurationMs`/`avgWpm`
/// are the totals across all books that day. `avgWpm` is null on days with
/// no sessions.
class DailyBucket {
  final DateTime day;
  final List<DailyBookSlice> perBook;
  final int totalWords;
  final int totalDurationMs;
  final int? avgWpm;

  const DailyBucket({
    required this.day,
    required this.perBook,
    required this.totalWords,
    required this.totalDurationMs,
    required this.avgWpm,
  });

  bool get isEmpty => totalWords == 0;
}

/// Total reading attributable to a single book within the window.
/// Ordered descending by [totalDurationMs] in [StatsSnapshot.bookBreakdowns].
class BookBreakdown {
  final String bookId;
  final String title;
  final int totalDurationMs;
  final int sessionCount;

  const BookBreakdown({
    required this.bookId,
    required this.title,
    required this.totalDurationMs,
    required this.sessionCount,
  });
}

class StatsSnapshot {
  final StatsRange range;
  final List<DailyBucket> dailyBuckets;
  final List<BookBreakdown> bookBreakdowns;
  final int totalWords;
  final int totalDurationMs;
  final int avgWpm;

  const StatsSnapshot({
    required this.range,
    required this.dailyBuckets,
    required this.bookBreakdowns,
    required this.totalWords,
    required this.totalDurationMs,
    required this.avgWpm,
  });

  int get booksTouched => bookBreakdowns.length;
  bool get isEmpty => totalWords == 0;
}
