import 'package:drift/drift.dart';

import 'book_source.dart';

class BooksTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get filePath => text()();
  BlobColumn get coverImage => blob().nullable()();
  IntColumn get totalWords => integer().withDefault(const Constant(0))();
  IntColumn get chapterCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get importedAt => dateTime()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  /// Filename used when storing this book's EPUB in the sync folder. We keep
  /// the user's original filename (with numeric suffix to disambiguate
  /// collisions) instead of the UUID so the folder is browsable.
  /// Null for books imported before the sync-filename feature landed.
  TextColumn get syncFileName => text().nullable()();

  /// Origin of the content. See [BookSource] for the allowed values.
  /// Drives library tab filtering and whether the row participates in EPUB sync.
  TextColumn get source => text().withDefault(const Constant(BookSource.epub))();

  /// For `source = article`: the URL it was imported from.
  TextColumn get sourceUrl => text().nullable()();

  /// For `source = article`: the site name (extracted by readability), used
  /// as a subtitle/attribution in the library card.
  TextColumn get siteName => text().nullable()();

  /// Reader rating: null = unrated, 1..5 otherwise. Rendered on the book
  /// completion card and persisted so rating survives re-reading.
  IntColumn get rating => integer().nullable()();

  /// Stamped when [rating] is written (including clears). Needed by sync's
  /// per-field LWW merge — without it, a fresh rating on one device can be
  /// overwritten by another device whose unrelated update (progress, etc.)
  /// bumped the parent updatedAt later.
  DateTimeColumn get ratingUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
