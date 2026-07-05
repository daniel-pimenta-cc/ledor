import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/di/providers.dart';
import 'package:ledor/database/app_database.dart';
import 'package:ledor/features/library_sync/presentation/providers/library_sync_provider.dart';
import 'package:ledor/features/rsvp_reader/presentation/providers/bookmarks_provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _StubLibrarySyncNotifier extends LibrarySyncNotifier {
  _StubLibrarySyncNotifier(super.ref);

  int pushCount = 0;

  @override
  void schedulePush() => pushCount++;

  @override
  void markSettingsDirty() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late _StubLibrarySyncNotifier syncStub;

  setUp(() {
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
    container.read(librarySyncProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  BookmarksController controller([String bookId = 'book1']) {
    // keepAlive via listen so the autoDispose family doesn't tear down
    // between the calls of a single test.
    container.listen(bookmarksControllerProvider(bookId), (previous, next) {});
    return container.read(bookmarksControllerProvider(bookId));
  }

  test('create persists the bookmark and schedules a sync push', () async {
    final created = await controller().create(
      globalWordIndex: 42,
      chapterIndex: 1,
      label: '  minha marca  ',
      contextSnippet: 'um trecho',
    );

    expect(created.label, 'minha marca'); // trimmed
    final rows = await db.bookmarksDao.watchForBook('book1').first;
    expect(rows, hasLength(1));
    expect(rows.single.globalWordIndex, 42);
    expect(rows.single.label, 'minha marca');
    expect(syncStub.pushCount, 1);
  });

  test('whitespace-only label is stored as null', () async {
    final created = await controller().create(
      globalWordIndex: 1,
      chapterIndex: 0,
      label: '   ',
    );
    expect(created.label, isNull);
  });

  test('updateLabel with empty input clears the label', () async {
    final created = await controller().create(
      globalWordIndex: 1,
      chapterIndex: 0,
      label: 'original',
    );

    await controller().updateLabel(created.id, '');

    final rows = await db.bookmarksDao.watchForBook('book1').first;
    expect(rows.single.label, isNull);
  });

  test('delete soft-deletes: hidden from watch, kept as tombstone for sync',
      () async {
    final created = await controller().create(
      globalWordIndex: 1,
      chapterIndex: 0,
    );

    await controller().delete(created.id);

    expect(await db.bookmarksDao.watchForBook('book1').first, isEmpty);
    final all = await db.bookmarksDao.getAllIncludingTombstones();
    expect(all, hasLength(1));
    expect(all.single.deletedAt, isNotNull);
  });
}
