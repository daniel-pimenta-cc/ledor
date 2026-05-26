import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../database/app_database.dart';
import '../../database/daos/bookmarks_dao.dart';
import '../../database/daos/books_dao.dart';
import '../../database/daos/cached_tokens_dao.dart';
import '../../database/daos/reading_progress_dao.dart';
import '../../database/daos/reading_session_dao.dart';
import '../../database/daos/sync_import_failures_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

final booksDaoProvider = Provider<BooksDao>((ref) {
  return ref.watch(appDatabaseProvider).booksDao;
});

final readingProgressDaoProvider = Provider<ReadingProgressDao>((ref) {
  return ref.watch(appDatabaseProvider).readingProgressDao;
});

final readingSessionDaoProvider = Provider<ReadingSessionDao>((ref) {
  return ref.watch(appDatabaseProvider).readingSessionDao;
});

final cachedTokensDaoProvider = Provider<CachedTokensDao>((ref) {
  return ref.watch(appDatabaseProvider).cachedTokensDao;
});

final syncImportFailuresDaoProvider = Provider<SyncImportFailuresDao>((ref) {
  return ref.watch(appDatabaseProvider).syncImportFailuresDao;
});

final bookmarksDaoProvider = Provider<BookmarksDao>((ref) {
  return ref.watch(appDatabaseProvider).bookmarksDao;
});

final appDocumentsDirProvider = FutureProvider<Directory>((ref) async {
  return getApplicationDocumentsDirectory();
});
