import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_constants.dart';

/// File-backed storage for inline EPUB images.
///
/// Bytes live under `<documents>/book_images/<bookId>/<n>.<ext>` — outside
/// the SQLite database so a 50 MB image-heavy book does not balloon the DB.
/// Each book owns its own folder so deleting a book is a single recursive
/// remove, no per-row tracking.
class InlineImageStorage {
  const InlineImageStorage();

  /// Materialize [bytes] for [bookId] under a stable per-book directory.
  /// Returns the path relative to the app documents directory (e.g.
  /// `book_images/<bookId>/3.img`) — what gets stored in
  /// `WordToken.imageRelativePath`. Extension is fixed: nothing reads it and
  /// Flutter's image decoder detects the format from the bytes themselves.
  Future<String> writeImage({
    required String bookId,
    required int sequenceIndex,
    required Uint8List bytes,
  }) async {
    final dir = await _ensureBookDir(bookId);
    final fileName = '$sequenceIndex.img';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return '${AppConstants.bookImagesSubdir}/$bookId/$fileName';
  }

  /// Absolute filesystem path for [relativePath] (as stored in
  /// [WordToken.imageRelativePath]).
  Future<String> resolveAbsolutePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  /// Recursive cleanup for a deleted book. Best-effort: missing folder is
  /// not an error, since not every book has inline images.
  Future<void> deleteForBook(String bookId) async {
    final dir = await _bookDir(bookId);
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
    } catch (_) {/* best effort */}
  }

  Future<Directory> _ensureBookDir(String bookId) async {
    final dir = await _bookDir(bookId);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _bookDir(String bookId) async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(
        '${appDir.path}/${AppConstants.bookImagesSubdir}/$bookId');
  }
}
