import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as ga;
import 'package:ledor/core/di/providers.dart';
import 'package:ledor/database/app_database.dart';
import 'package:ledor/features/library_sync/data/auth/drive_auth_backend.dart';
import 'package:ledor/features/library_sync/data/services/library_sync_service.dart';
import 'package:ledor/features/library_sync/domain/entities/sync_config.dart';
import 'package:ledor/features/library_sync/domain/entities/sync_library.dart';
import 'package:ledor/features/library_sync/presentation/providers/drive_auth_provider.dart';
import 'package:ledor/features/library_sync/presentation/providers/library_sync_provider.dart';
import 'package:ledor/features/library_sync/presentation/providers/sync_config_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../fixtures/fake_path_provider.dart';
import '../../fixtures/fake_sync_folder_gateway.dart';

const _kBooksShard = 'library/books.json';
const _kPendingDeletesKey = 'sync_pendingDeletes';

/// Signed-in (or signed-out, with null email) auth backend stub.
class _FakeAuthBackend extends DriveAuthBackend {
  final String? email;
  _FakeAuthBackend(this.email) : super(clientId: '', clientSecret: '');

  @override
  Future<String?> trySilentSignIn() async => email;

  @override
  Future<String?> signIn() => trySilentSignIn();

  @override
  Future<void> signOut() async {}

  @override
  Future<ga.AuthClient?> authenticatedClient() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late FakeSyncFolderGateway gateway;
  late ProviderContainer container;

