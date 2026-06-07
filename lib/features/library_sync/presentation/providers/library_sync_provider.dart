import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// SharedPreferences key holding the queued delete tombstones (JSON list).
/// Kept under the same `sync_` prefix as the SyncConfig keys.
const _kPendingDeletes = 'sync_pendingDeletes';

/// A book deletion waiting to be propagated to the sync folder as a
/// tombstone. Books are hard-deleted locally, so this queue is the only
/// record that the delete happened — it is persisted to SharedPreferences
/// and entries are only removed after the remote write succeeds. Without
/// that, a delete during a network blip would be silently dropped and the
/// book resurrected by the next full sync.
class PendingDelete {
  final String bookId;
  final DateTime deletedAt;

  const PendingDelete({required this.bookId, required this.deletedAt});

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'deletedAt': deletedAt.toIso8601String(),
      };

  static PendingDelete? fromJson(Map<String, dynamic> json) {
    final id = json['bookId'];
    final at = DateTime.tryParse(json['deletedAt'] as String? ?? '');
    if (id is! String || id.isEmpty || at == null) return null;
    return PendingDelete(bookId: id, deletedAt: at.toUtc());
  }
}

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
  final SharedPreferencesAsync _prefs;
  Timer? _debounce;
  bool _running = false;
  bool _queued = false;
  DateTime? _settingsUpdatedAt;
  final List<PendingDelete> _pendingDeletes = [];
  Future<void>? _pendingDeletesLoad;
  bool _pendingDeletesLoadedOk = false;

  LibrarySyncNotifier(this._ref, {SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync(),
        super(const LibrarySyncState());

  /// Restore queued deletes from disk, once, before first use. Never
  /// throws: a delete must never fail to enqueue because prefs hiccuped.
  Future<void> _ensurePendingDeletesLoaded() {
    return _pendingDeletesLoad ??= () async {
      final String? raw;
      try {
        raw = await _prefs.getString(_kPendingDeletes);
      } catch (_) {
        // Transient platform failure: forget the memoized future so the
        // next call retries instead of replaying the rejection forever.
        // Disk writes stay suppressed (see _savePendingDeletes) — a blind
        // write could clobber deletes queued by a previous session.
        _pendingDeletesLoad = null;
        return;
      }
      _pendingDeletesLoadedOk = true;
      if (raw == null || raw.isEmpty) return;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return;
        for (final entry in decoded) {
          if (entry is! Map<String, dynamic>) continue;
          final pending = PendingDelete.fromJson(entry);
          if (pending != null &&
              !_pendingDeletes.any((p) => p.bookId == pending.bookId)) {
            _pendingDeletes.add(pending);
          }
        }
      } on FormatException {
        // Corrupt blob — drop it rather than wedge every future sync.
        try {
          await _prefs.remove(_kPendingDeletes);
        } catch (_) {/* best effort */}
      }
    }();
  }

  /// Persist the queue. Best-effort by design: the in-memory queue keeps
  /// driving this session's flushes even when the write fails, and the
  /// next save retries. Skipped entirely until a load has succeeded — we
  /// don't know what a previous session queued, and overwriting it would
  /// drop tombstones (a later successful load merges disk entries back in
  /// by bookId, so suppressed writes lose nothing).
  Future<void> _savePendingDeletes() async {
    if (!_pendingDeletesLoadedOk) return;
    try {
      if (_pendingDeletes.isEmpty) {
        await _prefs.remove(_kPendingDeletes);
      } else {
        await _prefs.setString(
          _kPendingDeletes,
          jsonEncode([for (final p in _pendingDeletes) p.toJson()]),
        );
      }
    } catch (_) {/* best effort — queue stays in memory */}
  }

  /// Drop the queued delete tombstones, memory and disk. Called on
  /// disconnect: queued deletes belong to the account/folder they were
  /// created against, and replaying them after connecting a different
  /// account would write phantom tombstones into the new folder's shard.
  Future<void> clearPendingDeletes() async {
    _pendingDeletes.clear();
    // Mark the disk state as known-empty so neither a pending load nor a
    // future one resurrects the cleared entries.
    _pendingDeletesLoad = Future<void>.value();
    _pendingDeletesLoadedOk = true;
    try {
      await _prefs.remove(_kPendingDeletes);
    } catch (_) {/* best effort */}
  }

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

  /// Queue a delete tombstone for [bookId] and push it on the next sync.
  /// The queue is persisted before any network I/O, so the tombstone
  /// survives restarts, sign-outs and network failures; entries are only
  /// removed after the remote write succeeds. If a full sync is currently
  /// in flight the push is deferred to the queued re-run so it never races
  /// the shard read/write the sync is doing.
  Future<void> pushDelete(String bookId) async {
    final config = _ref.read(syncConfigProvider);
    if (!config.isConfigured) return;

    await _ensurePendingDeletesLoaded();
    _pendingDeletes.removeWhere((p) => p.bookId == bookId);
    _pendingDeletes.add(
      PendingDelete(bookId: bookId, deletedAt: DateTime.now().toUtc()),
    );
    await _savePendingDeletes();

    if (!config.isActive) return;
    if (!_ref.read(driveAuthProvider).isSignedIn) return;

    if (_running) {
      _queued = true;
      return;
    }
    await triggerSync();
  }

  /// Push every queued delete tombstone, keeping failures in the queue.
  /// Anything still pending afterwards aborts the sync: running the full
  /// pull/merge/push without the tombstone would re-import the deleted
  /// book from the still-active remote entry.
  Future<void> _flushPendingDeletes(
      LibrarySyncService service, SyncConfig config) async {
    await _ensurePendingDeletesLoaded();
    if (_pendingDeletes.isEmpty) return;

    Object? failure;
    for (final pending in List<PendingDelete>.from(_pendingDeletes)) {
      var pushed = false;
      try {
        pushed = await service.pushTombstone(
          config: config,
          bookId: pending.bookId,
          deletedAt: pending.deletedAt,
        );
      } catch (e) {
        failure = e;
      }
      if (pushed) {
        _pendingDeletes.removeWhere((p) => p.bookId == pending.bookId);
      }
    }
    await _savePendingDeletes();

    if (_pendingDeletes.isNotEmpty) {
      throw failure ??
          StateError(
            'Could not push ${_pendingDeletes.length} pending delete '
            'tombstone(s); sync aborted so the deleted book is not '
            'resurrected.',
          );
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
