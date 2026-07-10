import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/sync_file_name.dart';
import '../../../book_library/data/services/book_persistence.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../data/services/epub_extraction_service.dart';

final epubExtractionServiceProvider = Provider<EpubExtractionService>((ref) {
  return EpubExtractionService();
});

/// State for the import process.
enum ImportStatus { idle, processing, done, error }

class ImportState {
  final ImportStatus status;
  final String? importedBookId;

  const ImportState({
    this.status = ImportStatus.idle,
    this.importedBookId,
  });

  ImportState copyWith({
    ImportStatus? status,
    String? importedBookId,
  }) {
    return ImportState(
      status: status ?? this.status,
      importedBookId: importedBookId ?? this.importedBookId,
    );
  }
}

class EpubImportNotifier extends StateNotifier<ImportState> {
  final Ref _ref;

  EpubImportNotifier(this._ref) : super(const ImportState());

  Future<void> importFromFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: ImportStatus.idle);
        return;
      }

      await _importFromPath(
        result.files.single.path!,
        displayName: result.files.single.name,
      );
    } catch (_) {
      state = state.copyWith(status: ImportStatus.error);
    }
  }

  /// Entry point for drag-and-drop on desktop and any other caller that
  /// already has a file path on disk.
  Future<void> importFromPath(String path) async {
    try {
      await _importFromPath(path);
    } catch (_) {
      state = state.copyWith(status: ImportStatus.error);
    }
  }

  Future<void> _importFromPath(String filePath, {String? displayName}) async {
    state = state.copyWith(status: ImportStatus.processing);

    final pickedName = displayName ?? filePath.split(Platform.pathSeparator).last;
    final bytes = await File(filePath).readAsBytes();

    final extractionService = _ref.read(epubExtractionServiceProvider);
    final parsedBook = await extractionService.extractBook(bytes);

    if (parsedBook.chapters.isEmpty) {
      state = state.copyWith(status: ImportStatus.error);
      return;
    }

    // Pre-generate the book id so the on-disk filename matches the DB row.
    final bookId = const Uuid().v4();

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/${AppConstants.booksSubdir}');
    if (!booksDir.existsSync()) {
      await booksDir.create(recursive: true);
    }
    final savedPath = '${booksDir.path}/$bookId.epub';
    await File(savedPath).writeAsBytes(bytes);

    // We keep the user's filename for the sync folder (disambiguated
    // against existing books) so the files there are human-browsable.
    final booksDao = _ref.read(booksDaoProvider);
    final syncFileName = await uniqueSyncFileName(
      desired: pickedName,
      booksDao: booksDao,
    );

    await persistParsedBook(
      book: parsedBook,
      booksDao: booksDao,
      tokensDao: _ref.read(cachedTokensDaoProvider),
      id: bookId,
      filePath: savedPath,
      syncFileName: syncFileName,
    );

    // Do NOT create a reading_progress row here — the engine treats a
    // missing row as "not started" and defaults to (0, 0, defaultWpm) on
    // first open. Creating it at import time would put every freshly
    // imported book into the "In progress" section of the library.

    state = state.copyWith(
      status: ImportStatus.done,
      importedBookId: bookId,
    );

    // Push new book to sync folder (will copy EPUB too if syncEpubs is on).
    _ref.read(librarySyncProvider.notifier).schedulePush();
  }

  void reset() {
    state = const ImportState();
  }
}

final epubImportProvider =
    StateNotifierProvider<EpubImportNotifier, ImportState>((ref) {
  return EpubImportNotifier(ref);
});