  Future<ProviderContainer> buildContainer({required bool signedIn}) async {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncFolderGatewayProvider.overrideWithValue(gateway),
        driveAuthBackendProvider
            .overrideWithValue(_FakeAuthBackend(signedIn ? 'u@test' : null)),
      ],
    );
    // SyncConfigNotifier.load() runs async in its constructor; re-running
    // it here lets us await the configured state deterministically.
    await c.read(syncConfigProvider.notifier).load();
    if (signedIn) {
      await c.read(driveAuthProvider.notifier).trySilentSignIn();
    }
    return c;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rsvp_pending_deletes_');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // Mark sync as configured so pushDelete/triggerSync don't bail early.
    await SharedPreferencesAsync()
        .setString('sync_driveFolderId', 'folder-1');
    db = AppDatabase(NativeDatabase.memory());
    gateway = FakeSyncFolderGateway();
    container = await buildContainer(signedIn: true);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  SyncBooksShard decodeBooksShard() =>
      SyncBooksShard.decode(gateway.textFiles[_kBooksShard]!);

  Future<String?> readPendingPref() =>
      SharedPreferencesAsync().getString(_kPendingDeletesKey);

  group('LibrarySyncService.pushTombstone', () {
    LibrarySyncService service() =>
        container.read(librarySyncServiceProvider);
    SyncConfig config() => container.read(syncConfigProvider);

    test('returns false and writes nothing when folder is unreadable',
        () async {
      gateway.readable = false;

      final pushed = await service().pushTombstone(
        config: config(),
        bookId: 'book-1',
        deletedAt: DateTime.utc(2026, 6, 1),
      );

      expect(pushed, isFalse);
      expect(gateway.textFiles, isEmpty);
    });

    test('tombstones an active remote entry, keeps the rest, returns true',
        () async {
      final now = DateTime.utc(2026, 6, 1);
      gateway.textFiles[_kBooksShard] = SyncBooksShard(
        updatedAt: now,
        updatedBy: 'other-device',
        books: [
          SyncLibraryBook(
            id: 'book-1',
            title: 'Doomed',
            totalWords: 10,
            chapterCount: 1,
            importedAt: now,
            hasEpubFile: false,
            updatedAt: now,
          ),
          SyncLibraryBook(
            id: 'book-2',
            title: 'Survivor',
            totalWords: 10,
            chapterCount: 1,
            importedAt: now,
            hasEpubFile: false,
            updatedAt: now,
          ),
        ],
      ).encode();

      final deletedAt = DateTime.utc(2026, 6, 2);
      final pushed = await service().pushTombstone(
        config: config(),
        bookId: 'book-1',
        deletedAt: deletedAt,
      );

      expect(pushed, isTrue);
      final shard = decodeBooksShard();
      final doomed = shard.books.singleWhere((b) => b.id == 'book-1');
      expect(doomed.deletedAt, isNotNull);
      expect(doomed.deletedAt!.isAtSameMomentAs(deletedAt), isTrue);
      final survivor = shard.books.singleWhere((b) => b.id == 'book-2');
      expect(survivor.deletedAt, isNull);
    });
  });

  group('pending delete queue', () {
    test('failed tombstone push keeps the delete queued and fails the sync',
        () async {
      gateway.readable = false;

      final notifier = container.read(librarySyncProvider.notifier);
      await notifier.pushDelete('book-1');

      // Sync must fail: proceeding without the tombstone would resurrect
      // the deleted book from the still-active remote entry.
      expect(container.read(librarySyncProvider).stage, SyncStage.error);
      expect(gateway.textFiles, isEmpty);
      // The delete survives in the persisted queue.
      expect(await readPendingPref(), contains('book-1'));
    });

    test('retry after the folder is reachable pushes the tombstone and '
        'clears the queue', () async {
      gateway.readable = false;
      final notifier = container.read(librarySyncProvider.notifier);
      await notifier.pushDelete('book-1');
      expect(container.read(librarySyncProvider).stage, SyncStage.error);

      gateway.readable = true;
      await notifier.triggerSync();

      expect(container.read(librarySyncProvider).stage, SyncStage.done);
      final tombstone =
          decodeBooksShard().books.singleWhere((b) => b.id == 'book-1');
      expect(tombstone.deletedAt, isNotNull);
      expect(await readPendingPref(), isNull);
    });

    test('queued delete survives an app restart', () async {
      // Signed out: pushDelete only queues + persists, no sync attempt.
      final coldContainer = await buildContainer(signedIn: false);
      await coldContainer
          .read(librarySyncProvider.notifier)
          .pushDelete('book-1');
      expect(await readPendingPref(), contains('book-1'));
      coldContainer.dispose();

      // "Restart": a fresh container (new notifier, same prefs store).
      final warmContainer = await buildContainer(signedIn: true);
      addTearDown(warmContainer.dispose);
      await warmContainer.read(librarySyncProvider.notifier).triggerSync();

      expect(
        warmContainer.read(librarySyncProvider).stage,
        SyncStage.done,
      );
      final tombstone =
          decodeBooksShard().books.singleWhere((b) => b.id == 'book-1');
      expect(tombstone.deletedAt, isNotNull);
      expect(await readPendingPref(), isNull);
    });

    test('deletedAt is captured at delete time, not at flush time',
        () async {
      gateway.readable = false;
      final notifier = container.read(librarySyncProvider.notifier);

      final before = DateTime.now().toUtc();
      await notifier.pushDelete('book-1');
      final after = DateTime.now().toUtc();

      // The queued entry carries the original timestamp...
      final queued = (jsonDecode((await readPendingPref())!) as List).single
          as Map<String, dynamic>;
      final queuedAt = DateTime.parse(queued['deletedAt'] as String);
      expect(queuedAt.isBefore(before), isFalse);
      expect(queuedAt.isAfter(after), isFalse);

      // ...and the tombstone pushed later reuses it instead of restamping,
      // so LWW against a peer's later edit still resolves correctly.
      gateway.readable = true;
      await notifier.triggerSync();
      final tombstone =
          decodeBooksShard().books.singleWhere((b) => b.id == 'book-1');
      expect(tombstone.deletedAt!.isAtSameMomentAs(queuedAt), isTrue);
    });

    test('re-deleting the same book replaces the queued entry', () async {
      gateway.readable = false;
      final notifier = container.read(librarySyncProvider.notifier);
      await notifier.pushDelete('book-1');
      await notifier.pushDelete('book-1');

      final queued = jsonDecode((await readPendingPref())!) as List;
      expect(queued, hasLength(1));
    });

    // Disconnect escape hatch: queued deletes belong to the account they
    // were created against. Without the clear, a delete that failed to
    // push would be replayed against the NEXT connected account, writing
    // a phantom tombstone into that folder's shard.
    test('clearPendingDeletes drops the queue so a later sync pushes '
        'nothing', () async {
      gateway.readable = false;
      final notifier = container.read(librarySyncProvider.notifier);
      await notifier.pushDelete('book-1');
      expect(await readPendingPref(), contains('book-1'));

      await notifier.clearPendingDeletes();
      expect(await readPendingPref(), isNull);

      gateway.readable = true;
      await notifier.triggerSync();
      expect(container.read(librarySyncProvider).stage, SyncStage.done);
      final shard = gateway.textFiles[_kBooksShard];
      expect(shard == null || !shard.contains('book-1'), isTrue,
          reason: 'no phantom tombstone for the cleared delete');
    });
  });
}
