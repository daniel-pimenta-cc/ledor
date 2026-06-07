import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:rsvp_reader/database/app_database.dart';
import 'package:rsvp_reader/features/epub_import/data/services/epub_extraction_service.dart';
import 'package:rsvp_reader/features/library_sync/data/services/library_sync_service.dart';
import 'package:rsvp_reader/features/library_sync/domain/entities/sync_config.dart';
import 'package:rsvp_reader/features/library_sync/domain/entities/sync_library.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/display_settings.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../fixtures/build_minimal_epub.dart';
import '../../../fixtures/fake_path_provider.dart';
import '../../../fixtures/fake_sync_folder_gateway.dart';

export 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery, Value;
export 'package:rsvp_reader/database/app_database.dart';
export 'package:rsvp_reader/features/library_sync/domain/entities/sync_config.dart';
export 'package:rsvp_reader/features/library_sync/domain/entities/sync_library.dart';
export 'package:rsvp_reader/features/rsvp_reader/domain/entities/display_settings.dart';

export '../../../fixtures/build_minimal_epub.dart';
export '../../../fixtures/fake_sync_folder_gateway.dart';

/// Relative paths inside the fake sync folder, mirroring the private
/// constants in library_sync_service.dart.
const kLegacyLibraryFile = 'library.json';
const kBooksShardFile = 'library/books.json';
const kSettingsShardFile = 'library/settings.json';
const kSessionsShardFile = 'library/sessions.json';
const kBookmarksShardFile = 'library/bookmarks.json';
const kBooksDir = 'books';

/// End-to-end harness for [LibrarySyncService.sync]: real in-memory Drift
/// database + real DAOs + real [EpubExtractionService], with the Drive
/// gateway faked in memory. Tests drive full pull → merge → apply → push
/// rounds and assert on the database and the fake folder afterwards.
///
/// ```dart
/// late SyncServiceHarness h;
/// setUp(() async { h = SyncServiceHarness(); await h.init(); });
/// tearDown(() => h.dispose());
/// ```
class SyncServiceHarness {
  late Directory tmp;
  late AppDatabase db;
  late FakeSyncFolderGateway gateway;
  late LibrarySyncService service;
  late SyncConfig config;

  /// What `readSettings` hands the service during [runSync].
  DisplaySettings localSettings = const DisplaySettings();

  /// Captured argument of the last `applySettings` callback, or null when
  /// the sync decided the local settings win.
  DisplaySettings? appliedSettings;

  Future<void> init({
    bool syncEpubs = true,
    String deviceId = 'device-local',
  }) async {
    tmp = await Directory.systemTemp.createTemp('rsvp_sync_harness_');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = AppDatabase(NativeDatabase.memory());
    gateway = FakeSyncFolderGateway();
    service = LibrarySyncService(
      gateway: gateway,
      booksDao: db.booksDao,
      progressDao: db.readingProgressDao,
      sessionDao: db.readingSessionDao,
      tokensDao: db.cachedTokensDao,
      failuresDao: db.syncImportFailuresDao,
      bookmarksDao: db.bookmarksDao,
      extractionService: EpubExtractionService(),
    );
    config = SyncConfig(
      driveFolderId: 'folder-1',
      deviceId: deviceId,
      syncEpubs: syncEpubs,
    );
  }

  Future<void> dispose() async {
    await db.close();
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  }

  /// One full sync round. [localSettingsUpdatedAt] defaults to the epoch so
  /// fresh local settings never beat a remote snapshot by accident.
  Future<DateTime> runSync({DateTime? localSettingsUpdatedAt}) {
    return service.sync(
      config: config,
      readSettings: () => localSettings,
      applySettings: (s) async => appliedSettings = s,
      localSettingsUpdatedAt: localSettingsUpdatedAt,
    );
  }

  // ---------------------------------------------------------------------
  // Remote folder builders
  // ---------------------------------------------------------------------

