import 'package:drift/drift.dart';

import 'books_table.dart';

class ReadingProgressTable extends Table {
  TextColumn get bookId => text().references(BooksTable, #id)();
  IntColumn get chapterIndex => integer()();
  IntColumn get wordIndex => integer()();
  IntColumn get wpm => integer().withDefault(const Constant(300))();
  DateTimeColumn get updatedAt => dateTime()();

  /// Last reader mode (`'rsvp'`, `'ereader'`, or `'tts'`) the user
  /// explicitly chose for this book. `scroll` collapses into `rsvp` here
  /// since the two share a single user-facing identity — `scroll` is just
  /// the paused half of the RSVP experience.
  ///
  /// `null` means "never chosen" (default behaviour: open in scroll/RSVP).
  /// Added in schema v8.
  TextColumn get readerMode => text().nullable()();

  @override
  Set<Column> get primaryKey => {bookId};
}
