import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../database/app_database.dart';
import '../../../../database/daos/bookmarks_dao.dart';
import '../../../../database/daos/books_dao.dart';
import '../../../../database/daos/cached_tokens_dao.dart';
import '../../../../database/daos/reading_progress_dao.dart';
import '../../../../database/daos/reading_session_dao.dart';
import '../../../../database/daos/sync_import_failures_dao.dart';
import '../../../../database/tables/book_source.dart';
import '../../../book_library/data/services/book_persistence.dart';
import '../../../book_library/data/services/inline_image_storage.dart';
import '../../../epub_import/data/services/epub_extraction_service.dart';
import '../../../rsvp_reader/domain/entities/display_settings.dart';
import '../../domain/entities/sync_config.dart';
import '../../domain/entities/sync_library.dart';
import '../../domain/repositories/sync_folder_gateway.dart';

// Legacy monolithic manifest. Read once on first sync after upgrade so its
// contents can be migrated into the sharded layout; deleted right after.
const _kLegacyLibraryFile = 'library.json';

// New sharded layout under `library/` keeps each concern in its own file so a
// progress write doesn't drag settings/sessions over the wire and vice-versa.
const _kBooksShardFile = 'library/books.json';
const _kSettingsShardFile = 'library/settings.json';
const _kSessionsShardFile = 'library/sessions.json';
const _kBookmarksShardFile = 'library/bookmarks.json';

const _kBooksDir = 'books';

/// Pure functions that describe what the settings snapshot looks like on
/// disk. Kept as a map to stay forward-compatible with new DisplaySettings
/// fields without changing the sync schema every time.
Map<String, dynamic> displaySettingsToMap(DisplaySettings s) => {
      'wpm': s.wpm,
      'fontSize': s.fontSize,
      'contextFontSize': s.contextFontSize,
      'wordColorValue': s.wordColorValue,
      'orpColorValue': s.orpColorValue,
      'backgroundColorValue': s.backgroundColorValue,
      'highlightColorValue': s.highlightColorValue,
      'verticalPosition': s.verticalPosition,
      'horizontalPosition': s.horizontalPosition,
      'fontFamily': s.fontFamily,
      'showOrpHighlight': s.showOrpHighlight,
      'smartTiming': s.smartTiming,
      'rampUp': s.rampUp,
      'showFocusLine': s.showFocusLine,
      'focusLineShowsProgress': s.focusLineShowsProgress,
      'orpIndicator': s.orpIndicator.name,
      'showProgressSlider': s.showProgressSlider,
      'timeRemainingMode': s.timeRemainingMode.name,
      'sentencePauseMultiplier': s.sentencePauseMultiplier,
      'chapterPauseMultiplier': s.chapterPauseMultiplier,
      'ttsLanguage': s.ttsLanguage,
      // ttsVoiceName / ttsEngineId are intentionally written even when null
      // so the remote shard reflects "clear voice / use default engine".
      // The local backend falls back gracefully when the synced value
      // doesn't exist on this device (different Android engine list, etc.).
      'ttsVoiceName': s.ttsVoiceName,
      'ttsPitch': s.ttsPitch,
      'ttsRate': s.ttsRate,
      'ttsEngineId': s.ttsEngineId,
    };

DisplaySettings displaySettingsFromMap(Map<String, dynamic> m) {
  final defaults = const DisplaySettings();
  return defaults.copyWith(
    wpm: (m['wpm'] as num?)?.toInt(),
    fontSize: (m['fontSize'] as num?)?.toDouble(),
    contextFontSize: (m['contextFontSize'] as num?)?.toDouble(),
    wordColorValue: (m['wordColorValue'] as num?)?.toInt(),
    orpColorValue: (m['orpColorValue'] as num?)?.toInt(),
    backgroundColorValue: (m['backgroundColorValue'] as num?)?.toInt(),
    highlightColorValue: (m['highlightColorValue'] as num?)?.toInt(),
    verticalPosition: (m['verticalPosition'] as num?)?.toDouble(),
    horizontalPosition: (m['horizontalPosition'] as num?)?.toDouble(),
    fontFamily: m['fontFamily'] as String?,
    showOrpHighlight: m['showOrpHighlight'] as bool?,
    smartTiming: m['smartTiming'] as bool?,
    rampUp: m['rampUp'] as bool?,
    showFocusLine: m['showFocusLine'] as bool?,
    focusLineShowsProgress: m['focusLineShowsProgress'] as bool?,
    orpIndicator: _orpIndicatorFromName(m['orpIndicator'] as String?),
    showProgressSlider: m['showProgressSlider'] as bool?,
    timeRemainingMode:
        _timeRemainingModeFromName(m['timeRemainingMode'] as String?),
    sentencePauseMultiplier:
        (m['sentencePauseMultiplier'] as num?)?.toDouble(),
    chapterPauseMultiplier: (m['chapterPauseMultiplier'] as num?)?.toDouble(),
    ttsLanguage: m['ttsLanguage'] as String?,
    ttsVoiceName: m.containsKey('ttsVoiceName') ? m['ttsVoiceName'] as String? : defaults.ttsVoiceName,
    ttsPitch: (m['ttsPitch'] as num?)?.toDouble(),
    ttsRate: (m['ttsRate'] as num?)?.toDouble(),
    ttsEngineId: m.containsKey('ttsEngineId')
        ? m['ttsEngineId'] as String?
        : defaults.ttsEngineId,
  );
}

