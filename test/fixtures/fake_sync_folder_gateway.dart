import 'dart:typed_data';

import 'package:rsvp_reader/features/library_sync/domain/repositories/sync_folder_gateway.dart';

/// In-memory [SyncFolderGateway] for driving the sync service in tests.
///
/// Flip [readable] to simulate the folder being unreachable (offline,
/// revoked permissions); set [writeError] to make every write throw.
/// [writeLog] records the relative path of every successful write
/// (text and bytes) in order, so tests can assert that unchanged shards
/// are NOT re-pushed (the skip-write optimization).
class FakeSyncFolderGateway implements SyncFolderGateway {
  final Map<String, String> textFiles = {};
  final Map<String, Uint8List> binFiles = {};
  final List<String> writeLog = [];
  final List<String> deleteLog = [];
  bool readable = true;
  Object? writeError;

  @override
  Future<bool> isReadable(String folderPath) async => readable;

  @override
  Future<String?> readText(String folderPath, String relativePath) async =>
      textFiles[relativePath];

  @override
  Future<void> writeText(
      String folderPath, String relativePath, String content) async {
    final err = writeError;
    if (err != null) throw err;
    textFiles[relativePath] = content;
    writeLog.add(relativePath);
  }

  @override
  Future<Uint8List?> readBytes(String folderPath, String relativePath) async =>
      binFiles[relativePath];

  @override
  Future<void> writeBytes(
      String folderPath, String relativePath, Uint8List bytes) async {
    final err = writeError;
    if (err != null) throw err;
    binFiles[relativePath] = bytes;
    writeLog.add(relativePath);
  }

  @override
  Future<bool> fileExists(String folderPath, String relativePath) async =>
      textFiles.containsKey(relativePath) || binFiles.containsKey(relativePath);

  @override
  Future<void> deleteFile(String folderPath, String relativePath) async {
    textFiles.remove(relativePath);
    binFiles.remove(relativePath);
    deleteLog.add(relativePath);
  }

  @override
  Future<List<String>> listFiles(
      String folderPath, String relativePath) async {
    final prefix = '$relativePath/';
    return [
      for (final key in {...textFiles.keys, ...binFiles.keys})
        if (key.startsWith(prefix)) key.substring(prefix.length),
    ];
  }
}
