import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/di/providers.dart';
import 'package:ledor/core/utils/token_codec.dart';
import 'package:ledor/database/app_database.dart';
import 'package:ledor/database/tables/book_source.dart';
import 'package:ledor/features/epub_import/presentation/providers/epub_import_provider.dart';
import 'package:ledor/features/library_sync/presentation/providers/library_sync_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../fixtures/build_minimal_epub.dart';

/// Fake PathProviderPlatform that hands every call back the same temp
/// directory. The import flow calls [getApplicationDocumentsDirectory]
/// to decide where the EPUB ends up; routing it to a tearDown-cleaned
/// temp dir keeps the test sandboxed.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.docs);
  final Directory docs;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs.path;

  @override
  Future<String?> getTemporaryPath() async => docs.path;
}

/// Stubs out the Drive sync hand-off so import → schedulePush() does
/// not drag the auth / config providers in.
class _StubLibrarySyncNotifier extends LibrarySyncNotifier {
  _StubLibrarySyncNotifier(super.ref);

  @override
  void schedulePush() {}

  @override
  void markSettingsDirty() {}

  @override
  Future<void> triggerSync() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rsvp_import_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmp);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    db = AppDatabase(NativeDatabase.memory());

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        librarySyncProvider
            .overrideWith((ref) => _StubLibrarySyncNotifier(ref)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  group('EPUB import pipeline', () {
    test(
      'imports a fixture EPUB into books + cached_tokens + filesystem',
      () async {
        final bytes = buildMinimalEpub(
          title: 'Test Book',
          author: 'Test Author',
          chapters: [
            (
              title: 'Chapter One',
              body: 'The quick brown fox jumps over the lazy dog.',
            ),
            (
              title: 'Chapter Two',
              body:
                  'Lorem ipsum dolor sit amet consectetur adipiscing elit sed do.',
            ),
          ],
        );
        final source = File('${tmp.path}/source.epub');
        await source.writeAsBytes(bytes);

        final notifier = container.read(epubImportProvider.notifier);
        await notifier.importFromPath(source.path);

        final state = container.read(epubImportProvider);
        expect(state.status, ImportStatus.done);
        expect(state.importedBookId, isNotNull);

        // 1. Books table has the row with the metadata from the OPF.
        final book = await db.booksDao.getBookById(state.importedBookId!);
        expect(book, isNotNull);
        expect(book!.title, 'Test Book');
        expect(book.author, 'Test Author');
        expect(book.source, BookSource.epub);
        expect(book.totalWords, greaterThan(0));
        expect(book.chapterCount, 2);

        // 2. CachedTokens table has one row per chapter, summing to the
        //    book's total word count.
        final tokenRows =
            await db.cachedTokensDao.getTokensForBook(book.id);
        expect(tokenRows, hasLength(2));
        final wordSum =
            tokenRows.fold<int>(0, (acc, r) => acc + r.wordCount);
        expect(wordSum, book.totalWords);
        expect(
          tokenRows.map((r) => r.chapterIndex).toList(),
          [0, 1],
        );

        // 3. File copied to <appDocs>/books/<uuid>.epub.
        final savedFile = File('${tmp.path}/books/${book.id}.epub');
        expect(savedFile.existsSync(), isTrue);
        expect(
          await savedFile.readAsBytes(),
          bytes,
          reason: 'Saved file should be a byte-perfect copy of the input',
        );
        expect(book.filePath, savedFile.path);

        // 4. No reading-progress row is created at import time — the
        //    engine treats absence as "not started" and a row here would
        //    push the book into the "In progress" library section.
        final progress =
            await db.readingProgressDao.getProgressForBook(book.id);
        expect(progress, isNull);
      },
    );

    test('rejects a non-EPUB file with ImportStatus.error', () async {
      // Plain text — not a ZIP, EpubReader should throw on parse.
      final junk = File('${tmp.path}/not-an-epub.txt');
      await junk.writeAsString('definitely not an epub archive');

      final notifier = container.read(epubImportProvider.notifier);
      await notifier.importFromPath(junk.path);

      final state = container.read(epubImportProvider);
      expect(state.status, ImportStatus.error);

      // Nothing should have been persisted.
      final all = await db.booksDao.getAllBooks();
      expect(all, isEmpty);
    });

    test(
      'preserves the user-facing filename in books.syncFileName',
      () async {
        final bytes = buildMinimalEpub(
          title: 'Named Book',
          author: 'Author',
          chapters: [(title: 'Only', body: 'one two three four five.')],
        );
        final source = File('${tmp.path}/My Awesome Book.epub');
        await source.writeAsBytes(bytes);

        final notifier = container.read(epubImportProvider.notifier);
        await notifier.importFromPath(source.path);

        final state = container.read(epubImportProvider);
        expect(state.status, ImportStatus.done);

        final book = await db.booksDao.getBookById(state.importedBookId!);
        expect(book!.syncFileName, 'My Awesome Book.epub');
      },
    );
  });

  group('persistParsedBook integration via importer', () {
    test('tokensJson roundtrip recovers the same chapter shape', () async {
      final bytes = buildMinimalEpub(
        title: 'Roundtrip',
        author: 'Author',
        chapters: [
          (title: 'A', body: 'one two three.'),
          (title: 'B', body: 'four five six.'),
        ],
      );
      final source = File('${tmp.path}/rt.epub');
      await source.writeAsBytes(bytes);

      await container.read(epubImportProvider.notifier).importFromPath(
            source.path,
          );
      final bookId =
          container.read(epubImportProvider).importedBookId!;

      final ch0 =
          await db.cachedTokensDao.getTokensForChapter(bookId, 0);
      final ch1 =
          await db.cachedTokensDao.getTokensForChapter(bookId, 1);
      expect(ch0, isNotNull);
      expect(ch1, isNotNull);
      expect(ch0!.chapterTitle, 'A');
      expect(ch1!.chapterTitle, 'B');
      // tokensJson é gravado no formato compacto v2 e decodifica de volta
      // pros mesmos tokens (texto + posições estruturais).
      expect(TokenCodec.isCompact(ch0.tokensJson), isTrue);
      final tokens0 = TokenCodec.decode(ch0.tokensJson, chapterIndex: 0);
      // O fixture renderiza o título do capítulo como <h1> no body, então
      // ele aparece como primeiro token.
      expect(tokens0.map((t) => t.text), ['A', 'one', 'two', 'three.']);
      expect(tokens0.first.isChapterStart, isTrue);
      expect(ch0.wordCount, greaterThan(0));
    });

    test(
      'separate imports get independent book ids and rows',
      () async {
        final src1 = File('${tmp.path}/a.epub')
          ..writeAsBytesSync(buildMinimalEpub(
            title: 'A',
            author: 'X',
            chapters: [(title: 'c', body: 'a b c d e f g.')],
          ));
        final src2 = File('${tmp.path}/b.epub')
          ..writeAsBytesSync(buildMinimalEpub(
            title: 'B',
            author: 'Y',
            chapters: [(title: 'c', body: 'h i j k l m n.')],
          ));

        final notifier = container.read(epubImportProvider.notifier);
        await notifier.importFromPath(src1.path);
        final firstId =
            container.read(epubImportProvider).importedBookId!;
        // Move the notifier back to idle so the second import isn't a
        // dedupe pass on top of the first one's state.
        notifier.reset();
        await notifier.importFromPath(src2.path);
        final secondId =
            container.read(epubImportProvider).importedBookId!;

        expect(firstId, isNot(equals(secondId)));
        final books = await db.booksDao.getAllBooks();
        expect(books, hasLength(2));
        expect(
          books.map((b) => b.title).toSet(),
          {'A', 'B'},
        );
      },
    );
  });
}