OrpIndicatorStyle? _orpIndicatorFromName(String? raw) {
  if (raw == null) return null;
  for (final s in OrpIndicatorStyle.values) {
    if (s.name == raw) return s;
  }
  return null;
}

TimeRemainingMode? _timeRemainingModeFromName(String? raw) {
  if (raw == null) return null;
  for (final m in TimeRemainingMode.values) {
    if (m.name == raw) return m;
  }
  return null;
}

/// Called after pull to apply the synced DisplaySettings (the provider layer
/// writes the fields back to SharedPreferences by re-saving through the
/// notifier).
typedef ApplySettingsCallback = Future<void> Function(DisplaySettings);

/// Called to produce the current local DisplaySettings snapshot for push.
typedef ReadSettingsCallback = DisplaySettings Function();

/// Reports bulk-import progress. [current] is 0-based and incremented after
/// each file attempt; [total] is the number of files the service is about to
/// process (set on the initial call with current=0). [fileName] is the file
/// just attempted, or empty at the initial call.
typedef ImportProgressCallback = void Function(
    int current, int total, String fileName);

/// Orchestrates pull + push against the user-chosen folder.
///
/// Push/pull are not re-entrant: callers (typically [LibrarySyncNotifier])
/// serialize access with a mutex/flag.
class LibrarySyncService {
  final SyncFolderGateway _gateway;
  final BooksDao _booksDao;
  final ReadingProgressDao _progressDao;
  final ReadingSessionDao _sessionDao;
  final CachedTokensDao _tokensDao;
  final SyncImportFailuresDao _failuresDao;
  final BookmarksDao _bookmarksDao;
  final EpubExtractionService _extractionService;

  LibrarySyncService({
    required SyncFolderGateway gateway,
    required BooksDao booksDao,
    required ReadingProgressDao progressDao,
    required ReadingSessionDao sessionDao,
    required CachedTokensDao tokensDao,
    required SyncImportFailuresDao failuresDao,
    required BookmarksDao bookmarksDao,
    required EpubExtractionService extractionService,
  })  : _gateway = gateway,
        _booksDao = booksDao,
        _progressDao = progressDao,
        _sessionDao = sessionDao,
        _tokensDao = tokensDao,
        _failuresDao = failuresDao,
        _bookmarksDao = bookmarksDao,
        _extractionService = extractionService;

  /// Pull remote → merge with local → push merged back.
  ///
  /// Returns the time at which the sync completed on success. Throws on I/O
  /// errors — callers should catch and surface via [SyncResult.fail].
  Future<DateTime> sync({
    required SyncConfig config,
    required ReadSettingsCallback readSettings,
    required ApplySettingsCallback applySettings,
    DateTime? localSettingsUpdatedAt,
    ImportProgressCallback? onImportProgress,
  }) async {
    final folder = config.driveFolderId!;

    // 1. Fire off every independent Drive read in parallel. Each await
    // afterwards is for the one we need next; wall-clock cost is whichever
    // of these finishes last.
    final isReadableF = _gateway.isReadable(folder);
    final legacyManifestF = _gateway.readText(folder, _kLegacyLibraryFile);
    final booksShardF = _gateway.readText(folder, _kBooksShardFile);
    final settingsShardF = _gateway.readText(folder, _kSettingsShardFile);
    final sessionsShardF = _gateway.readText(folder, _kSessionsShardFile);
    final bookmarksShardF = _gateway.readText(folder, _kBookmarksShardFile);
    final listBooksF = config.syncEpubs
        ? _gateway.listFiles(folder, _kBooksDir).catchError(
              (_) => <String>[],
            )
        : Future<List<String>>.value(const []);

    if (!await isReadableF) {
      throw StateError('Sync folder is not readable: $folder');
    }

    // 2. Decode remote shards. If the new shards are absent we look for a
    // legacy `library.json` and migrate its contents into shard memory; the
    // file itself is removed at push time so other devices can also adopt
    // the new layout without seeing it again.
    final remoteShards = await _loadRemoteShards(
      booksShardF: booksShardF,
      settingsShardF: settingsShardF,
      sessionsShardF: sessionsShardF,
      bookmarksShardF: bookmarksShardF,
      legacyManifestF: legacyManifestF,
      deviceId: config.deviceId,
    );

    // 3. Inventory the books folder + auto-import orphans (only when EPUB
    // sync is enabled).
    Set<String> remoteEpubFiles = const {};
    if (config.syncEpubs) {
      remoteEpubFiles = (await listBooksF).toSet();
      await _autoImportOrphanFiles(
        folder: folder,
        remoteBooks: remoteShards.books,
        remoteEpubFiles: remoteEpubFiles,
        onProgress: onImportProgress,
      );
    }

    // 4. Build local shard snapshots (now possibly augmented with the
    // freshly auto-imported books). Reuse the remote settings timestamp
    // when the user didn't touch settings this session so the skip-write
    // check fires.
    final settingsTs = localSettingsUpdatedAt ??
        remoteShards.settings.settings?.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final local = await _buildLocalShards(
      config: config,
      localSettings: readSettings(),
      localSettingsUpdatedAt: settingsTs,
    );

    // 5. Merge each shard, then compact zombie tombstones (see docs).
    final mergedBooks = _compactZombieTombstones(
      mergeBooksShard(local.books, remoteShards.books, config.deviceId),
      config.deviceId,
    );
    final mergedSettings =
        mergeSettingsShard(local.settings, remoteShards.settings, config.deviceId);
    final mergedSessions =
        mergeSessionsShard(local.sessions, remoteShards.sessions, config.deviceId);
    final mergedBookmarks =
        mergeBookmarksShard(local.bookmarks, remoteShards.bookmarks, config.deviceId);

    // 6. Apply remote → local where remote won.
    await _applyShardsToLocal(
      merged: _MergedShards(
        books: mergedBooks,
        settings: mergedSettings,
        sessions: mergedSessions,
        bookmarks: mergedBookmarks,
      ),
      localBefore: local,
      config: config,
      applySettings: applySettings,
    );

    // 7. Push each shard only if its content actually changed. The legacy
    // monolith is deleted on first sync after upgrade.
    if (remoteShards.legacyPresent) {
      try {
        await _gateway.deleteFile(folder, _kLegacyLibraryFile);
      } catch (_) {/* best-effort; next sync will retry */}
    }
    final pushes = <Future<void>>[];
    if (!_booksShardEquals(mergedBooks, remoteShards.books)) {
      pushes.add(
          _gateway.writeText(folder, _kBooksShardFile, mergedBooks.encode()));
    }
    if (!_settingsShardEquals(mergedSettings, remoteShards.settings)) {
      pushes.add(_gateway.writeText(
          folder, _kSettingsShardFile, mergedSettings.encode()));
    }
    if (!_sessionsShardEquals(mergedSessions, remoteShards.sessions)) {
      pushes.add(_gateway.writeText(
          folder, _kSessionsShardFile, mergedSessions.encode()));
    }
    if (!_bookmarksShardEquals(mergedBookmarks, remoteShards.bookmarks)) {
      pushes.add(_gateway.writeText(
          folder, _kBookmarksShardFile, mergedBookmarks.encode()));
    }
    await Future.wait(pushes);

    // 8. Upload any local EPUBs the folder is missing (when EPUB sync on).
    if (config.syncEpubs) {
      await _uploadMissingEpubs(
        folder: folder,
        merged: mergedBooks,
        remoteEpubFiles: remoteEpubFiles,
      );
    }

    return DateTime.now();
  }

