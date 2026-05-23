import 'package:drift/drift.dart';

import 'daos/bookmarks_dao.dart';
import 'daos/books_dao.dart';
import 'daos/cached_tokens_dao.dart';
import 'daos/reading_progress_dao.dart';
import 'daos/reading_session_dao.dart';
import 'daos/sync_import_failures_dao.dart';
import 'tables/book_source.dart';
import 'tables/bookmarks_table.dart';
import 'tables/books_table.dart';
import 'tables/cached_tokens_table.dart';
import 'tables/reading_progress_table.dart';
import 'tables/reading_session_table.dart';
import 'tables/sync_import_failures_table.dart';

part 'app_database.g.dart';

/// Database schema and serialization notes for the local app database.
///
/// - BooksTable (primary key: `id`): stores metadata for each book or
///   article (title, author, file path, cover image, import timestamps,
///   source and sync filename). `id` is a text UUID used as the canonical
///   identifier for library rows.
/// - CachedTokensTable (primary key: `id`): holds tokenized content per
///   chapter. Each row references a book via `bookId` and contains
///   `chapterIndex`, `chapterTitle`, and `tokensJson` (JSON-serialized
///   token list), plus word/paragraph counts. The `id` column is
///   auto-incremented.
/// - ReadingProgressTable (primary key: `bookId`): a single progress row
///   per book that tracks `chapterIndex`, `wordIndex`, `wpm`,
///   `updatedAt`, and `readerMode` (last reader mode the user chose for
///   this book — `'rsvp'` / `'ereader'` / `'tts'`, nullable).
///
/// Relationships: both `CachedTokensTable.bookId` and
/// `ReadingProgressTable.bookId` reference `BooksTable.id`. `chapterIndex`
/// ties token rows to a reader's progress.
///
/// Token serialization rationale: tokens are stored as JSON per chapter to
/// keep one compact row per chapter instead of normalizing each token into
/// its own row. This reduces DB churn and improves read performance — a
/// ~100k-word book would otherwise produce on the order of ~5k token rows
/// (roughly 2–3 MB), which is slower and heavier to manage than a few
/// per-chapter JSON rows.
///
/// Import-time progress behavior: we intentionally do NOT create a
/// `reading_progress` row during import. The engine treats a missing row as
/// "not started" (see `epub_import_provider.dart`), avoiding unnecessary
/// writes for unread items.
@DriftDatabase(
  tables: [
    BooksTable,
    ReadingProgressTable,
    ReadingSessionTable,
    CachedTokensTable,
    SyncImportFailuresTable,
    BookmarksTable,
  ],
  daos: [
    BooksDao,
    ReadingProgressDao,
    ReadingSessionDao,
    CachedTokensDao,
    SyncImportFailuresDao,
    BookmarksDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(booksTable, booksTable.syncFileName);
          }
          if (from < 3) {
            await m.createTable(syncImportFailuresTable);
          }
          if (from < 4) {
            await m.addColumn(booksTable, booksTable.source);
            await m.addColumn(booksTable, booksTable.sourceUrl);
            await m.addColumn(booksTable, booksTable.siteName);
          }
          if (from < 5) {
            await m.createTable(readingSessionTable);
            await m.createIndex(readingSessionStartedAtIdx);
            await m.createIndex(readingSessionBookIdIdx);
          }
          if (from < 6) {
            await m.addColumn(booksTable, booksTable.rating);
          }
          if (from < 7) {
            await m.addColumn(booksTable, booksTable.ratingUpdatedAt);
          }
          if (from < 8) {
            await m.addColumn(
                readingProgressTable, readingProgressTable.readerMode);
          }
          if (from < 9) {
            await m.createTable(bookmarksTable);
            await m.createIndex(bookmarksBookIdIdx);
          }
          if (from < 10) {
            await m.addColumn(bookmarksTable, bookmarksTable.endGlobalWordIndex);
            await m.addColumn(bookmarksTable, bookmarksTable.endChapterIndex);
          }
        },
      );
}
