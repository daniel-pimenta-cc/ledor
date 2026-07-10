import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_import_failures_table.dart';

part 'sync_import_failures_dao.g.dart';

@DriftAccessor(tables: [SyncImportFailuresTable])
class SyncImportFailuresDao extends DatabaseAccessor<AppDatabase>
    with _$SyncImportFailuresDaoMixin {
  SyncImportFailuresDao(super.db);

  Future<List<SyncImportFailuresTableData>> getAll() {
    return (select(syncImportFailuresTable)
          ..orderBy([(t) => OrderingTerm.desc(t.failedAt)]))
        .get();
  }

  Stream<List<SyncImportFailuresTableData>> watchAll() {
    return (select(syncImportFailuresTable)
          ..orderBy([(t) => OrderingTerm.desc(t.failedAt)]))
        .watch();
  }

  Future<Set<String>> getAllFileNames() async {
    final rows = await getAll();
    return rows.map((r) => r.fileName).toSet();
  }

  Future<void> record(String fileName, String error) {
    return into(syncImportFailuresTable).insertOnConflictUpdate(
      SyncImportFailuresTableCompanion.insert(
        fileName: fileName,
        errorMessage: error,
        failedAt: DateTime.now(),
      ),
    );
  }

  Future<void> clear(String fileName) {
    return (delete(syncImportFailuresTable)
          ..where((t) => t.fileName.equals(fileName)))
        .go();
  }

  /// Removes failure rows whose fileName is not in [stillPresent]. Used
  /// after listing the sync folder to prune entries for files the user
  /// deleted from the cloud.
  Future<void> retainOnly(Set<String> stillPresent) async {
    await (delete(syncImportFailuresTable)
          ..where((t) => t.fileName.isNotIn(stillPresent)))
        .go();
  }
}