  /// Loads the three shards. Falls back to the legacy `library.json` only
  /// when none of the shards exist remotely (fresh upgrade); otherwise the
  /// legacy file is treated as already-migrated and ignored.
  Future<_RemoteShards> _loadRemoteShards({
    required Future<String?> booksShardF,
    required Future<String?> settingsShardF,
    required Future<String?> sessionsShardF,
    required Future<String?> bookmarksShardF,
    required Future<String?> legacyManifestF,
    required String deviceId,
  }) async {
    final booksRaw = await booksShardF;
    final settingsRaw = await settingsShardF;
    final sessionsRaw = await sessionsShardF;
    final bookmarksRaw = await bookmarksShardF;
    final legacyRaw = await legacyManifestF;
    final legacyPresent = legacyRaw != null && legacyRaw.trim().isNotEmpty;

    final anyShardPresent = (booksRaw != null && booksRaw.trim().isNotEmpty) ||
        (settingsRaw != null && settingsRaw.trim().isNotEmpty) ||
        (sessionsRaw != null && sessionsRaw.trim().isNotEmpty) ||
        (bookmarksRaw != null && bookmarksRaw.trim().isNotEmpty);

    if (!anyShardPresent && legacyPresent) {
      final legacy = SyncLibrary.decode(legacyRaw);
      return _RemoteShards(
        books: SyncBooksShard(
          updatedAt: legacy.updatedAt,
          updatedBy: legacy.updatedBy,
          books: legacy.books,
        ),
        settings: SyncSettingsShard(
          updatedAt: legacy.updatedAt,
          updatedBy: legacy.updatedBy,
          settings: legacy.settings,
        ),
        sessions: SyncSessionsShard.empty(deviceId),
        bookmarks: SyncBookmarksShard.empty(deviceId),
        legacyPresent: true,
      );
    }

    return _RemoteShards(
      books: booksRaw == null || booksRaw.trim().isEmpty
          ? SyncBooksShard.empty(deviceId)
          : SyncBooksShard.decode(booksRaw),
      settings: settingsRaw == null || settingsRaw.trim().isEmpty
          ? SyncSettingsShard.empty(deviceId)
          : SyncSettingsShard.decode(settingsRaw),
      sessions: sessionsRaw == null || sessionsRaw.trim().isEmpty
          ? SyncSessionsShard.empty(deviceId)
          : SyncSessionsShard.decode(sessionsRaw),
      bookmarks: bookmarksRaw == null || bookmarksRaw.trim().isEmpty
          ? SyncBookmarksShard.empty(deviceId)
          : SyncBookmarksShard.decode(bookmarksRaw),
      legacyPresent: legacyPresent,
    );
  }

