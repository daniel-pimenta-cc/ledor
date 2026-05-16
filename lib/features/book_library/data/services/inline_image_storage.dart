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
  /// `book_images/<bookId>/3.png`) — what gets stored in
  /// `WordToken.imageRelativePath`.
  Future<String> writeImage({
    required String bookId,
    required int sequenceIndex,
    required Uint8List bytes,
  }) async {
    final dir = await _ensureBookDir(bookId);
    final ext = _detectExtension(bytes);
    final fileName = '$sequenceIndex$ext';
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

  /// Sniffs magic bytes to pick the right extension. Falls back to `.bin`
  /// when nothing matches — the renderer will refuse and we'll just show
  /// the placeholder. Avoids storing the wrong mime type when the EPUB
  /// declared one thing and the bytes are something else (it happens).
  static String _detectExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return '.gif';
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return '.bmp';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return '.webp';
    }
    return '.bin';
  }
}
