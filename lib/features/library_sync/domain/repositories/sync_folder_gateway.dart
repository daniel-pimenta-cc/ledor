import 'dart:typed_data';

/// Abstraction over the user-chosen sync folder.
///
/// Implementations wrap the platform-specific file access: dart:io paths on
/// most platforms; could be swapped for a SAF-based impl on Android in the
/// future to support `content://` URIs with persisted permissions.
abstract class SyncFolderGateway {
  /// Whether the folder is reachable right now (exists, permissions ok).
  Future<bool> isReadable(String folderPath);

  /// Read a UTF-8 text file from the folder. Returns null if the file does
  /// not exist.
  Future<String?> readText(String folderPath, String relativePath);

  /// Write a UTF-8 text file, replacing any existing content.
  Future<void> writeText(String folderPath, String relativePath, String content);

  /// Read a binary file. Returns null if the file does not exist.
  Future<Uint8List?> readBytes(String folderPath, String relativePath);

  /// Write a binary file, replacing any existing content.
  Future<void> writeBytes(String folderPath, String relativePath, Uint8List bytes);

  /// Delete a file if it exists. No-op if it does not.
  Future<void> deleteFile(String folderPath, String relativePath);

  /// List relative file paths under [relativePath]. Empty if the directory
  /// doesn't exist.
  Future<List<String>> listFiles(String folderPath, String relativePath);
}
