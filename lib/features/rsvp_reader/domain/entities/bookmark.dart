import '../../../../database/app_database.dart';

/// A named save point inside a book/article. See [BookmarksTable] for the
/// persisted shape; this entity is the in-memory mirror used by providers
/// and the UI.
class Bookmark {
  final String id;
  final String bookId;
  final int globalWordIndex;
  final int chapterIndex;

  /// Inclusive end of a multi-word range. Null when the bookmark anchors
  /// a single word.
  final int? endGlobalWordIndex;
  final int? endChapterIndex;

  /// User-supplied note. When null the UI falls back to [contextSnippet].
  final String? label;

  /// Few words around the bookmarked word captured at creation time, so
  /// the list has a meaningful preview without re-querying the engine.
  final String? contextSnippet;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Non-null marks the row as a tombstone (locally soft-deleted, kept
  /// around so the next sync push can ship the deletion).
  final DateTime? deletedAt;

  const Bookmark({
    required this.id,
    required this.bookId,
    required this.globalWordIndex,
    required this.chapterIndex,
    this.endGlobalWordIndex,
    this.endChapterIndex,
    this.label,
    this.contextSnippet,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isRange =>
      endGlobalWordIndex != null && endGlobalWordIndex! > globalWordIndex;

  bool get isTombstone => deletedAt != null;

  /// Trimmed label or null. Empty strings are treated as "no label" so the
  /// UI can show the snippet preview instead.
  String? get effectiveLabel {
    final trimmed = label?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Bookmark copyWith({
    String? id,
    String? bookId,
    int? globalWordIndex,
    int? chapterIndex,
    int? endGlobalWordIndex,
    bool clearEndGlobalWordIndex = false,
    int? endChapterIndex,
    bool clearEndChapterIndex = false,
    String? label,
    bool clearLabel = false,
    String? contextSnippet,
    bool clearContextSnippet = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      globalWordIndex: globalWordIndex ?? this.globalWordIndex,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      endGlobalWordIndex: clearEndGlobalWordIndex
          ? null
          : (endGlobalWordIndex ?? this.endGlobalWordIndex),
      endChapterIndex: clearEndChapterIndex
          ? null
          : (endChapterIndex ?? this.endChapterIndex),
      label: clearLabel ? null : (label ?? this.label),
      contextSnippet: clearContextSnippet
          ? null
          : (contextSnippet ?? this.contextSnippet),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  factory Bookmark.fromRow(BookmarksTableData row) => Bookmark(
        id: row.id,
        bookId: row.bookId,
        globalWordIndex: row.globalWordIndex,
        chapterIndex: row.chapterIndex,
        endGlobalWordIndex: row.endGlobalWordIndex,
        endChapterIndex: row.endChapterIndex,
        label: row.label,
        contextSnippet: row.contextSnippet,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );
}
