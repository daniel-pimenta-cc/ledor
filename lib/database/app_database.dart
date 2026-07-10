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
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Every step is idempotent: it skips work whose table/index/column is
        // already present. This is essential because a *prior aborted upgrade*
        // can leave the DB partially migrated. sqlite auto-commits each DDL
        // statement, but drift only bumps `user_version` after the whole
        // callback succeeds — so if any step throws, every object created
        // before it stays committed while the version stays put. On the next
        // open the migration re-runs from the same low version and, without
        // these guards, crashes on the first `CREATE`/`ADD COLUMN` whose
        // object already exists ("index ... already exists", "duplicate
        // column name"). A real device (a Galaxy Tab on a v4 build) hit this:
        // the first run created reading_session, its indexes and bookmarks
        // before aborting on the old double-add of the v10 columns. Guarding
        // every operation lets such a wedged DB roll all the way to the
        // current schema instead of crash-looping.
        onUpgrade: (m, from, to) async {
          Future<void> addColumnIfMissing(
              TableInfo table, GeneratedColumn column) async {
            if (!await _columnExists(table.actualTableName, column.name)) {
              await m.addColumn(table, column);
            }
          }

          Future<void> createIndexIfMissing(Index index) async {
            if (!await _indexExists(index.entityName)) {
              await m.createIndex(index);
            }
          }

          if (from < 2) {
            await addColumnIfMissing(booksTable, booksTable.syncFileName);
          }
          if (from < 3) {
            await m.createTable(syncImportFailuresTable);
          }
          if (from < 4) {
            await addColumnIfMissing(booksTable, booksTable.source);
            await addColumnIfMissing(booksTable, booksTable.sourceUrl);
            await addColumnIfMissing(booksTable, booksTable.siteName);
          }
          if (from < 5) {
            await m.createTable(readingSessionTable);
            await createIndexIfMissing(readingSessionStartedAtIdx);
            await createIndexIfMissing(readingSessionBookIdIdx);
          }
          if (from < 6) {
            await addColumnIfMissing(booksTable, booksTable.rating);
          }
          if (from < 7) {
            await addColumnIfMissing(booksTable, booksTable.ratingUpdatedAt);
          }
          if (from < 8) {
            await addColumnIfMissing(
                readingProgressTable, readingProgressTable.readerMode);
          }
          if (from < 9) {
            // createTable materialises the *current* BookmarksTable, which
            // already carries the v10 endGlobalWordIndex/endChapterIndex
            // columns. So a DB from < 9 gets them here, and the addColumn
            // step below sees them present and skips — no double-add.
            await m.createTable(bookmarksTable);
            await createIndexIfMissing(bookmarksBookIdIdx);
          }
          if (from < 10) {
            // Adds the end-anchor columns for DBs created at the v9 shape;
            // a no-op for DBs from < 9 that already got them via createTable.
            await addColumnIfMissing(
                bookmarksTable, bookmarksTable.endGlobalWordIndex);
            await addColumnIfMissing(
                bookmarksTable, bookmarksTable.endChapterIndex);
          }
          if (from < 11) {
            await createIndexIfMissing(cachedTokensBookIdIdx);
          }
        },
      );

  /// Whether an index named [name] exists.
  Future<bool> _indexExists(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?",
      variables: [Variable.withString(name)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Whether [table] has a column named [column]. The table name is a trusted
  /// schema constant, so interpolating it into the PRAGMA is safe (PRAGMA
  /// doesn't accept bound parameters for its argument).
  Future<bool> _columnExists(String table, String column) async {
    final rows = await customSelect("PRAGMA table_info('$table')").get();
    return rows.any((r) => r.data['name'] == column);
  }
}
