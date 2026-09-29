import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/linux_file_dialog.dart';
import '../../../../core/utils/platform_capabilities.dart';
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

  /// Id of the imported book when exactly one was imported (the library opens
  /// it right away). Null after a batch, where there is no single book to open.
  final String? importedBookId;

  /// Outcome of the last run. A batch can partially succeed, so `done` alone
  /// doesn't say whether anything failed.
  final int importedCount;
  final int failedCount;

  /// 1-based position of the file being processed while a batch runs.
  final int currentIndex;
  final int totalCount;

  /// Linux without qarma/kdialog/zenity: the file dialog can't open at all,
  /// which deserves a different message than a bad EPUB.
  final bool filePickerUnavailable;

  const ImportState({
    this.status = ImportStatus.idle,
    this.importedBookId,
    this.importedCount = 0,
    this.failedCount = 0,
    this.currentIndex = 0,
    this.totalCount = 0,
    this.filePickerUnavailable = false,
  });

  ImportState copyWith({
    ImportStatus? status,
    String? importedBookId,
    int? importedCount,
    int? failedCount,
    int? currentIndex,
    int? totalCount,
  }) {
    return ImportState(
      status: status ?? this.status,
      importedBookId: importedBookId ?? this.importedBookId,
      importedCount: importedCount ?? this.importedCount,
      failedCount: failedCount ?? this.failedCount,
      currentIndex: currentIndex ?? this.currentIndex,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

typedef PickedFile = ({String path, String? displayName});

/// Asks the user for EPUB files. Returns null/empty when they cancel.
typedef EpubPicker = Future<List<PickedFile>?> Function();

class FilePickerUnavailableException implements Exception {
  const FilePickerUnavailableException();
}

Future<List<PickedFile>?> _pickEpubsWithFilePicker() async {
  if (PlatformCapabilities.isLinux && !await hasLinuxFileDialogTool()) {
    throw const FilePickerUnavailableException();
  }
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['epub'],
    allowMultiple: true,
  );
  return [
    for (final f in result?.files ?? const <PlatformFile>[])
      if (f.path != null) (path: f.path!, displayName: f.name),
  ];
}

class EpubImportNotifier extends StateNotifier<ImportState> {
  final Ref _ref;
  final EpubPicker _pick;

  EpubImportNotifier(this._ref, {EpubPicker? picker})
      : _pick = picker ?? _pickEpubsWithFilePicker,
        super(const ImportState());

  Future<void> importFromFilePicker() async {
    final List<PickedFile>? files;
    try {
      files = await _pick();
    } on FilePickerUnavailableException {
      state = const ImportState(
        status: ImportStatus.error,
        filePickerUnavailable: true,
      );
      return;
    } catch (_) {
      state = state.copyWith(status: ImportStatus.error);
      return;
    }

    if (files == null || files.isEmpty) {
      state = state.copyWith(status: ImportStatus.idle);
      return;
    }

    await _importBatch(files);
  }

  /// Entry point for drag-and-drop on desktop and any other caller that
  /// already has a file path on disk.
  Future<void> importFromPath(String path) =>
      _importBatch([(path: path, displayName: null)]);

  /// Imports [files] one after another. Sequential on purpose: parsing is
  /// heavy and `uniqueSyncFileName` must see the previous book to avoid
  /// handing two files with the same name the same sync filename.
  Future<void> _importBatch(List<PickedFile> files) async {
    var imported = 0;
    var failed = 0;
    String? lastId;

    state = ImportState(
      status: ImportStatus.processing,
      totalCount: files.length,
      currentIndex: 1,
    );

    for (var i = 0; i < files.length; i++) {
      state = state.copyWith(currentIndex: i + 1);
      try {
        final id = await _importFromPath(
          files[i].path,
          displayName: files[i].displayName,
        );
        if (id == null) {
          failed++;
        } else {
          imported++;
          lastId = id;
        }
      } catch (_) {
        failed++;
      }
    }

    if (imported == 0) {
      state = ImportState(
        status: ImportStatus.error,
        failedCount: failed,
        totalCount: files.length,
      );
      return;
    }

    state = ImportState(
      status: ImportStatus.done,
      // Only a lone import opens the reader; after a batch the user stays in
      // the library to see what arrived.
      importedBookId: files.length == 1 ? lastId : null,
      importedCount: imported,
      failedCount: failed,
      totalCount: files.length,
    );

    // One push for the whole batch.
    _ref.read(librarySyncProvider.notifier).schedulePush();
  }

  /// Returns the new book id, or null when the EPUB has no readable content.
  Future<String?> _importFromPath(String filePath, {String? displayName}) async {
    final pickedName = displayName ?? filePath.split(Platform.pathSeparator).last;
    final bytes = await File(filePath).readAsBytes();

    final extractionService = _ref.read(epubExtractionServiceProvider);
    final parsedBook = await extractionService.extractBook(bytes);

    if (parsedBook.chapters.isEmpty) return null;

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

    return bookId;
  }

  void reset() {
    state = const ImportState();
  }
}

final epubImportProvider =
    StateNotifierProvider<EpubImportNotifier, ImportState>((ref) {
  return EpubImportNotifier(ref);
});