  /// A remote manifest entry with sane defaults; override what the test
  /// cares about. [updatedAt]/[importedAt] default to a fixed UTC instant.
  SyncLibraryBook makeRemoteBook({
    required String id,
    String title = 'Remote Book',
    String? author,
    int totalWords = 12,
    int chapterCount = 1,
    DateTime? importedAt,
    DateTime? lastReadAt,
    bool hasEpubFile = true,
    String? syncFileName,
    SyncLibraryProgress? progress,
    DateTime? deletedAt,
    DateTime? updatedAt,
    int? rating,
    DateTime? ratingUpdatedAt,
  }) {
    return SyncLibraryBook(
      id: id,
      title: title,
      author: author,
      totalWords: totalWords,
      chapterCount: chapterCount,
      importedAt: importedAt ?? DateTime.utc(2026, 1, 1),
      lastReadAt: lastReadAt,
      hasEpubFile: hasEpubFile,
      syncFileName: syncFileName,
      progress: progress,
      deletedAt: deletedAt,
      updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1),
      rating: rating,
      ratingUpdatedAt: ratingUpdatedAt,
    );
  }

  void putBooksShard(
    List<SyncLibraryBook> books, {
    DateTime? updatedAt,
    String updatedBy = 'device-remote',
  }) {
    gateway.textFiles[kBooksShardFile] = SyncBooksShard(
      updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1),
      updatedBy: updatedBy,
      books: books,
    ).encode();
  }

  void putBookmarksShard(
    List<SyncLibraryBookmark> bookmarks, {
    DateTime? updatedAt,
    String updatedBy = 'device-remote',
  }) {
    gateway.textFiles[kBookmarksShardFile] = SyncBookmarksShard(
      updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1),
      updatedBy: updatedBy,
      bookmarks: bookmarks,
    ).encode();
  }

  void putSessionsShard(
    List<SyncReadingSession> sessions, {
    DateTime? updatedAt,
    String updatedBy = 'device-remote',
  }) {
    gateway.textFiles[kSessionsShardFile] = SyncSessionsShard(
      updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1),
      updatedBy: updatedBy,
      sessions: sessions,
    ).encode();
  }

  /// Drops a valid EPUB into the fake folder's books/ dir (e.g. for
  /// auto-import-orphan or import-from-remote tests).
  void putRemoteEpub(String fileName, {String title = 'Remote Epub'}) {
    gateway.binFiles['$kBooksDir/$fileName'] = buildMinimalEpub(
      title: title,
      author: 'Remote Author',
      chapters: [
        (title: 'Chapter One', body: 'alpha beta gamma delta epsilon'),
      ],
    );
  }

  SyncBooksShard? readBooksShard() {
    final raw = gateway.textFiles[kBooksShardFile];
    return raw == null ? null : SyncBooksShard.decode(raw);
  }

  SyncBookmarksShard? readBookmarksShard() {
    final raw = gateway.textFiles[kBookmarksShardFile];
    return raw == null ? null : SyncBookmarksShard.decode(raw);
  }

  SyncSessionsShard? readSessionsShard() {
    final raw = gateway.textFiles[kSessionsShardFile];
    return raw == null ? null : SyncSessionsShard.decode(raw);
  }

  // ---------------------------------------------------------------------
  // Local database seeders
  // ---------------------------------------------------------------------

  /// Inserts a local EPUB book row backed by a real minimal EPUB written
  /// to the temp dir, so upload paths can read actual bytes. Returns the
  /// saved file path. Timestamps are written the way the app writes them:
  /// local-TZ DateTimes (Drift), which is what the isAtSameMomentAs
  /// invariants are about.
  Future<String> seedLocalBook({
    required String id,
    String title = 'Local Book',
    String? author,
    String? syncFileName,
    DateTime? importedAt,
    DateTime? lastReadAt,
    int totalWords = 12,
    int chapterCount = 1,
    int? rating,
    DateTime? ratingUpdatedAt,
  }) async {
    final path = '${tmp.path}/$id.epub';
    File(path).writeAsBytesSync(buildMinimalEpub(
      title: title,
      author: author ?? 'Local Author',
      chapters: [
        (title: 'Chapter One', body: 'alpha beta gamma delta epsilon'),
      ],
    ));
    await db.booksDao.insertBook(BooksTableCompanion.insert(
      id: id,
      title: title,
      author: Value(author),
      filePath: path,
      totalWords: Value(totalWords),
      chapterCount: Value(chapterCount),
      importedAt: importedAt ?? DateTime(2026, 1, 1),
      lastReadAt: Value(lastReadAt),
      syncFileName: Value(syncFileName),
    ));
    if (rating != null) {
      await db.booksDao.applySyncedRating(
          id, rating, ratingUpdatedAt ?? DateTime(2026, 1, 1));
    }
    return path;
  }

  Future<void> seedLocalProgress({
    required String bookId,
    int chapterIndex = 0,
    int wordIndex = 0,
    int wpm = 300,
    DateTime? updatedAt,
    String? readerMode,
  }) async {
    await db.readingProgressDao.upsertProgress(ReadingProgressTableCompanion(
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      wordIndex: Value(wordIndex),
      wpm: Value(wpm),
      updatedAt: Value(updatedAt ?? DateTime(2026, 1, 1)),
      readerMode: Value(readerMode),
    ));
  }

  Future<void> seedLocalBookmark({
    required String id,
    required String bookId,
    int globalWordIndex = 0,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) async {
    await db.bookmarksDao.applyFromSync(BookmarksTableCompanion.insert(
      id: id,
      bookId: bookId,
      globalWordIndex: globalWordIndex,
      label: Value(label),
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      updatedAt: updatedAt ?? DateTime(2026, 1, 1),
      deletedAt: Value(deletedAt),
    ));
  }
}
