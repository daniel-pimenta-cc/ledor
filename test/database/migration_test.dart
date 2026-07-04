import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/database/app_database.dart';

/// Regression tests for the Drift schema migration.
///
/// The bug these guard against: the `from < 9` step calls
/// `createTable(bookmarksTable)`, which materialises the *current*
/// definition — already carrying the v10 `end_global_word_index` /
/// `end_chapter_index` columns. The old `from < 10` block then ran
/// `addColumn(endGlobalWordIndex)` unconditionally, so any DB jumping from
/// < 9 straight to >= 10 crashed with `SqliteException(1): duplicate column
/// name`. A real device (a Galaxy Tab on an April build, schema < 9) hit
/// exactly this on first open of the new build.
///
/// Strategy: let Drift create the *current* schema, then simulate an older
/// DB by dropping the objects a real old DB wouldn't have and rewinding
/// `user_version`. Reopening forces `onUpgrade` to run for real.
void main() {
  late Directory tmpDir;
  late File dbFile;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('rsvp_mig_test');
    dbFile = File('${tmpDir.path}/app.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  /// Open a throwaway DB on [dbFile] to seed the current schema, run [seed]
  /// against the raw connection to roll it back to an older state, then
  /// close. The next `AppDatabase(NativeDatabase(dbFile))` will migrate.
  Future<void> seedOldSchema(Future<void> Function(AppDatabase db) seed) async {
    final db = AppDatabase(NativeDatabase(dbFile));
    // Force the lazy open so onCreate builds the full v11 schema first.
    await db.customStatement('SELECT 1');
    await seed(db);
    await db.close();
  }

  Future<Set<String>> bookmarkColumns(AppDatabase db) async {
    final rows =
        await db.customSelect("PRAGMA table_info('bookmarks_table')").get();
    return rows.map((r) => r.data['name'] as String).toSet();
  }

  test('upgrade from < 9 (no bookmarks table) reaches v11 without crashing '
      'and bookmarks has the end-anchor columns', () async {
    await seedOldSchema((db) async {
      await db.customStatement('DROP TABLE IF EXISTS bookmarks_table');
      await db.customStatement('DROP INDEX IF EXISTS cached_tokens_book_id_idx');
      await db.customStatement('PRAGMA user_version = 8');
    });

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // Must not throw "duplicate column name" — this is the tablet's crash.
    final cols = await bookmarkColumns(db);
    expect(cols, containsAll(['end_global_word_index', 'end_chapter_index']));

    final version = await db
        .customSelect('PRAGMA user_version')
        .map((r) => r.data['user_version'] as int)
        .getSingle();
    expect(version, 11);
  });

  test('upgrade from a half-applied state (bookmarks table already present, '
      'user_version still < 9) recovers instead of crashing on '
      '"table already exists"', () async {
    await seedOldSchema((db) async {
      // Leave bookmarks_table in place (the failed migration had created it
      // with the full current schema before aborting), but drop the v11
      // index it never reached and rewind the version.
      await db.customStatement('DROP INDEX IF EXISTS cached_tokens_book_id_idx');
      await db.customStatement('PRAGMA user_version = 8');
    });

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final cols = await bookmarkColumns(db);
    expect(cols, containsAll(['end_global_word_index', 'end_chapter_index']));
  });

  test('upgrade from a fully half-applied state (every table/index/column '
      'already present, user_version stuck at 4) rolls forward to v11 '
      'without crashing on "already exists"', () async {
    // Reproduces the real device state: a v4 build whose first upgrade ran
    // far enough to create reading_session + its indexes, sync_import_failures
    // and bookmarks (with the current schema) before aborting — leaving the
    // full v11 object set committed but user_version still 4.
    await seedOldSchema((db) async {
      await db.customStatement('PRAGMA user_version = 4');
    });

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // The first thing the migration would re-run for from=4 is
    // `CREATE INDEX reading_session_started_at_idx` — which already exists.
    // Must not throw.
    final version = await db
        .customSelect('PRAGMA user_version')
        .map((r) => r.data['user_version'] as int)
        .getSingle();
    expect(version, 11);

    final cols = await bookmarkColumns(db);
    expect(cols, containsAll(['end_global_word_index', 'end_chapter_index']));
  });

  test('upgrade from exactly v9 (bookmarks without end-anchor columns) adds '
      'them via the guarded addColumn step', () async {
    await seedOldSchema((db) async {
      await db.customStatement('DROP TABLE IF EXISTS bookmarks_table');
      await db.customStatement('DROP INDEX IF EXISTS cached_tokens_book_id_idx');
      // Recreate bookmarks at the v9 shape: no end_global_word_index /
      // end_chapter_index columns.
      await db.customStatement('''
        CREATE TABLE bookmarks_table (
          id TEXT NOT NULL,
          book_id TEXT NOT NULL,
          global_word_index INTEGER NOT NULL,
          chapter_index INTEGER NOT NULL DEFAULT 0,
          label TEXT,
          context_snippet TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          PRIMARY KEY (id)
        )
      ''');
      await db.customStatement('PRAGMA user_version = 9');
    });

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final cols = await bookmarkColumns(db);
    expect(cols, containsAll(['end_global_word_index', 'end_chapter_index']));
  });
}
