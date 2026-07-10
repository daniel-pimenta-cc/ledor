import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/library_sync/domain/entities/sync_library.dart';

DateTime _t(int offsetSec) =>
    DateTime.utc(2026, 1, 1).add(Duration(seconds: offsetSec));

SyncLibraryBook _book({
  required String id,
  String title = 'Book',
  int totalWords = 1000,
  DateTime? importedAt,
  DateTime? lastReadAt,
  bool hasEpubFile = false,
  String? syncFileName,
  SyncLibraryProgress? progress,
  DateTime? deletedAt,
  required int updatedAtSec,
  int? rating,
  DateTime? ratingUpdatedAt,
}) {
  return SyncLibraryBook(
    id: id,
    title: title,
    author: 'Author',
    totalWords: totalWords,
    chapterCount: 5,
    importedAt: importedAt ?? _t(0),
    lastReadAt: lastReadAt,
    hasEpubFile: hasEpubFile,
    syncFileName: syncFileName,
    progress: progress,
    deletedAt: deletedAt,
    updatedAt: _t(updatedAtSec),
    rating: rating,
    ratingUpdatedAt: ratingUpdatedAt,
  );
}

SyncLibraryProgress _progress({
  int chapter = 0,
  int word = 0,
  int wpm = 300,
  required int atSec,
}) {
  return SyncLibraryProgress(
    chapterIndex: chapter,
    wordIndex: word,
    wpm: wpm,
    updatedAt: _t(atSec),
  );
}