  SyncBooksShard _compactZombieTombstones(
    SyncBooksShard shard,
    String deviceId,
  ) {
    final activeFileNames = <String>{
      for (final b in shard.books)
        if (b.deletedAt == null) b.syncFileName ?? '${b.id}.epub',
    };
    final compactedBooks = shard.books.where((b) {
      if (b.deletedAt == null) return true;
      final name = b.syncFileName ?? '${b.id}.epub';
      return !activeFileNames.contains(name);
    }).toList();
    if (compactedBooks.length == shard.books.length) return shard;
    return SyncBooksShard(
      schemaVersion: shard.schemaVersion,
      updatedAt: shard.updatedAt,
      updatedBy: deviceId,
      books: compactedBooks,
    );
  }

  Future<_LocalShards> _buildLocalShards({
    required SyncConfig config,
    required DisplaySettings localSettings,
    required DateTime localSettingsUpdatedAt,
  }) async {
    // Articles are local-only — they have no backing EPUB to upload and the
    // shards target EPUB libraries. Skip them here.
    final books = (await _booksDao.getAllBooks())
        .where((b) => b.source == BookSource.epub)
        .toList();
    final bookRows = <SyncLibraryBook>[];
    for (final book in books) {
      final progress = await _progressDao.getProgressForBook(book.id);
      bookRows.add(SyncLibraryBook(
        id: book.id,
        title: book.title,
        author: book.author,
        totalWords: book.totalWords,
        chapterCount: book.chapterCount,
        importedAt: book.importedAt,
        lastReadAt: book.lastReadAt,
        hasEpubFile: true,
        syncFileName: book.syncFileName,
        progress: progress == null
            ? null
            : SyncLibraryProgress(
                chapterIndex: progress.chapterIndex,
                wordIndex: progress.wordIndex,
                wpm: progress.wpm,
                updatedAt: progress.updatedAt,
                readerMode: progress.readerMode,
              ),
        deletedAt: null,
        updatedAt: book.lastReadAt ?? book.importedAt,
        rating: book.rating,
        ratingUpdatedAt: book.ratingUpdatedAt,
      ));
    }

    // Sessions are append-only: we ship every local row and the merge does
    // a set-union by id remotely.
    final localSessions = await _sessionDao.getAllSessions();
    final sessionRows = localSessions
        .map((s) => SyncReadingSession(
              id: s.id,
              bookId: s.bookId,
              startedAt: s.startedAt,
              endedAt: s.endedAt,
              durationMs: s.durationMs,
              wordsRead: s.wordsRead,
              startWordIndex: s.startWordIndex,
              endWordIndex: s.endWordIndex,
              avgWpm: s.avgWpm,
            ))
        .toList();

    // Bookmarks ship every row including tombstones — peers need the
    // `deletedAt` to converge on deletes. The DAO's getAllIncludingTombstones
    // is named accordingly.
    final localBookmarks = await _bookmarksDao.getAllIncludingTombstones();
    final bookmarkRows = localBookmarks
        .map((b) => SyncLibraryBookmark(
              id: b.id,
              bookId: b.bookId,
              globalWordIndex: b.globalWordIndex,
              chapterIndex: b.chapterIndex,
              label: b.label,
              contextSnippet: b.contextSnippet,
              createdAt: b.createdAt,
              updatedAt: b.updatedAt,
              deletedAt: b.deletedAt,
            ))
        .toList();

    final now = DateTime.now().toUtc();
    return _LocalShards(
      books: SyncBooksShard(
        updatedAt: now,
        updatedBy: config.deviceId,
        books: bookRows,
      ),
      settings: SyncSettingsShard(
        updatedAt: now,
        updatedBy: config.deviceId,
        settings: SyncLibrarySettings(
          values: displaySettingsToMap(localSettings),
          updatedAt: localSettingsUpdatedAt,
        ),
      ),
      sessions: SyncSessionsShard(
        updatedAt: now,
        updatedBy: config.deviceId,
        sessions: sessionRows,
      ),
      bookmarks: SyncBookmarksShard(
        updatedAt: now,
        updatedBy: config.deviceId,
        bookmarks: bookmarkRows,
      ),
    );
  }

