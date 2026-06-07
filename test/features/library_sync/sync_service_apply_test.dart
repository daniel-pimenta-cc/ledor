import 'package:flutter_test/flutter_test.dart';

import 'helpers/sync_service_harness.dart';

/// Apply-to-local behaviour of LibrarySyncService.sync(): once the shards are
/// merged, the remote-won values must land in the DB (progress, lastReadAt,
/// rating, settings) and the local-won values must survive untouched and ride
/// back out in the pushed shard.
///
/// Every test pins one concrete merge/apply invariant. Timestamps are
/// deterministic: DateTime.utc(...) on the remote shards (JSON is UTC),
/// DateTime(...) local-TZ on the DB seeds (Drift writes local) — the
/// isAtSameMomentAs rules exist precisely because of that split.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncServiceHarness h;

  setUp(() async {
    h = SyncServiceHarness();
    await h.init();
  });

  tearDown(() => h.dispose());

  // -------------------------------------------------------------------------
  // 1. Progress: remote newer (>60s ahead) wins and is written to the DB.
  // -------------------------------------------------------------------------
  test('remote progress >60s newer is applied to the local DB', () async {
    await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
    // Local: word 10, chapter 0, rsvp, an old (Jan) timestamp. Seeds use the
    // local TZ (Drift); remote uses UTC. The remote instant below is a whole
    // month ahead so it wins regardless of the runner's TZ offset — well past
    // the 60s tiebreaker window, so the larger wordIndex never matters.
    await h.seedLocalProgress(
      bookId: 'book-1',
      chapterIndex: 0,
      wordIndex: 10,
      wpm: 300,
      readerMode: 'rsvp',
      updatedAt: DateTime(2026, 1, 1, 10, 0, 0),
    );
    final remoteProgressTs = DateTime.utc(2026, 2, 1, 10, 0, 0);
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        updatedAt: DateTime.utc(2026, 2, 1),
        progress: SyncLibraryProgress(
          chapterIndex: 3,
          wordIndex: 999,
          wpm: 450,
          updatedAt: remoteProgressTs,
          readerMode: 'tts',
        ),
      ),
    ]);

    await h.runSync();

    final prog = await h.db.readingProgressDao.getProgressForBook('book-1');
    expect(prog, isNotNull);
    expect(prog!.chapterIndex, 3);
    expect(prog.wordIndex, 999);
    expect(prog.wpm, 450);
    expect(prog.readerMode, 'tts');
    // updatedAt is persisted as the remote instant (compared cross-TZ).
    expect(prog.updatedAt.isAtSameMomentAs(remoteProgressTs), isTrue);
  });

  // -------------------------------------------------------------------------
  // 2. progressDiffers explicitly includes readerMode: a mode-only change
  //    (same word/chapter, newer remote updatedAt) still gets applied.
  // -------------------------------------------------------------------------
  test('remote readerMode-only change is applied even when word/chapter match',
      () async {
    await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
    await h.seedLocalProgress(
      bookId: 'book-1',
      chapterIndex: 2,
      wordIndex: 50,
      wpm: 300,
      readerMode: 'rsvp',
      updatedAt: DateTime(2026, 1, 1, 10, 0, 0),
    );
    // Same chapter/word/wpm; only readerMode flips. Remote instant is a month
    // ahead so it unambiguously wins the LWW across the TZ boundary.
    final remoteProgressTs = DateTime.utc(2026, 2, 1, 10, 0, 0);
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        updatedAt: DateTime.utc(2026, 2, 1),
        progress: SyncLibraryProgress(
          chapterIndex: 2,
          wordIndex: 50,
          wpm: 300,
          updatedAt: remoteProgressTs,
          readerMode: 'ereader',
        ),
      ),
    ]);

    await h.runSync();

    final prog = await h.db.readingProgressDao.getProgressForBook('book-1');
    expect(prog!.readerMode, 'ereader');
    expect(prog.chapterIndex, 2);
    expect(prog.wordIndex, 50);
    expect(prog.updatedAt.isAtSameMomentAs(remoteProgressTs), isTrue);
  });

  // -------------------------------------------------------------------------
  // 3. Local progress newer: DB row untouched, and the pushed shard carries
  //    the local progress (not the remote one).
  // -------------------------------------------------------------------------
  test('local progress newer leaves DB intact and pushes the local progress',
      () async {
    await h.seedLocalBook(
      id: 'book-1',
      syncFileName: 'book-1.epub',
      lastReadAt: DateTime(2026, 3, 1),
    );
    final localProgressTs = DateTime(2026, 3, 1, 12, 0, 0);
    await h.seedLocalProgress(
      bookId: 'book-1',
      chapterIndex: 5,
      wordIndex: 800,
      wpm: 350,
      readerMode: 'rsvp',
      updatedAt: localProgressTs,
    );
    // Remote progress is older (an earlier month), behind in the book.
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        updatedAt: DateTime.utc(2026, 1, 1),
        progress: SyncLibraryProgress(
          chapterIndex: 1,
          wordIndex: 20,
          wpm: 300,
          updatedAt: DateTime.utc(2026, 1, 1, 9, 0, 0),
          readerMode: 'ereader',
        ),
      ),
    ]);

    await h.runSync();

    // DB still carries the local (winning) progress, byte for byte.
    final prog = await h.db.readingProgressDao.getProgressForBook('book-1');
    expect(prog!.chapterIndex, 5);
    expect(prog.wordIndex, 800);
    expect(prog.wpm, 350);
    expect(prog.readerMode, 'rsvp');
    expect(prog.updatedAt.isAtSameMomentAs(localProgressTs), isTrue);

    // The pushed shard reflects the local progress winning the merge.
    final pushed = h.readBooksShard()!.books.single;
    expect(pushed.progress!.wordIndex, 800);
    expect(pushed.progress!.chapterIndex, 5);
    expect(pushed.progress!.readerMode, 'rsvp');
    expect(pushed.progress!.updatedAt.isAtSameMomentAs(localProgressTs), isTrue);
  });

  // -------------------------------------------------------------------------
  // 4a. lastReadAt remote newer -> setLastReadAt applied to the DB.
  // -------------------------------------------------------------------------
  test('remote lastReadAt newer is applied via setLastReadAt', () async {
    await h.seedLocalBook(
      id: 'book-1',
      syncFileName: 'book-1.epub',
      lastReadAt: DateTime(2026, 1, 1, 8, 0, 0),
    );
    final remoteLastRead = DateTime.utc(2026, 5, 1, 8, 0, 0);
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        lastReadAt: remoteLastRead,
        updatedAt: DateTime.utc(2026, 5, 1, 8, 0, 0),
      ),
    ]);

    await h.runSync();

    final book = await h.db.booksDao.getBookById('book-1');
    expect(book!.lastReadAt, isNotNull);
    expect(book.lastReadAt!.isAtSameMomentAs(remoteLastRead), isTrue);
  });

  // -------------------------------------------------------------------------
  // 4b. lastReadAt at the same instant (UTC remote vs local-TZ local) -> no
  //     change. This is the isAtSameMomentAs invariant: the same absolute
  //     instant must not produce a DB write or a books-shard rewrite even
  //     though one side is local-TZ (Drift) and the other UTC (JSON). We
  //     establish the remote shard from the local data on a first sync (so it
  //     carries exactly the local instants, converted to UTC), then assert the
  //     second sync is a no-op — independent of the runner's TZ offset.
  // -------------------------------------------------------------------------
  test('lastReadAt at the same instant produces no books-shard rewrite',
      () async {
    final localLastRead = DateTime(2026, 1, 1, 8, 0, 0);
    await h.seedLocalBook(
      id: 'book-1',
      syncFileName: 'book-1.epub',
      lastReadAt: localLastRead,
    );
    await h.seedLocalProgress(
      bookId: 'book-1',
      wordIndex: 5,
      readerMode: 'rsvp',
      updatedAt: DateTime(2026, 1, 1, 8, 0, 0),
    );

    // First sync writes the books shard derived from the local instants.
    await h.runSync();
    expect(h.gateway.writeLog, contains(kBooksShardFile));
    h.gateway.writeLog.clear();

    // Second sync: remote shard now names the same instants as UTC; local DB
    // still local-TZ. Same instant -> no rewrite, no DB bump.
    await h.runSync();

    final book = await h.db.booksDao.getBookById('book-1');
    expect(book!.lastReadAt!.isAtSameMomentAs(localLastRead), isTrue);
    expect(h.gateway.writeLog, isNot(contains(kBooksShardFile)),
        reason: 'identical instant must not trigger a books-shard rewrite');
  });

  // -------------------------------------------------------------------------
  // 5a. Rating LWW: remote ratingUpdatedAt newer -> remote rating wins in DB.
  // -------------------------------------------------------------------------
  test('remote rating with newer ratingUpdatedAt is applied to the DB',
      () async {
    await h.seedLocalBook(
      id: 'book-1',
      syncFileName: 'book-1.epub',
      rating: 2,
      ratingUpdatedAt: DateTime(2026, 1, 1),
    );
    final remoteRatingTs = DateTime.utc(2026, 6, 1);
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        updatedAt: DateTime.utc(2026, 6, 1),
        rating: 5,
        ratingUpdatedAt: remoteRatingTs,
      ),
    ]);

    await h.runSync();

    final book = await h.db.booksDao.getBookById('book-1');
    expect(book!.rating, 5);
    expect(book.ratingUpdatedAt!.isAtSameMomentAs(remoteRatingTs), isTrue);
  });

  // -------------------------------------------------------------------------
  // 5b. Rating LWW: remote ratingUpdatedAt older -> local rating survives in
  //     the DB and the pushed shard carries the local (winning) rating.
  // -------------------------------------------------------------------------
  test('older remote rating does not overwrite local; push carries local',
      () async {
    final localRatingTs = DateTime(2026, 6, 1);
    await h.seedLocalBook(
      id: 'book-1',
      syncFileName: 'book-1.epub',
      rating: 4,
      ratingUpdatedAt: localRatingTs,
    );
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        updatedAt: DateTime.utc(2026, 6, 1),
        rating: 1,
        ratingUpdatedAt: DateTime.utc(2026, 1, 1), // older
      ),
    ]);

    await h.runSync();

    final book = await h.db.booksDao.getBookById('book-1');
    expect(book!.rating, 4, reason: 'local rating wins LWW');
    expect(book.ratingUpdatedAt!.isAtSameMomentAs(localRatingTs), isTrue);

    final pushed = h.readBooksShard()!.books.single;
    expect(pushed.rating, 4);
    expect(pushed.ratingUpdatedAt!.isAtSameMomentAs(localRatingTs), isTrue);
  });

  // -------------------------------------------------------------------------
  // 5c. Rating survives an unrelated field bump: remote has newer lastReadAt
  //     (which gets applied) but an older/absent rating -> the local rating
  //     is untouched because its own ratingUpdatedAt governs the merge.
  // -------------------------------------------------------------------------
  test('local rating survives a remote lastReadAt bump (per-field LWW)',
      () async {
    final localRatingTs = DateTime(2026, 6, 1);
    await h.seedLocalBook(
      id: 'book-1',
      syncFileName: 'book-1.epub',
      lastReadAt: DateTime(2026, 1, 1, 8, 0, 0),
      rating: 3,
      ratingUpdatedAt: localRatingTs,
    );
    final remoteLastRead = DateTime.utc(2026, 7, 1, 8, 0, 0);
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'book-1',
        syncFileName: 'book-1.epub',
        lastReadAt: remoteLastRead,
        updatedAt: DateTime.utc(2026, 7, 1, 8, 0, 0),
        // Remote never rated this book.
        rating: null,
        ratingUpdatedAt: null,
      ),
    ]);

    await h.runSync();

    final book = await h.db.booksDao.getBookById('book-1');
    // lastReadAt bumped...
    expect(book!.lastReadAt!.isAtSameMomentAs(remoteLastRead), isTrue);
    // ...but rating untouched (its own timestamp wins).
    expect(book.rating, 3);
    expect(book.ratingUpdatedAt!.isAtSameMomentAs(localRatingTs), isTrue);
  });

  // -------------------------------------------------------------------------
  // 6a. Settings: remote settings updatedAt newer than localSettingsUpdatedAt
  //     -> applySettings is invoked with the remote values.
  // -------------------------------------------------------------------------
  test('remote settings newer than local triggers applySettings with remote '
      'values', () async {
    // Local prefs say wpm 300, stamped old.
    h.localSettings = const DisplaySettings(wpm: 300);
    // Remote settings shard with wpm 555, stamped newer.
    final remoteSettingsTs = DateTime.utc(2026, 5, 1);
    h.gateway.textFiles[kSettingsShardFile] = SyncSettingsShard(
      updatedAt: remoteSettingsTs,
      updatedBy: 'device-remote',
      settings: SyncLibrarySettings(
        values: const {'wpm': 555},
        updatedAt: remoteSettingsTs,
      ),
    ).encode();

    await h.runSync(localSettingsUpdatedAt: DateTime(2026, 1, 1));

    expect(h.appliedSettings, isNotNull);
    expect(h.appliedSettings!.wpm, 555);
  });

  // -------------------------------------------------------------------------
  // 6b. Settings: local settings updatedAt newer -> applySettings NOT called,
  //     and the pushed settings shard carries the local values.
  // -------------------------------------------------------------------------
  test('local settings newer skips applySettings and pushes local values',
      () async {
    h.localSettings = const DisplaySettings(wpm: 420);
    // Remote settings stamped old.
    h.gateway.textFiles[kSettingsShardFile] = SyncSettingsShard(
      updatedAt: DateTime.utc(2026, 1, 1),
      updatedBy: 'device-remote',
      settings: SyncLibrarySettings(
        values: const {'wpm': 100},
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ).encode();

    // Local settings are newer than the remote snapshot.
    await h.runSync(localSettingsUpdatedAt: DateTime(2026, 9, 1));

    expect(h.appliedSettings, isNull,
        reason: 'local settings win, nothing to apply locally');
    // The merged (local-winning) settings are pushed back.
    final pushedRaw = h.gateway.textFiles[kSettingsShardFile]!;
    final pushed = SyncSettingsShard.decode(pushedRaw);
    expect(pushed.settings!.values['wpm'], 420);
  });

  // -------------------------------------------------------------------------
  // 7. New remote book with syncEpubs=false -> placeholder row inserted
  //    (empty filePath, zero cached tokens) and the remote progress applied.
  // -------------------------------------------------------------------------
  test('new remote book with EPUB sync off inserts a placeholder + progress',
      () async {
    await h.dispose();
    h = SyncServiceHarness();
    await h.init(syncEpubs: false);

    final remoteProgressTs = DateTime.utc(2026, 4, 1, 10, 0, 0);
    h.putBooksShard([
      h.makeRemoteBook(
        id: 'remote-only',
        title: 'Cloud Book',
        author: 'Cloud Author',
        totalWords: 1234,
        chapterCount: 7,
        syncFileName: 'remote-only.epub',
        updatedAt: DateTime.utc(2026, 4, 1),
        progress: SyncLibraryProgress(
          chapterIndex: 2,
          wordIndex: 88,
          wpm: 360,
          updatedAt: remoteProgressTs,
          readerMode: 'tts',
        ),
      ),
    ]);

    await h.runSync();

    // Placeholder book row: metadata present, filePath empty, no tokens.
    final book = await h.db.booksDao.getBookById('remote-only');
    expect(book, isNotNull);
    expect(book!.title, 'Cloud Book');
    expect(book.author, 'Cloud Author');
    expect(book.totalWords, 1234);
    expect(book.chapterCount, 7);
    expect(book.filePath, isEmpty);
    expect(book.syncFileName, 'remote-only.epub');

    final tokens = await h.db.cachedTokensDao.getTokensForBook('remote-only');
    expect(tokens, isEmpty);

    // Remote progress applied verbatim.
    final prog =
        await h.db.readingProgressDao.getProgressForBook('remote-only');
    expect(prog, isNotNull);
    expect(prog!.chapterIndex, 2);
    expect(prog.wordIndex, 88);
    expect(prog.wpm, 360);
    expect(prog.readerMode, 'tts');
    expect(prog.updatedAt.isAtSameMomentAs(remoteProgressTs), isTrue);
  });

  // -------------------------------------------------------------------------
  // Tiebreak pin (mutation-testing follow-up). mergeBooksShard passes the
  // LOCAL shard as `a`, and mergeProgress returns `a` on an exact tie, so a
  // remote progress carrying the SAME instant never reaches progressDiffers
  // as a cross-TZ (UTC vs local) pair — the merged object IS the local one.
  // That ordering is what currently makes the isAtSameMomentAs and
  // readerMode terms in progressDiffers defence-in-depth rather than
  // load-bearing. If this test ever fails, the merge tiebreak flipped and
  // those terms became the only guard — extend the mutation coverage there.
  // -------------------------------------------------------------------------
  test('exact-instant tie keeps local progress: mode-only remote flip is '
      'not applied', () async {
    await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
    await h.seedLocalProgress(
      bookId: 'book-1',
      chapterIndex: 2,
      wordIndex: 50,
      wpm: 300,
      readerMode: 'rsvp',
      updatedAt: DateTime(2026, 1, 1, 10, 0, 0),
    );
    // First sync materializes the remote shard from the local instants.
    await h.runSync();

    // Flip ONLY readerMode remotely, keeping every timestamp identical.
    final pushed = h.readBooksShard()!;
    final book = pushed.books.single;
    h.putBooksShard(
      [
        book.copyWith(
          progress: SyncLibraryProgress(
            chapterIndex: book.progress!.chapterIndex,
            wordIndex: book.progress!.wordIndex,
            wpm: book.progress!.wpm,
            updatedAt: book.progress!.updatedAt,
            readerMode: 'ereader',
          ),
        ),
      ],
      updatedAt: pushed.updatedAt,
      updatedBy: pushed.updatedBy,
    );

    await h.runSync();

    final prog = await h.db.readingProgressDao.getProgressForBook('book-1');
    expect(prog!.readerMode, 'rsvp',
        reason: 'exact ties resolve to the local side of the merge');
  });

  // -------------------------------------------------------------------------
  // Net-effect pin: a second sync over identical state performs ZERO writes
  // to the reading_progress table — not even redundant same-value upserts.
  // Complements the shard-level idempotency test in sync_service_basics by
  // watching the database side through Drift's table update stream.
  // -------------------------------------------------------------------------
  test('second sync over identical state performs zero progress-table writes',
      () async {
    await h.seedLocalBook(id: 'book-1', syncFileName: 'book-1.epub');
    await h.seedLocalProgress(
      bookId: 'book-1',
      chapterIndex: 1,
      wordIndex: 25,
      readerMode: 'rsvp',
      updatedAt: DateTime(2026, 1, 1, 10, 0, 0),
    );
    await h.runSync();

    final updates = <TableUpdate>[];
    final sub = h.db
        .tableUpdates(TableUpdateQuery.onTable(h.db.readingProgressTable))
        .listen(updates.addAll);

    await h.runSync();
    await sub.cancel();

    expect(updates, isEmpty,
        reason: 'an unchanged book must not produce DB writes on re-sync');
  });
}
