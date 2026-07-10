import 'dart:typed_data';

/// A single book entry on the monthly recap card.
class RecapBook {
  final String bookId;
  final String title;
  final String? author;
  final Uint8List? coverImage;
  final int totalDurationMs;

  /// 0..1, based on `maxEndWordIndex / book.totalWords`. Always 1.0 for
  /// finished books (where the user hit the last word).
  final double progressFraction;

  const RecapBook({
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverImage,
    required this.totalDurationMs,
    required this.progressFraction,
  });
}

class MonthlyRecap {
  final int year;
  final int month; // 1..12
  final List<RecapBook> finished;
  final List<RecapBook> reading;
  final int totalWords;
  final int totalDurationMs;

  const MonthlyRecap({
    required this.year,
    required this.month,
    required this.finished,
    required this.reading,
    required this.totalWords,
    required this.totalDurationMs,
  });

  bool get isEmpty => finished.isEmpty && reading.isEmpty;
}
