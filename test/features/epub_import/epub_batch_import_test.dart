import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/di/providers.dart';
import 'package:ledor/core/utils/platform_capabilities.dart';
import 'package:ledor/database/app_database.dart';
import 'package:ledor/features/epub_import/presentation/providers/epub_import_provider.dart';
import 'package:ledor/features/library_sync/presentation/providers/library_sync_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../fixtures/build_minimal_epub.dart';
import '../../fixtures/fake_path_provider.dart';

/// Counts pushes so the test can assert a batch schedules exactly one.
class _StubLibrarySyncNotifier extends LibrarySyncNotifier {
  _StubLibrarySyncNotifier(super.ref, this.pushes);
  final List<int> pushes;

  @override
  void schedulePush() => pushes.add(1);

  @override
  void markSettingsDirty() {}

  @override
  Future<void> triggerSync() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late List<int> pushes;
  late Future<List<PickedFile>?> Function() pickerImpl;

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          librarySyncProvider
              .overrideWith((ref) => _StubLibrarySyncNotifier(ref, pushes)),
          epubImportProvider.overrideWith(
            (ref) => EpubImportNotifier(ref, picker: () => pickerImpl()),
          ),
        ],
      );

  Future<PickedFile> writeEpub(String fileName, String title) async {
    final file = File('${tmp.path}/$fileName');
    await file.writeAsBytes(
      buildMinimalEpub(
        title: title,
        author: 'AIEP',
        chapters: [(title: 'One', body: 'Some words to read in $title.')],
      ),
    );
    return (path: file.path, displayName: fileName);
  }

  Future<PickedFile> writeGarbage(String fileName) async {
    final file = File('${tmp.path}/$fileName');
    await file.writeAsString('this is not an epub');
    return (path: file.path, displayName: fileName);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rsvp_batch_import_test_');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = AppDatabase(NativeDatabase.memory());
    pushes = [];
    pickerImpl = () async => null;
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('batch EPUB import', () {
    test('imports every picked file and stays in the library', () async {
      final a = await writeEpub('a.epub', 'Book A');
      final b = await writeEpub('b.epub', 'Book B');
      final c = await writeEpub('c.epub', 'Book C');
      pickerImpl = () async => [a, b, c];
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(epubImportProvider.notifier).importFromFilePicker();

      final state = container.read(epubImportProvider);
      expect(state.status, ImportStatus.done);
      expect(state.importedCount, 3);
      expect(state.failedCount, 0);
      expect(
        state.importedBookId,
        isNull,
        reason: 'a batch has no single book to open',
      );
      final books = await db.booksDao.getAllBooks();
      expect(books.map((b) => b.title).toSet(), {'Book A', 'Book B', 'Book C'});
      expect(pushes, hasLength(1), reason: 'one sync push per batch');
    });

    test('two files with the same name get distinct sync filenames', () async {
      final first = await writeEpub('apunte.epub', 'Apunte 1');
      // Same display name, different content and on-disk path.
      final other = File('${tmp.path}/other.epub')
        ..writeAsBytesSync(
          buildMinimalEpub(
            title: 'Apunte 2',
            author: 'AIEP',
            chapters: [(title: 'One', body: 'Different words entirely.')],
          ),
        );
      pickerImpl = () async => [
            first,
            (path: other.path, displayName: 'apunte.epub'),
          ];
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(epubImportProvider.notifier).importFromFilePicker();

      final names = (await db.booksDao.getAllBooks())
          .map((b) => b.syncFileName)
          .toList();
      expect(names, unorderedEquals(['apunte.epub', 'apunte (2).epub']));
    });

    test('a broken file does not stop the rest and is counted as failed',
        () async {
      final a = await writeEpub('a.epub', 'Book A');
      final bad = await writeGarbage('bad.epub');
      final c = await writeEpub('c.epub', 'Book C');
      pickerImpl = () async => [a, bad, c];
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(epubImportProvider.notifier).importFromFilePicker();

      final state = container.read(epubImportProvider);
      expect(state.status, ImportStatus.done);
      expect(state.importedCount, 2);
      expect(state.failedCount, 1);
      expect(await db.booksDao.getAllBooks(), hasLength(2));
    });

    test('reports an error when nothing could be imported', () async {
      final bad = await writeGarbage('bad.epub');
      pickerImpl = () async => [bad];
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(epubImportProvider.notifier).importFromFilePicker();

      final state = container.read(epubImportProvider);
      expect(state.status, ImportStatus.error);
      expect(state.failedCount, 1);
      expect(state.filePickerUnavailable, isFalse);
      expect(pushes, isEmpty);
    });

    test('a single file still opens the reader (importedBookId set)',
        () async {
      final a = await writeEpub('a.epub', 'Book A');
      pickerImpl = () async => [a];
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(epubImportProvider.notifier).importFromFilePicker();

      final state = container.read(epubImportProvider);
      expect(state.status, ImportStatus.done);
      expect(state.importedBookId, isNotNull);
    });

    test('cancelling the dialog leaves the state idle', () async {
      pickerImpl = () async => null;
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(epubImportProvider.notifier).importFromFilePicker();

      expect(container.read(epubImportProvider).status, ImportStatus.idle);
      expect(await db.booksDao.getAllBooks(), isEmpty);
    });
  });

  group('file dialog failures', () {
    test('a picker failure is flagged as unavailable only on Linux', () async {
      pickerImpl = () async => throw Exception('no dialog backend');
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(epubImportProvider.notifier).importFromFilePicker();

      final state = container.read(epubImportProvider);
      expect(state.status, ImportStatus.error);
      expect(state.filePickerUnavailable, PlatformCapabilities.isLinux);
    });

    test('importFromPaths (drag-and-drop) imports every path in one batch',
        () async {
      final a = await writeEpub('a.epub', 'Book A');
      final b = await writeEpub('b.epub', 'Book B');
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(epubImportProvider.notifier);
      final statuses = <ImportStatus>[];
      container.listen(
        epubImportProvider,
        (_, next) => statuses.add(next.status),
      );

      await notifier.importFromPaths([a.path, b.path]);

      expect(statuses.first, ImportStatus.processing);
      final state = container.read(epubImportProvider);
      expect(state.status, ImportStatus.done);
      expect(state.importedCount, 2);
      expect(pushes, hasLength(1));
    });
  });
}