  Future<void> _applyShardsToLocal({
    required _MergedShards merged,
    required _LocalShards localBefore,
    required SyncConfig config,
    required ApplySettingsCallback applySettings,
  }) async {
    final localById = {for (final b in localBefore.books.books) b.id: b};

    for (final book in merged.books.books) {
      try {
        final local = localById[book.id];

        // Tombstone: remote says deleted → drop locally.
        if (book.deletedAt != null) {
          if (local != null) {
            await _deleteBookLocally(book.id);
          }
          continue;
        }

        if (local == null) {
          // New book from remote. Need the EPUB to populate tokens.
          if (config.syncEpubs) {
            await _importFromRemoteEpub(
              folder: config.driveFolderId!,
              book: book,
            );
          } else {
            // Insert a placeholder row so progress/metadata sync, but skip
            // tokens. Reader will prompt to re-import locally.
            await _insertPlaceholderBook(book);
            if (book.progress != null) {
              await _progressDao.upsertProgress(ReadingProgressTableCompanion(
                bookId: Value(book.id),
                chapterIndex: Value(book.progress!.chapterIndex),
                wordIndex: Value(book.progress!.wordIndex),
                wpm: Value(book.progress!.wpm),
                updatedAt: Value(book.progress!.updatedAt),
                readerMode: Value(book.progress!.readerMode),
              ));
            }
          }
          continue;
        }

        // Book exists locally: update metadata + progress + rating when
        // merged differs.
        // DateTime comparisons use isAtSameMomentAs because local times come
        // from Drift (local TZ, isUtc=false) while remote times come from
        // shard JSON (isUtc=true). Default DateTime == compares both
        // microsSinceEpoch AND isUtc, so the same instant on the two sides
        // would always register as different — producing a needless write
        // per book on every sync.
        final localProg = local.progress;
        final remoteProg = book.progress;
        final progressDiffers = remoteProg != null &&
            (localProg == null ||
                !remoteProg.updatedAt.isAtSameMomentAs(localProg.updatedAt) ||
                remoteProg.wordIndex != localProg.wordIndex ||
                remoteProg.chapterIndex != localProg.chapterIndex ||
                remoteProg.readerMode != localProg.readerMode);
        if (progressDiffers) {
          await _progressDao.upsertProgress(ReadingProgressTableCompanion(
            bookId: Value(book.id),
            chapterIndex: Value(remoteProg.chapterIndex),
            wordIndex: Value(remoteProg.wordIndex),
            wpm: Value(remoteProg.wpm),
            updatedAt: Value(remoteProg.updatedAt),
            readerMode: Value(remoteProg.readerMode),
          ));
        }
        final lastReadDiffers = book.lastReadAt != null &&
            (local.lastReadAt == null ||
                !book.lastReadAt!.isAtSameMomentAs(local.lastReadAt!));
        if (lastReadDiffers) {
          await _booksDao.setLastReadAt(book.id, book.lastReadAt!);
        }

        // Rating LWW per its own timestamp.
        final remoteRatingTs = book.ratingUpdatedAt;
        final localRatingTs = local.ratingUpdatedAt;
        final ratingDiffers = remoteRatingTs != null &&
            (localRatingTs == null ||
                remoteRatingTs.isAfter(localRatingTs) ||
                book.rating != local.rating);
        if (ratingDiffers) {
          // Only apply when the remote timestamp is newer-or-equal; equality
          // with a different value would already be caught by the merge
          // (the merge picks one deterministically, and we just persist it).
          if (localRatingTs == null ||
              remoteRatingTs.isAfter(localRatingTs) ||
              remoteRatingTs.isAtSameMomentAs(localRatingTs)) {
            await _booksDao.applySyncedRating(
                book.id, book.rating, remoteRatingTs);
          }
        }
      } catch (e, st) {
        debugPrint('Failed to apply remote book "${book.id}": $e\n$st');
      }
    }

    // Sessions: insert any remote ids the local DB doesn't have yet. They
    // never mutate, so we don't update existing rows.
    final existingIds = await _sessionDao.existingSessionIds();
    int newSessions = 0;
    for (final s in merged.sessions.sessions) {
      if (existingIds.contains(s.id)) continue;
      try {
        await _sessionDao.insertSession(ReadingSessionTableCompanion.insert(
          id: s.id,
          bookId: s.bookId,
          startedAt: s.startedAt,
          endedAt: s.endedAt,
          durationMs: s.durationMs,
          wordsRead: s.wordsRead,
          startWordIndex: s.startWordIndex,
          endWordIndex: s.endWordIndex,
          avgWpm: s.avgWpm,
        ));
        newSessions++;
      } catch (e, st) {
        debugPrint('Failed to apply remote session "${s.id}": $e\n$st');
      }
    }
    if (newSessions > 0) {
      debugPrint('[sync] imported $newSessions remote session(s)');
    }

    // Bookmarks: LWW by updatedAt. We compare against the local
    // `getAllIncludingTombstones()` snapshot so a remote update bumping the
    // label or flipping deletedAt is applied verbatim.
    final localBookmarksById = {
      for (final bm in localBefore.bookmarks.bookmarks) bm.id: bm,
    };
    for (final remote in merged.bookmarks.bookmarks) {
      try {
        final local = localBookmarksById[remote.id];
        if (local == null) {
          // First time we see this bookmark. Skip tombstone-only rows the
          // local DB never knew about — the remote already carries the
          // tombstone, so other peers don't need us to round-trip it.
          if (remote.deletedAt != null) continue;
          await _bookmarksDao.applyFromSync(BookmarksTableCompanion.insert(
            id: remote.id,
            bookId: remote.bookId,
            globalWordIndex: remote.globalWordIndex,
            chapterIndex: Value(remote.chapterIndex),
            label: Value(remote.label),
            contextSnippet: Value(remote.contextSnippet),
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            deletedAt: Value(remote.deletedAt),
          ));
          continue;
        }
        // Use isAtSameMomentAs to compare timestamps across UTC/local
        // boundaries (Drift writes local-TZ, JSON parses to UTC).
        if (remote.updatedAt.isAtSameMomentAs(local.updatedAt)) continue;
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          await _bookmarksDao.applyFromSync(BookmarksTableCompanion(
            id: Value(remote.id),
            bookId: Value(remote.bookId),
            globalWordIndex: Value(remote.globalWordIndex),
            chapterIndex: Value(remote.chapterIndex),
            label: Value(remote.label),
            contextSnippet: Value(remote.contextSnippet),
            createdAt: Value(remote.createdAt),
            updatedAt: Value(remote.updatedAt),
            deletedAt: Value(remote.deletedAt),
          ));
        }
      } catch (e, st) {
        debugPrint('Failed to apply remote bookmark "${remote.id}": $e\n$st');
      }
    }

