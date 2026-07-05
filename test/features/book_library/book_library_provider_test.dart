import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/di/providers.dart';
import 'package:ledor/core/utils/text_tokenizer.dart';
import 'package:ledor/database/app_database.dart';
import 'package:ledor/database/tables/book_source.dart';
import 'package:ledor/features/book_library/data/services/book_persistence.dart';
import 'package:ledor/features/book_library/presentation/providers/book_library_provider.dart';
import 'package:ledor/features/epub_import/domain/entities/chapter.dart';
import 'package:ledor/features/epub_import/domain/entities/parsed_book.dart';
import 'package:ledor/features/library_sync/presentation/providers/library_sync_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../fixtures/fake_path_provider.dart';

class _StubLibrarySyncNotifier extends LibrarySyncNotifier {
  _StubLibrarySyncNotifier(super.ref);

  final deletedBookIds = <String>[];

  @override
  void schedulePush() {}

  @override
  void markSettingsDirty() {}

  @override
  Future<void> triggerSync() async {}

  @override
  Future<void> pushDelete(String bookId) async {
    deletedBookIds.add(bookId);
  }
}

ParsedBook _bookWithChapters(String title, List<int> wordCounts) {
  final chapters = <Chapter>[];
  var offset = 0;
  for (var i = 0; i < wordCounts.length; i++) {
    final text =
        List.generate(wordCounts[i], (j) => 'word${offset + j}').join(' ');
    final tokens =
        TextTokenizer.tokenize(text, chapterIndex: i, globalOffset: offset);
    chapters.add(Chapter(title: 'chapter $i', tokens: tokens));
    offset += tokens.length;
  }
  return ParsedBook(
    title: title,
    author: '',
    coverImage: null,
    chapters: chapters,
    totalWords: offset,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProviderContainer container;
  late _StubLibrarySyncNotifier syncStub;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ledor_library_test_');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        librarySyncProvider.overrideWith((ref) {
          return syncStub = _StubLibrarySyncNotifier(ref);
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> persist(ParsedBook book, {String source = BookSource.epub}) {
    return persistParsedBook(
      book: book,
      booksDao: db.booksDao,
      tokensDao: db.cachedTokensDao,
      source: source,
    );
  }

  Future<void> setProgress(String bookId, int chapterIndex, int wordIndex) {
    return db.readingProgressDao.upsertProgress(ReadingProgressTableCompanion(
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      wordIndex: Value(wordIndex),
      wpm: const Value(300),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Re-reads the providers from scratch so assertions never race the drift
  /// watch streams after direct DB writes.
  Future<Map<String, double>> progressMap() async {
    container.invalidate(bookLibraryProvider);
    return container.refresh(libraryProgressProvider.future);
  }

  Future<CategorizedBooks> categorized(LibraryKind kind) async {
    container.invalidate(bookLibraryProvider);
    container.invalidate(libraryProgressProvider);
    return container.refresh(categorizedLibraryProvider(kind).future);
  }

  group('libraryProgressProvider', () {
    test('computes the fraction across chapter boundaries', () async {
      final id = await persist(_bookWithChapters('b', [10, 10, 10]));
      await setProgress(id, 1, 5); // 10 words before + 5 = 15/30

      final map = await progressMap();
      expect(map[id], closeTo(0.5, 1e-9));
    });

    test('is 0.0 for a book with no progress row', () async {
      final id = await persist(_bookWithChapters('b', [10]));
      expect((await progressMap())[id], 0.0);
    });

    test('clamps to 1.0 when the cursor overshoots totalWords', () async {
      final id = await persist(_bookWithChapters('b', [10]));
      await setProgress(id, 0, 999);
      expect((await progressMap())[id], 1.0);
    });
  });

  group('categorizedLibraryProvider', () {
    test('splits by the 99% threshold', () async {
      final fresh = await persist(_bookWithChapters('fresh', [10]));
      final reading = await persist(_bookWithChapters('reading', [10, 10]));
      final done = await persist(_bookWithChapters('done', [10]));
      await setProgress(reading, 0, 5);
      await setProgress(done, 0, 10);

      final result = await categorized(LibraryKind.books);
      expect(result.notStarted.map((b) => b.id), [fresh]);
      expect(result.inProgress.map((b) => b.id), [reading]);
      expect(result.read.map((b) => b.id), [done]);
    });

    test('filters by source: books tab only sees EPUBs', () async {
      final epub = await persist(_bookWithChapters('epub', [10]));
      final article = await persist(
        _bookWithChapters('article', [10]),
        source: BookSource.article,
      );

      final books = await categorized(LibraryKind.books);
      final articles = await categorized(LibraryKind.articles);
      expect(books.notStarted.map((b) => b.id), [epub]);
      expect(articles.notStarted.map((b) => b.id), [article]);
    });
  });

  group('markBookAsReadProvider', () {
    test('bumps progress so the book lands in "read"', () async {
      final id = await persist(_bookWithChapters('b', [10, 10]));
      await setProgress(id, 0, 3);

      await container.read(markBookAsReadProvider(id))();

      final result = await categorized(LibraryKind.books);
      expect(result.read.map((b) => b.id), [id]);
      expect((await progressMap())[id], 1.0);
    });
  });

  group('deleteBookProvider', () {
    test('removes the book, tokens, and progress, and pushes a tombstone',
        () async {
      final id = await persist(_bookWithChapters('b', [10]));
      await setProgress(id, 0, 5);
      // Materialize the stub before deleting so the recorded call survives.
      container.read(librarySyncProvider.notifier);

      await container.read(deleteBookProvider(id))();

      expect(await db.booksDao.getBookById(id), isNull);
      expect(await db.readingProgressDao.getProgressForBook(id), isNull);
      expect(await db.cachedTokensDao.getTokensForChapter(id, 0), isNull);
      expect(syncStub.deletedBookIds, [id]);
    });
  });
}
