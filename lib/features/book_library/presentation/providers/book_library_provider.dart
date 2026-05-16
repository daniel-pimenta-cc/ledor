import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../../../database/daos/cached_tokens_dao.dart';
import '../../../../database/tables/book_source.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../data/services/inline_image_storage.dart';

/// Stream of all books, sorted by last read date.
final bookLibraryProvider = StreamProvider<List<BooksTableData>>((ref) {
  final booksDao = ref.watch(booksDaoProvider);
  return booksDao.watchAllBooks();
});

/// Books grouped by reading status, each list pre-sorted for display.
class CategorizedBooks {
  final List<BooksTableData> inProgress;
  final List<BooksTableData> notStarted;
  final List<BooksTableData> read;

  const CategorizedBooks({
    required this.inProgress,
    required this.notStarted,
    required this.read,
  });

  bool get isEmpty =>
      inProgress.isEmpty && notStarted.isEmpty && read.isEmpty;
}

/// The kind of content to show in a library tab. Drives the `source` column
/// filter in [categorizedLibraryProvider] and the empty-state copy.
enum LibraryKind { books, articles }

/// Progress fraction per book across the whole library, computed in two DB
/// queries (one for all progress rows, one for all chapter word counts)
/// instead of N+1. Every library tile and the categorized tabs derive from
/// this, so closing the reader re-runs O(1) queries instead of O(N).
final libraryProgressProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final books = await ref.watch(bookLibraryProvider.future);
  final progressDao = ref.read(readingProgressDaoProvider);
  final tokensDao = ref.read(cachedTokensDaoProvider);

  final results = await Future.wait([
    progressDao.getAllProgress(),
    tokensDao.getAllChapterWordCounts(),
  ]);
  final progressRows = results[0] as List<ReadingProgressTableData>;
  final chapterCounts = results[1] as List<ChapterWordCount>;

  final progressByBook = {for (final p in progressRows) p.bookId: p};
  final chaptersByBook = <String, List<ChapterWordCount>>{};
  for (final row in chapterCounts) {
    chaptersByBook.putIfAbsent(row.bookId, () => []).add(row);
  }

  final out = <String, double>{};
  for (final book in books) {
    final progress = progressByBook[book.id];
    if (progress == null || book.totalWords <= 0) {
      out[book.id] = 0.0;
      continue;
    }
    final chapters = chaptersByBook[book.id];
    int wordsBefore = 0;
    if (chapters != null) {
      for (final c in chapters) {
        if (c.chapterIndex < progress.chapterIndex) {
          wordsBefore += c.wordCount;
        }
      }
    }
    final globalIdx = wordsBefore + progress.wordIndex;
    out[book.id] = (globalIdx / book.totalWords).clamp(0.0, 1.0);
  }
  return out;
});

/// Books in the library split into "in progress", "not started", and "read",
/// filtered by [LibraryKind] (books → source='epub', articles → source='article').
///
/// Sorting:
/// - inProgress: most recently read first
/// - notStarted: most recently imported first
/// - read: most recently finished first (by lastReadAt)
final categorizedLibraryProvider =
    FutureProvider.family<CategorizedBooks, LibraryKind>((ref, kind) async {
  final books = await ref.watch(bookLibraryProvider.future);
  final progress = await ref.watch(libraryProgressProvider.future);

  final wantedSource =
      kind == LibraryKind.articles ? BookSource.article : BookSource.epub;
  final filtered = books.where((b) => b.source == wantedSource);

  final inProgress = <BooksTableData>[];
  final notStarted = <BooksTableData>[];
  final read = <BooksTableData>[];

  for (final book in filtered) {
    final fraction = progress[book.id] ?? 0.0;
    if (fraction <= 0.0 || book.totalWords <= 0) {
      notStarted.add(book);
    } else if (fraction >= 0.99) {
      read.add(book);
    } else {
      inProgress.add(book);
    }
  }

  // inProgress is already sorted by lastReadAt desc (from watchAllBooks).
  notStarted.sort((a, b) => b.importedAt.compareTo(a.importedAt));
  read.sort((a, b) {
    final aDate = a.lastReadAt ?? a.importedAt;
    final bDate = b.lastReadAt ?? b.importedAt;
    return bDate.compareTo(aDate);
  });

  return CategorizedBooks(
    inProgress: inProgress,
    notStarted: notStarted,
    read: read,
  );
});

/// Reading progress for a book as a fraction in [0.0, 1.0]. Derived from
/// [libraryProgressProvider] so all cards share a single pair of DB reads.
final bookProgressProvider =
    FutureProvider.family<double, String>((ref, bookId) async {
  final map = await ref.watch(libraryProgressProvider.future);
  return map[bookId] ?? 0.0;
});

/// Delete a book and all its associated data.
final deleteBookProvider =
    Provider.family<Future<void> Function(), String>((ref, bookId) {
  return () async {
    final booksDao = ref.read(booksDaoProvider);
    final tokensDao = ref.read(cachedTokensDaoProvider);
    final progressDao = ref.read(readingProgressDaoProvider);

    await tokensDao.deleteTokensForBook(bookId);
    await progressDao.deleteProgressForBook(bookId);
    await booksDao.deleteBook(bookId);
    // Inline image bytes live outside the DB — drop the whole folder so
    // they don't outlive the book row.
    await const InlineImageStorage().deleteForBook(bookId);

    // Propagate deletion to the sync folder as a tombstone.
    await ref.read(librarySyncProvider.notifier).pushDelete(bookId);
  };
});

/// Jump a book's reading progress to the end so it shows up under "Read".
/// Picks the last chapter's wordCount as the cursor. If that cache row is
/// missing, derives the word count from totalWords so the library's 99%
/// threshold still flips.
final markBookAsReadProvider =
    Provider.family<Future<void> Function(), String>((ref, bookId) {
  return () async {
    final booksDao = ref.read(booksDaoProvider);
    final tokensDao = ref.read(cachedTokensDaoProvider);
    final progressDao = ref.read(readingProgressDaoProvider);

    final book = await booksDao.getBookById(bookId);
    if (book == null || book.chapterCount <= 0) return;

    final lastChapterIndex = book.chapterCount - 1;
    final lastChapter =
        await tokensDao.getTokensForChapter(bookId, lastChapterIndex);
    int lastWordIndex;
    if (lastChapter != null) {
      lastWordIndex = lastChapter.wordCount;
    } else {
      // Tokens cache missing for the last chapter — fall back to whatever
      // totalWords - (words before last chapter) gives us, so the
      // categorizedLibraryProvider's fraction computation still reaches 1.0.
      final wordsBefore =
          await tokensDao.getWordCountBeforeChapter(bookId, lastChapterIndex);
      final remaining = book.totalWords - wordsBefore;
      lastWordIndex = remaining > 0 ? remaining : book.totalWords;
    }

    final existing = await progressDao.getProgressForBook(bookId);
    await progressDao.upsertProgress(ReadingProgressTableCompanion(
      bookId: Value(bookId),
      chapterIndex: Value(lastChapterIndex),
      wordIndex: Value(lastWordIndex),
      wpm: Value(existing?.wpm ?? AppConstants.defaultWpm),
      updatedAt: Value(DateTime.now()),
    ));
    await booksDao.updateLastReadAt(bookId);

    // Push updated progress to the sync folder.
    ref.read(librarySyncProvider.notifier).schedulePush();
  };
});
