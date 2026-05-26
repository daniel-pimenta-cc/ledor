import 'package:drift/drift.dart';

/// Named save points inside a book/article. The user creates one with a
/// long-press on a word; tapping it later seeks the reader back to that
/// word.
///
/// Why no foreign key to BooksTable: bookmarks survive a temporary local
/// delete (or a re-import with a different `bookId` — should not happen,
/// but harmless). The DAO filters orphans defensively, and the sync layer
/// emits a tombstone row separately for each deleted bookmark so other
/// devices converge.
///
/// `deletedAt` carries tombstone semantics — the row stays so the next
/// sync push can ship the deletion to peers. The DAO's `watch*` /
/// `getAllForBook` queries hide tombstoned rows from the UI; sync queries
/// see them.
@TableIndex(name: 'bookmarks_book_id_idx', columns: {#bookId})
class BookmarksTable extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();

  /// Global word index inside the book — what the reader engine actually
  /// seeks to. We persist it directly (rather than reconstructing from
  /// chapter+wordIndex) so a bookmark survives even if a re-import shifts
  /// chapter boundaries. The seek path already clamps to total words.
  IntColumn get globalWordIndex => integer()();

  /// Chapter index at creation time — kept so the list can show
  /// "Ch. N · 42%" without having to re-resolve `globalWordIndex` against
  /// the current chapter table. Survives re-imports trivially: if the
  /// chapter shape changed, the seek path normalises through
  /// `_globalToLocal`, and only the displayed chapter number drifts.
  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();

  /// Last word of a multi-word selection (inclusive). Null for the common
  /// single-word case. When set, the UI can render the selected range
  /// verbatim and the seek path still uses [globalWordIndex] (the start)
  /// — the end is informational + used to rebuild the snippet on devices
  /// that import the book later.
  IntColumn get endGlobalWordIndex => integer().nullable()();

  /// Chapter of the [endGlobalWordIndex] anchor. Null for single-word
  /// bookmarks; useful for ranges that cross a chapter boundary.
  IntColumn get endChapterIndex => integer().nullable()();

  /// Optional user-supplied note shown as the primary label in the list.
  /// When null, the UI falls back to [contextSnippet].
  TextColumn get label => text().nullable()();

  /// Few words around the bookmarked word, captured at creation time, so
  /// the list has a meaningful preview even when [label] is null and the
  /// book hasn't been loaded into the engine yet (e.g. opening Bookmarks
  /// from outside the reader, syncing in fresh on a new device).
  TextColumn get contextSnippet => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Non-null marks the row as a tombstone. Sync ships these to peers so
  /// deletes converge; the DAO hides them from the reader UI.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