    // Settings: only apply when remote wins (its updatedAt > local's).
    // Isolated in its own try/catch so a prefs write failure doesn't bail
    // out of the sync before we write the merged manifest back to the
    // remote folder.
    final localSettingsTs = localBefore.settings.settings?.updatedAt;
    final mergedSettingsTs = merged.settings.settings?.updatedAt;
    if (merged.settings.settings != null &&
        (localSettingsTs == null ||
            (mergedSettingsTs != null &&
                mergedSettingsTs.isAfter(localSettingsTs)))) {
      try {
        await applySettings(
            displaySettingsFromMap(merged.settings.settings!.values));
      } catch (e, st) {
        debugPrint('Failed to apply remote settings: $e\n$st');
      }
    }
  }

  Future<void> _deleteBookLocally(String bookId) async {
    await _tokensDao.deleteTokensForBook(bookId);
    await _progressDao.deleteProgressForBook(bookId);
    // Bookmarks of a removed book are dropped outright (no per-row
    // tombstone needed): the parent book tombstone already propagates the
    // deletion intent and every peer's _applyShardsToLocal will cascade
    // here the same way.
    await _bookmarksDao.deleteAllForBook(bookId);
    final book = await _booksDao.getBookById(bookId);
    if (book != null) {
      final f = File(book.filePath);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {/* best effort */}
      }
    }
    await _booksDao.deleteBook(bookId);
    await const InlineImageStorage().deleteForBook(bookId);
  }

  /// Returns the relative path in the sync folder where [book]'s EPUB lives.
  /// Uses [SyncLibraryBook.syncFileName] when present, falling back to the
  /// legacy `<bookId>.epub` naming for books imported before the filename
  /// feature landed.
  String _epubRelPath(SyncLibraryBook book) {
    final name = book.syncFileName ?? '${book.id}.epub';
    return '$_kBooksDir/$name';
  }

  Future<void> _insertPlaceholderBook(SyncLibraryBook book) async {
    await _booksDao.insertBook(BooksTableCompanion.insert(
      id: book.id,
      title: book.title,
      author: Value(book.author),
      filePath: '', // no local file yet
      totalWords: Value(book.totalWords),
      chapterCount: Value(book.chapterCount),
      importedAt: book.importedAt,
      lastReadAt: Value(book.lastReadAt),
      syncFileName: Value(book.syncFileName),
    ));
  }

  Future<void> _importFromRemoteEpub({
    required String folder,
    required SyncLibraryBook book,
  }) async {
    final bytes = await _gateway.readBytes(folder, _epubRelPath(book));
    if (bytes == null) {
      // Remote metadata references an EPUB that isn't there yet. Insert
      // placeholder; next sync will fill it in.
      await _insertPlaceholderBook(book);
      if (book.progress != null) {
        await _progressDao.upsertProgress(ReadingProgressTableCompanion(
          bookId: Value(book.id),
          chapterIndex: Value(book.progress!.chapterIndex),
          wordIndex: Value(book.progress!.wordIndex),
          wpm: Value(book.progress!.wpm),
          updatedAt: Value(book.progress!.updatedAt),
          readerMode: Value(book.progress!.readerMode),
        ));
      }
      return;
    }

    final parsed = await _extractionService.extractBook(bytes);
    if (parsed.chapters.isEmpty) {
      await _insertPlaceholderBook(book);
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/${AppConstants.booksSubdir}');
    if (!booksDir.existsSync()) {
      await booksDir.create(recursive: true);
    }
    final savedPath = '${booksDir.path}/${book.id}.epub';
    await File(savedPath).writeAsBytes(bytes);

    await _booksDao.insertBook(BooksTableCompanion.insert(
      id: book.id,
      title: book.title,
      author: Value(book.author),
      filePath: savedPath,
      coverImage: Value(parsed.coverImage),
      totalWords: Value(parsed.totalWords),
      chapterCount: Value(parsed.chapters.length),
      importedAt: book.importedAt,
      lastReadAt: Value(book.lastReadAt),
      syncFileName: Value(book.syncFileName),
    ));

    await persistChaptersWithImages(
      bookId: book.id,
      chapters: parsed.chapters,
      tokensDao: _tokensDao,
    );

    if (book.progress != null) {
      await _progressDao.upsertProgress(ReadingProgressTableCompanion(
        bookId: Value(book.id),
        chapterIndex: Value(book.progress!.chapterIndex),
        wordIndex: Value(book.progress!.wordIndex),
        wpm: Value(book.progress!.wpm),
        updatedAt: Value(book.progress!.updatedAt),
        readerMode: Value(book.progress!.readerMode),
      ));
    }
  }

  Future<void> _uploadMissingEpubs({
    required String folder,
    required SyncBooksShard merged,
    required Set<String> remoteEpubFiles,
  }) async {
    // Filenames claimed by at least one active (non-tombstoned) book in the
    // merged library. If two entries share a syncFileName — an old tombstone
    // plus a re-imported orphan, for example — the tombstone's delete would
    // clobber the active book's file and the next sync would upload it back,
    // forever. Actives win this tie: leave the file alone.
    final activeFileNames = <String>{};
    for (final book in merged.books) {
      if (book.deletedAt != null) continue;
      activeFileNames.add(book.syncFileName ?? '${book.id}.epub');
    }

    for (final book in merged.books) {
      final fileName = book.syncFileName ?? '${book.id}.epub';
      final relPath = '$_kBooksDir/$fileName';

      if (book.deletedAt != null) {
        if (activeFileNames.contains(fileName)) continue;
        // Only round-trip to Drive if the file actually exists; previous
        // syncs' tombstones would otherwise re-trigger a list+delete pair
        // for every already-removed file on every sync.
        if (remoteEpubFiles.contains(fileName)) {
          await _gateway.deleteFile(folder, relPath);
        }
        continue;
      }

      if (remoteEpubFiles.contains(fileName)) continue;

      final local = await _booksDao.getBookById(book.id);
      if (local == null || local.filePath.isEmpty) continue;
      final localFile = File(local.filePath);
      if (!await localFile.exists()) continue;

      final bytes = await localFile.readAsBytes();
      await _gateway.writeBytes(folder, relPath, bytes);
    }
  }

  /// Discovers EPUBs that the user dropped directly in the sync folder and
  /// imports them as fresh local books. A file is considered "orphan" when
  /// its name matches no entry in the remote manifest nor any local book's
  /// [BooksTableData.syncFileName].
  ///
  /// Files that previously failed to import are recorded in
  /// [SyncImportFailuresDao] and skipped on subsequent syncs so we don't
  /// thrash on a corrupt EPUB. Stale failure entries for files the user
  /// deleted from the cloud are pruned here as well. Per-file errors are
  /// caught so a single bad EPUB does not block the rest.
  ///
  /// Known limitation: matching is case-sensitive and by exact filename.
  /// Renaming a file in the cloud is treated as "delete old + new orphan",
  /// which produces a duplicate book. A content-hash dedup would fix this
  /// but is out of scope here.
  Future<void> _autoImportOrphanFiles({
    required String folder,
    required SyncBooksShard remoteBooks,
    required Set<String> remoteEpubFiles,
    ImportProgressCallback? onProgress,
  }) async {
    await _failuresDao.retainOnly(remoteEpubFiles);
    final previouslyFailed = await _failuresDao.getAllFileNames();

    final knownInManifest = remoteBooks.books
        .where((b) => b.deletedAt == null && b.syncFileName != null)
        .map((b) => b.syncFileName!)
        .toSet();
    // Tombstoned filenames: re-importing them would spawn a second book row
    // with the same syncFileName as a pre-existing tombstone, which then
    // fights the active row each sync (tombstone deletes the active file,
    // active re-uploads, repeat forever). Treat them as "known" so the file
    // is left alone; the next _uploadMissingEpubs pass will clean it up via
    // the tombstone's delete branch.
    final tombstonedInManifest = remoteBooks.books
        .where((b) => b.deletedAt != null && b.syncFileName != null)
        .map((b) => b.syncFileName!)
        .toSet();
    final localBooks = await _booksDao.getAllBooks();
    final knownLocally = localBooks
        .map((b) => b.syncFileName)
        .whereType<String>()
        .toSet();

    final orphans = remoteEpubFiles
        .where((f) => f.toLowerCase().endsWith('.epub'))
        .where((f) => !knownInManifest.contains(f))
        .where((f) => !tombstonedInManifest.contains(f))
        .where((f) => !knownLocally.contains(f))
        .where((f) => !previouslyFailed.contains(f))
        .toList();
    if (orphans.isEmpty) return;

    onProgress?.call(0, orphans.length, '');

    for (int i = 0; i < orphans.length; i++) {
      final fileName = orphans[i];
      onProgress?.call(i, orphans.length, fileName);
      try {
        await _autoImportOrphan(folder: folder, fileName: fileName);
        // Success: clear any stale failure record for this filename.
        await _failuresDao.clear(fileName);
      } catch (e, st) {
        debugPrint('Failed to auto-import "$fileName": $e\n$st');
        await _failuresDao.record(fileName, e.toString());
      }
    }

    onProgress?.call(orphans.length, orphans.length, '');
  }

  Future<void> _autoImportOrphan({
    required String folder,
    required String fileName,
  }) async {
    final bytes = await _gateway.readBytes(folder, '$_kBooksDir/$fileName');
    if (bytes == null) return;

    final parsed = await _extractionService.extractBook(bytes);
    if (parsed.chapters.isEmpty) return;

    final bookId = const Uuid().v4();
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/${AppConstants.booksSubdir}');
    if (!booksDir.existsSync()) {
      await booksDir.create(recursive: true);
    }
    final savedPath = '${booksDir.path}/$bookId.epub';
    await File(savedPath).writeAsBytes(bytes);

    await _booksDao.insertBook(BooksTableCompanion.insert(
      id: bookId,
      title: parsed.title,
      author: Value(parsed.author),
      filePath: savedPath,
      coverImage: Value(parsed.coverImage),
      totalWords: Value(parsed.totalWords),
      chapterCount: Value(parsed.chapters.length),
      importedAt: DateTime.now(),
      syncFileName: Value(fileName),
    ));

    await persistChaptersWithImages(
      bookId: bookId,
      chapters: parsed.chapters,
      tokensDao: _tokensDao,
    );
  }

  /// True when two books shards describe the same book set, ignoring the
  /// per-sync metadata that flips every run. Skipping the write here saves a
  /// ~1.5s Drive round-trip when the user didn't touch any book this session.
  bool _booksShardEquals(SyncBooksShard a, SyncBooksShard b) {
    if (a.books.length != b.books.length) return false;
    final aBooks = [...a.books]..sort((x, y) => x.id.compareTo(y.id));
    final bBooks = [...b.books]..sort((x, y) => x.id.compareTo(y.id));
    for (int i = 0; i < aBooks.length; i++) {
      if (jsonEncode(aBooks[i].toJson()) != jsonEncode(bBooks[i].toJson())) {
        return false;
      }
    }
    return true;
  }

  bool _settingsShardEquals(SyncSettingsShard a, SyncSettingsShard b) {
    return jsonEncode(a.settings?.toJson()) ==
        jsonEncode(b.settings?.toJson());
  }

  bool _sessionsShardEquals(SyncSessionsShard a, SyncSessionsShard b) {
    if (a.sessions.length != b.sessions.length) return false;
    final aSessions = [...a.sessions]..sort((x, y) => x.id.compareTo(y.id));
    final bSessions = [...b.sessions]..sort((x, y) => x.id.compareTo(y.id));
    for (int i = 0; i < aSessions.length; i++) {
      if (jsonEncode(aSessions[i].toJson()) !=
          jsonEncode(bSessions[i].toJson())) {
        return false;
      }
    }
    return true;
  }

  bool _bookmarksShardEquals(SyncBookmarksShard a, SyncBookmarksShard b) {
    if (a.bookmarks.length != b.bookmarks.length) return false;
    final aBookmarks = [...a.bookmarks]..sort((x, y) => x.id.compareTo(y.id));
    final bBookmarks = [...b.bookmarks]..sort((x, y) => x.id.compareTo(y.id));
    for (int i = 0; i < aBookmarks.length; i++) {
      if (jsonEncode(aBookmarks[i].toJson()) !=
          jsonEncode(bBookmarks[i].toJson())) {
        return false;
      }
    }
    return true;
  }

  /// Write a tombstone to the books shard for [bookId] so other devices
  /// drop it on their next sync. Called from the delete path.
  Future<void> pushTombstone({
    required SyncConfig config,
    required String bookId,
    required DateTime deletedAt,
  }) async {
    final folder = config.driveFolderId!;
    if (!await _gateway.isReadable(folder)) return;

    final raw = await _gateway.readText(folder, _kBooksShardFile);
    SyncBooksShard remote = raw == null || raw.trim().isEmpty
        ? SyncBooksShard.empty(config.deviceId)
        : SyncBooksShard.decode(raw);

    final updated = <SyncLibraryBook>[];
    SyncLibraryBook? deletedEntry;
    bool found = false;
    for (final book in remote.books) {
      if (book.id == bookId) {
        found = true;
        final tombstone = book.copyWith(
          deletedAt: deletedAt,
          updatedAt: deletedAt,
        );
        deletedEntry = tombstone;
        updated.add(tombstone);
      } else {
        updated.add(book);
      }
    }
    if (!found) {
      final tombstone = SyncLibraryBook(
        id: bookId,
        title: '',
        totalWords: 0,
        chapterCount: 0,
        importedAt: deletedAt,
        hasEpubFile: false,
        deletedAt: deletedAt,
        updatedAt: deletedAt,
      );
      deletedEntry = tombstone;
      updated.add(tombstone);
    }

    final next = SyncBooksShard(
      updatedAt: DateTime.now().toUtc(),
      updatedBy: config.deviceId,
      books: updated,
    );
    await _gateway.writeText(folder, _kBooksShardFile, next.encode());

    if (config.syncEpubs && deletedEntry != null) {
      await _gateway.deleteFile(folder, _epubRelPath(deletedEntry));
    }
  }
}