void main() {
  group('mergeProgress', () {
    test('takes the non-null when one side is null', () {
      final p = _progress(chapter: 1, word: 10, atSec: 100);
      expect(mergeProgress(null, p), equals(p));
      expect(mergeProgress(p, null), equals(p));
    });

    test('last-write-wins when timestamps differ by more than 60s', () {
      final older = _progress(chapter: 5, word: 500, atSec: 0);
      final newer = _progress(chapter: 0, word: 10, atSec: 120);
      expect(mergeProgress(older, newer), newer);
      expect(mergeProgress(newer, older), newer);
    });

    test('within 60s prefers higher progress (wordIndex tiebreaker)', () {
      final a = _progress(chapter: 2, word: 100, atSec: 100);
      final b = _progress(chapter: 2, word: 200, atSec: 130);
      expect(mergeProgress(a, b), b);
      expect(mergeProgress(b, a), b);
    });

    test('within 60s with different chapters prefers higher chapter', () {
      final a = _progress(chapter: 3, word: 50, atSec: 100);
      final b = _progress(chapter: 2, word: 500, atSec: 110);
      expect(mergeProgress(a, b), a);
    });
  });

  group('mergeBook', () {
    test('later updatedAt wins on title', () {
      final a = _book(id: 'x', title: 'Old', updatedAtSec: 0);
      final b = _book(id: 'x', title: 'New', updatedAtSec: 100);
      final merged = mergeBook(a, b);
      expect(merged.title, 'New');
    });

    test('earliest importedAt is preserved', () {
      final a = _book(id: 'x', importedAt: _t(0), updatedAtSec: 100);
      final b = _book(id: 'x', importedAt: _t(500), updatedAtSec: 200);
      final merged = mergeBook(a, b);
      expect(merged.importedAt, _t(0));
    });

    test('later lastReadAt wins', () {
      final a = _book(id: 'x', lastReadAt: _t(10), updatedAtSec: 100);
      final b = _book(id: 'x', lastReadAt: _t(50), updatedAtSec: 20);
      expect(mergeBook(a, b).lastReadAt, _t(50));
    });

    test('hasEpubFile is OR of both sides', () {
      final a = _book(id: 'x', hasEpubFile: true, updatedAtSec: 0);
      final b = _book(id: 'x', hasEpubFile: false, updatedAtSec: 100);
      expect(mergeBook(a, b).hasEpubFile, isTrue);
    });

    test('progress is merged with wordIndex tiebreaker', () {
      final a = _book(
        id: 'x',
        progress: _progress(chapter: 2, word: 500, atSec: 100),
        updatedAtSec: 100,
      );
      final b = _book(
        id: 'x',
        progress: _progress(chapter: 2, word: 800, atSec: 130),
        updatedAtSec: 130,
      );
      expect(mergeBook(a, b).progress!.wordIndex, 800);
    });

    test('tombstone: deletedAt on either side wins', () {
      final a = _book(id: 'x', deletedAt: _t(100), updatedAtSec: 100);
      final b = _book(id: 'x', updatedAtSec: 200);
      expect(mergeBook(a, b).deletedAt, _t(100));
    });

    test('syncFileName: propagates from whichever side has it', () {
      final a = _book(id: 'x', updatedAtSec: 0);
      final b = _book(id: 'x', syncFileName: 'moby.epub', updatedAtSec: 100);
      expect(mergeBook(a, b).syncFileName, 'moby.epub');
      expect(mergeBook(b, a).syncFileName, 'moby.epub');
    });

    test('syncFileName: newer wins when both sides set it', () {
      final a = _book(
          id: 'x', syncFileName: 'old.epub', updatedAtSec: 50);
      final b = _book(
          id: 'x', syncFileName: 'new.epub', updatedAtSec: 100);
      expect(mergeBook(a, b).syncFileName, 'new.epub');
    });
  });

  group('legacy monolith decode', () {
    test('decodes a legacy library.json payload', () {
      // The app only ever DECODES the legacy monolith (one-shot migration),
      // so the fixture is a raw JSON map — there is no production encoder.
      final raw = jsonEncode({
        'schemaVersion': 1,
        'updatedAt': _t(100).toIso8601String(),
        'updatedBy': 'dev-1',
        'settings': {
          'values': {'wpm': 350, 'font': 'Inter'},
          'updatedAt': _t(90).toIso8601String(),
        },
        'books': [
          _book(
            id: 'b1',
            title: 'Hello',
            progress: _progress(chapter: 1, word: 42, atSec: 80),
            lastReadAt: _t(85),
            hasEpubFile: true,
            syncFileName: 'hello.epub',
            updatedAtSec: 100,
          ).toJson(),
          _book(id: 'b2', deletedAt: _t(90), updatedAtSec: 95).toJson(),
        ],
      });
      final decoded = SyncLibrary.decode(raw);
      expect(decoded.books.length, 2);
      expect(decoded.books[0].id, 'b1');
      expect(decoded.books[0].progress!.wordIndex, 42);
      expect(decoded.books[0].hasEpubFile, isTrue);
      expect(decoded.books[0].syncFileName, 'hello.epub');
      expect(decoded.books[1].deletedAt, _t(90));
      expect(decoded.settings!.values['wpm'], 350);
      expect(decoded.updatedBy, 'dev-1');
    });
  });

  group('mergeBook rating', () {
    test('keeps the side whose ratingUpdatedAt is newer', () {
      final a = _book(
        id: 'b1',
        updatedAtSec: 100,
        rating: 4,
        ratingUpdatedAt: _t(50),
      );
      final b = _book(
        id: 'b1',
        updatedAtSec: 100,
        rating: 5,
        ratingUpdatedAt: _t(80),
      );
      expect(mergeBook(a, b).rating, 5);
      expect(mergeBook(a, b).ratingUpdatedAt, _t(80));
    });

    test('preserves rating across unrelated metadata bumps', () {
      // Rating set on device A at t=50, but device B later bumped progress at
      // t=200 (parent updatedAt) without rating. Rating must survive.
      final a = _book(
        id: 'b1',
        updatedAtSec: 100,
        rating: 4,
        ratingUpdatedAt: _t(50),
      );
      final b = _book(
        id: 'b1',
        updatedAtSec: 200,
        rating: null,
        ratingUpdatedAt: null,
      );
      expect(mergeBook(a, b).rating, 4);
      expect(mergeBook(a, b).ratingUpdatedAt, _t(50));
    });

    test('null on both sides yields null rating', () {
      final a = _book(id: 'b1', updatedAtSec: 100);
      final b = _book(id: 'b1', updatedAtSec: 200);
      expect(mergeBook(a, b).rating, isNull);
      expect(mergeBook(a, b).ratingUpdatedAt, isNull);
    });
  });

  group('mergeSessionsShard', () {
    test('unions sessions by id, never duplicates', () {
      final s1 = _session(id: 's1', bookId: 'b1', startedAtSec: 10);
      final s2 = _session(id: 's2', bookId: 'b1', startedAtSec: 20);
      final s3 = _session(id: 's3', bookId: 'b2', startedAtSec: 30);
      final a = SyncSessionsShard(
        updatedAt: _t(0),
        updatedBy: 'a',
        sessions: [s1, s2],
      );
      final b = SyncSessionsShard(
        updatedAt: _t(0),
        updatedBy: 'b',
        sessions: [s2, s3],
      );
      final merged = mergeSessionsShard(a, b, 'd');
      expect(merged.sessions.map((s) => s.id).toList(), ['s1', 's2', 's3']);
    });

    test('rolls a side as-is when the other is empty', () {
      final s = _session(id: 's1', bookId: 'b1', startedAtSec: 10);
      final a = SyncSessionsShard(
        updatedAt: _t(0),
        updatedBy: 'a',
        sessions: [s],
      );
      final b = SyncSessionsShard.empty('b');
      final merged = mergeSessionsShard(a, b, 'd');
      expect(merged.sessions.length, 1);
      expect(merged.sessions[0].id, 's1');
    });
  });

  group('SyncBooksShard roundtrip', () {
    test('encode + decode preserves rating fields', () {
      final shard = SyncBooksShard(
        updatedAt: _t(0),
        updatedBy: 'dev-1',
        books: [
          _book(
            id: 'b1',
            updatedAtSec: 10,
            rating: 5,
            ratingUpdatedAt: _t(5),
          ),
        ],
      );
      final round = SyncBooksShard.decode(shard.encode());
      expect(round.books[0].rating, 5);
      expect(round.books[0].ratingUpdatedAt, _t(5));
    });
  });

  group('SyncSessionsShard roundtrip', () {
    test('encode + decode preserves session fields', () {
      final shard = SyncSessionsShard(
        updatedAt: _t(0),
        updatedBy: 'dev-1',
        sessions: [
          _session(id: 's1', bookId: 'b1', startedAtSec: 100),
        ],
      );
      final round = SyncSessionsShard.decode(shard.encode());
      expect(round.sessions[0].id, 's1');
      expect(round.sessions[0].bookId, 'b1');
      expect(round.sessions[0].startedAt, _t(100));
    });
  });
}

SyncReadingSession _session({
  required String id,
  required String bookId,
  required int startedAtSec,
  int durationMs = 60000,
  int wordsRead = 200,
}) {
  return SyncReadingSession(
    id: id,
    bookId: bookId,
    startedAt: _t(startedAtSec),
    endedAt: _t(startedAtSec + 60),
    durationMs: durationMs,
    wordsRead: wordsRead,
    startWordIndex: 0,
    endWordIndex: wordsRead,
    avgWpm: 300,
  );
}
