import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../../epub_import/presentation/providers/epub_import_provider.dart';
import '../../../rsvp_reader/domain/entities/display_settings.dart';
import '../../../rsvp_reader/presentation/providers/display_settings_provider.dart';
import '../../data/gateways/drive_sync_folder_gateway.dart';
import '../../data/services/library_sync_service.dart';
import '../../domain/entities/sync_config.dart';
import '../../domain/repositories/sync_folder_gateway.dart';
import 'drive_auth_provider.dart';
import 'sync_config_provider.dart';

/// Single Drive-backed gateway. Takes a closure that returns a fresh
/// authenticated client each operation so token refresh is handled by
/// google_sign_in, not here.
final driveSyncFolderGatewayProvider =
    Provider<DriveSyncFolderGateway>((ref) {
  return DriveSyncFolderGateway(() async {
    return ref.read(driveAuthProvider.notifier).authenticatedClient();
  });
});

final syncFolderGatewayProvider = Provider<SyncFolderGateway>((ref) {
  return ref.watch(driveSyncFolderGatewayProvider);
});

final librarySyncServiceProvider = Provider<LibrarySyncService>((ref) {
  return LibrarySyncService(
    gateway: ref.watch(syncFolderGatewayProvider),
    booksDao: ref.watch(booksDaoProvider),
    progressDao: ref.watch(readingProgressDaoProvider),
    sessionDao: ref.watch(readingSessionDaoProvider),
    tokensDao: ref.watch(cachedTokensDaoProvider),
    failuresDao: ref.watch(syncImportFailuresDaoProvider),
    bookmarksDao: ref.watch(bookmarksDaoProvider),
    extractionService: ref.watch(epubExtractionServiceProvider),
  );
});

/// Live list of files whose last auto-import attempt failed. Used by the
/// sync settings section to let the user retry them.
final syncImportFailuresProvider =
    StreamProvider<List<SyncImportFailuresTableData>>((ref) {
  return ref.watch(syncImportFailuresDaoProvider).watchAll();
});

enum SyncStage { idle, syncing, error, done }

class LibrarySyncState {
  final SyncStage stage;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  /// When auto-importing books from the sync folder, these track progress
  /// so the UI can render "Importando X de Y: file.epub". Null outside of
  /// an active import.
  final int? importCurrent;
  final int? importTotal;
  final String? importFileName;

  const LibrarySyncState({
    this.stage = SyncStage.idle,
    this.errorMessage,
    this.lastSyncedAt,
    this.importCurrent,
    this.importTotal,
    this.importFileName,
  });

  bool get isImporting =>
      importTotal != null && importTotal! > 0 && importCurrent != importTotal;

  LibrarySyncState copyWith({
    SyncStage? stage,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastSyncedAt,
    int? importCurrent,
    int? importTotal,
    String? importFileName,
    bool clearImport = false,
  }) {
    return LibrarySyncState(
      stage: stage ?? this.stage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      importCurrent: clearImport ? null : (importCurrent ?? this.importCurrent),
      importTotal: clearImport ? null : (importTotal ?? this.importTotal),
      importFileName:
          clearImport ? null : (importFileName ?? this.importFileName),
    );
  }
}

class LibrarySyncNotifier extends StateNotifier<LibrarySyncState> {
  final Ref _ref;
  Timer? _debounce;
  bool _running = false;
  bool _queued = false;
  DateTime? _settingsUpdatedAt;
  final List<String> _pendingDeletes = [];

  LibrarySyncNotifier(this._ref) : super(const LibrarySyncState());

  /// Record that the local settings just changed. Used to stamp the settings
  /// snapshot during the next push.
  void markSettingsDirty() {
    _settingsUpdatedAt = DateTime.now().toUtc();
  }

  /// Schedule a sync ~2s from now, coalescing multiple rapid calls.
  void schedulePush() {
    final config = _ref.read(syncConfigProvider);
    if (!config.isActive) return;
    if (!_ref.read(driveAuthProvider).isSignedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      triggerSync();
    });
  }

  /// Run a sync now. Safe to call multiple times: concurrent calls are
  /// coalesced into one queued re-run after the current one finishes.
  Future<void> triggerSync() async {
    final config = _ref.read(syncConfigProvider);
    if (!config.isConfigured) return;
    if (!_ref.read(driveAuthProvider).isSignedIn) return;

    if (_running) {
      _queued = true;
      return;
    }
    _running = true;
    _debounce?.cancel();
    state = state.copyWith(stage: SyncStage.syncing, clearError: true);

    final service = _ref.read(librarySyncServiceProvider);
    try {
      await _flushPendingDeletes(service, config);
      final completedAt = await service.sync(
        config: config,
        readSettings: () => _ref.read(displaySettingsProvider),
        applySettings: (DisplaySettings synced) async {
          await _ref
              .read(displaySettingsProvider.notifier)
              .applyFromRemote(synced);
        },
        localSettingsUpdatedAt: _settingsUpdatedAt,
        onImportProgress: (current, total, fileName) {
          state = state.copyWith(
            importCurrent: current,
            importTotal: total,
            importFileName: fileName,
          );
        },
      );
      _settingsUpdatedAt = null;
      await _ref.read(syncConfigProvider.notifier).markSyncedAt(completedAt);
      state = LibrarySyncState(
        stage: SyncStage.done,
        lastSyncedAt: completedAt,
      );
    } catch (e) {
      state = state.copyWith(
        stage: SyncStage.error,
        errorMessage: e.toString(),
        clearImport: true,
      );
    } finally {
      _running = false;
      if (_queued) {
        _queued = false;
        scheduleMicrotask(triggerSync);
      }
    }
  }

  /// Remove a failure record so the next sync retries the file.
  Future<void> retryFailedImport(String fileName) async {
    await _ref.read(syncImportFailuresDaoProvider).clear(fileName);
    await triggerSync();
  }

  /// Push a delete tombstone for [bookId]. If a full sync is currently in
  /// flight, the delete is queued and flushed at the start of the next sync
  /// so it never races the manifest read/write the sync is doing.
  Future<void> pushDelete(String bookId) async {
    final config = _ref.read(syncConfigProvider);
    if (!config.isActive) return;
    if (!_ref.read(driveAuthProvider).isSignedIn) return;

    if (_running) {
      _pendingDeletes.add(bookId);
      _queued = true;
      return;
    }

    _pendingDeletes.add(bookId);
    await triggerSync();
  }

  Future<void> _flushPendingDeletes(
      LibrarySyncService service, SyncConfig config) async {
    if (_pendingDeletes.isEmpty) return;
    final ids = List<String>.from(_pendingDeletes);
    _pendingDeletes.clear();
    for (final id in ids) {
      try {
        await service.pushTombstone(
          config: config,
          bookId: id,
          deletedAt: DateTime.now().toUtc(),
        );
      } catch (_) {/* will be retried on next full sync */}
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final librarySyncProvider =
    StateNotifierProvider<LibrarySyncNotifier, LibrarySyncState>((ref) {
  return LibrarySyncNotifier(ref);
});