/// In-memory wrapper for what we read from Drive.
class _RemoteShards {
  final SyncBooksShard books;
  final SyncSettingsShard settings;
  final SyncSessionsShard sessions;
  final SyncBookmarksShard bookmarks;

  /// True when `library.json` is still present remotely (and was migrated
  /// into [books]/[settings]). The sync flow deletes the legacy file on
  /// push so other devices don't see it on the next pull.
  final bool legacyPresent;

  const _RemoteShards({
    required this.books,
    required this.settings,
    required this.sessions,
    required this.bookmarks,
    required this.legacyPresent,
  });
}

/// In-memory wrapper for the snapshot we built off the local DB.
class _LocalShards {
  final SyncBooksShard books;
  final SyncSettingsShard settings;
  final SyncSessionsShard sessions;
  final SyncBookmarksShard bookmarks;

  const _LocalShards({
    required this.books,
    required this.settings,
    required this.sessions,
    required this.bookmarks,
  });
}

/// Output of merging local × remote, per shard.
class _MergedShards {
  final SyncBooksShard books;
  final SyncSettingsShard settings;
  final SyncSessionsShard sessions;
  final SyncBookmarksShard bookmarks;

  const _MergedShards({
    required this.books,
    required this.settings,
    required this.sessions,
    required this.bookmarks,
  });
}
