import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../domain/entities/bookmark.dart';

/// Live list of non-tombstoned bookmarks for a book, ordered by their
/// position inside the book.
final bookmarksProvider =
    StreamProvider.autoDispose.family<List<Bookmark>, String>((ref, bookId) {
  final dao = ref.watch(bookmarksDaoProvider);
  return dao.watchForBook(bookId).map(
        (rows) => rows.map(Bookmark.fromRow).toList(growable: false),
      );
});

/// Live count of non-tombstoned bookmarks for a single book. Consumed by
/// the book card to render a "N bookmarks" badge and by the long-press
/// action sheet to conditionally show the "Show bookmarks" entry.
final bookmarkCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, bookId) {
  final dao = ref.watch(bookmarksDaoProvider);
  return dao.watchForBook(bookId).map((rows) => rows.length);
});

/// Live list of every non-tombstoned bookmark across the whole library.
/// Used by the global `/bookmarks` screen.
final allBookmarksProvider =
    StreamProvider.autoDispose<List<Bookmark>>((ref) {
  final dao = ref.watch(bookmarksDaoProvider);
  return dao.watchAll().map(
        (rows) => rows.map(Bookmark.fromRow).toList(growable: false),
      );
});

/// Stateless façade for create/update/delete operations on bookmarks of a
/// single book. Each mutation also pings the sync provider so other
/// devices pick the change up on the next push.
class BookmarksController {
  final Ref _ref;
  final String bookId;
  static const _uuid = Uuid();

  BookmarksController(this._ref, this.bookId);

  /// Creates a new bookmark. Returns the persisted [Bookmark] so the UI
  /// can confirm via toast / focus the row in the list. Pass
  /// [endGlobalWordIndex] for a multi-word range; leave null for the
  /// common single-word anchor.
  Future<Bookmark> create({
    required int globalWordIndex,
    required int chapterIndex,
    int? endGlobalWordIndex,
    int? endChapterIndex,
    String? label,
    String? contextSnippet,
  }) async {
    final dao = _ref.read(bookmarksDaoProvider);
    final now = DateTime.now();
    final trimmedLabel = label?.trim();
    final entry = BookmarksTableCompanion.insert(
      id: _uuid.v4(),
      bookId: bookId,
      globalWordIndex: globalWordIndex,
      chapterIndex: Value(chapterIndex),
      endGlobalWordIndex: Value(endGlobalWordIndex),
      endChapterIndex: Value(endChapterIndex),
      label: Value(
          (trimmedLabel == null || trimmedLabel.isEmpty) ? null : trimmedLabel),
      contextSnippet: Value(contextSnippet),
      createdAt: now,
      updatedAt: now,
    );
    await dao.upsert(entry);
    _ref.read(librarySyncProvider.notifier).schedulePush();

    return Bookmark(
      id: entry.id.value,
      bookId: bookId,
      globalWordIndex: globalWordIndex,
      chapterIndex: chapterIndex,
      endGlobalWordIndex: endGlobalWordIndex,
      endChapterIndex: endChapterIndex,
      label: entry.label.value,
      contextSnippet: contextSnippet,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Updates only the label. Empty / whitespace-only input clears the
  /// label so the snippet preview kicks back in.
  Future<void> updateLabel(String id, String? label) async {
    final dao = _ref.read(bookmarksDaoProvider);
    final trimmed = label?.trim();
    final cleaned = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    await dao.updateLabel(id, cleaned);
    _ref.read(librarySyncProvider.notifier).schedulePush();
  }

  /// Soft-deletes the bookmark — the row stays as a tombstone so the next
  /// sync push can ship the deletion to peers.
  Future<void> delete(String id) async {
    final dao = _ref.read(bookmarksDaoProvider);
    await dao.softDelete(id);
    _ref.read(librarySyncProvider.notifier).schedulePush();
  }
}

final bookmarksControllerProvider =
    Provider.autoDispose.family<BookmarksController, String>(
  (ref, bookId) => BookmarksController(ref, bookId),
);
