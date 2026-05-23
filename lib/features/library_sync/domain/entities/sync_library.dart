import 'dart:convert';

/// Schema version of the legacy monolithic `library.json` manifest.
const syncSchemaVersion = 1;

/// Schema version of each new shard file (books/settings/sessions). Bumped
/// together when any shard's on-disk format changes.
const syncShardSchemaVersion = 1;

class SyncLibraryProgress {
  final int chapterIndex;
  final int wordIndex;
  final int wpm;
  final DateTime updatedAt;

  /// Persisted reader-mode tag (`'rsvp'` / `'ereader'` / `'tts'`). Null
  /// for rows that predate the schema bump or never had a mode selected
  /// — the local engine treats null as "default" (scroll/RSVP).
  final String? readerMode;

  const SyncLibraryProgress({
    required this.chapterIndex,
    required this.wordIndex,
    required this.wpm,
    required this.updatedAt,
    this.readerMode,
  });

  Map<String, dynamic> toJson() => {
        'chapterIndex': chapterIndex,
        'wordIndex': wordIndex,
        'wpm': wpm,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (readerMode != null) 'readerMode': readerMode,
      };

  factory SyncLibraryProgress.fromJson(Map<String, dynamic> json) =>
      SyncLibraryProgress(
        chapterIndex: json['chapterIndex'] as int,
        wordIndex: json['wordIndex'] as int,
        wpm: json['wpm'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        readerMode: json['readerMode'] as String?,
      );
}

class SyncLibraryBook {
  final String id;
  final String title;
  final String? author;
  final int totalWords;
  final int chapterCount;
  final DateTime importedAt;
  final DateTime? lastReadAt;
  final bool hasEpubFile;
  final String? syncFileName;
  final SyncLibraryProgress? progress;
  final DateTime? deletedAt;
  final DateTime updatedAt;

  /// Reader's rating, 1..5 or null.
  final int? rating;

  /// Per-field timestamp so rating merges via LWW without being clobbered
  /// when an unrelated field (progress, lastReadAt) bumps [updatedAt] later
  /// on another device. Null when the book was never rated on any device
  /// or when the row predates v7 of the local schema.
  final DateTime? ratingUpdatedAt;

  const SyncLibraryBook({
    required this.id,
    required this.title,
    this.author,
    required this.totalWords,
    required this.chapterCount,
    required this.importedAt,
    this.lastReadAt,
    required this.hasEpubFile,
    this.syncFileName,
    this.progress,
    this.deletedAt,
    required this.updatedAt,
    this.rating,
    this.ratingUpdatedAt,
  });

  SyncLibraryBook copyWith({
    String? title,
    String? author,
    int? totalWords,
    int? chapterCount,
    DateTime? importedAt,
    DateTime? lastReadAt,
    bool? hasEpubFile,
    String? syncFileName,
    SyncLibraryProgress? progress,
    DateTime? deletedAt,
    DateTime? updatedAt,
    int? rating,
    DateTime? ratingUpdatedAt,
  }) {
    return SyncLibraryBook(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      totalWords: totalWords ?? this.totalWords,
      chapterCount: chapterCount ?? this.chapterCount,
      importedAt: importedAt ?? this.importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      hasEpubFile: hasEpubFile ?? this.hasEpubFile,
      syncFileName: syncFileName ?? this.syncFileName,
      progress: progress ?? this.progress,
      deletedAt: deletedAt ?? this.deletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      ratingUpdatedAt: ratingUpdatedAt ?? this.ratingUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'totalWords': totalWords,
        'chapterCount': chapterCount,
        'importedAt': importedAt.toUtc().toIso8601String(),
        'lastReadAt': lastReadAt?.toUtc().toIso8601String(),
        'hasEpubFile': hasEpubFile,
        'syncFileName': syncFileName,
        'progress': progress?.toJson(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'rating': rating,
        'ratingUpdatedAt': ratingUpdatedAt?.toUtc().toIso8601String(),
      };

  factory SyncLibraryBook.fromJson(Map<String, dynamic> json) =>
      SyncLibraryBook(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String?,
        totalWords: json['totalWords'] as int? ?? 0,
        chapterCount: json['chapterCount'] as int? ?? 0,
        importedAt: DateTime.parse(json['importedAt'] as String),
        lastReadAt: json['lastReadAt'] == null
            ? null
            : DateTime.parse(json['lastReadAt'] as String),
        hasEpubFile: json['hasEpubFile'] as bool? ?? false,
        syncFileName: json['syncFileName'] as String?,
        progress: json['progress'] == null
            ? null
            : SyncLibraryProgress.fromJson(
                json['progress'] as Map<String, dynamic>),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        rating: (json['rating'] as num?)?.toInt(),
        ratingUpdatedAt: json['ratingUpdatedAt'] == null
            ? null
            : DateTime.parse(json['ratingUpdatedAt'] as String),
      );
}

class SyncLibrarySettings {
  final Map<String, dynamic> values;
  final DateTime updatedAt;

  const SyncLibrarySettings({
    required this.values,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'values': values,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory SyncLibrarySettings.fromJson(Map<String, dynamic> json) =>
      SyncLibrarySettings(
        values: Map<String, dynamic>.from(json['values'] as Map),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class SyncLibrary {
  final int schemaVersion;
  final DateTime updatedAt;
  final String updatedBy;
  final SyncLibrarySettings? settings;
  final List<SyncLibraryBook> books;

  const SyncLibrary({
    this.schemaVersion = syncSchemaVersion,
    required this.updatedAt,
    required this.updatedBy,
    this.settings,
    required this.books,
  });

  factory SyncLibrary.empty(String deviceId) => SyncLibrary(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedBy: deviceId,
        books: const [],
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'updatedBy': updatedBy,
        'settings': settings?.toJson(),
        'books': books.map((b) => b.toJson()).toList(),
      };

  factory SyncLibrary.fromJson(Map<String, dynamic> json) => SyncLibrary(
        schemaVersion: json['schemaVersion'] as int? ?? syncSchemaVersion,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        updatedBy: json['updatedBy'] as String? ?? '',
        settings: json['settings'] == null
            ? null
            : SyncLibrarySettings.fromJson(
                json['settings'] as Map<String, dynamic>),
        books: (json['books'] as List? ?? const [])
            .map((b) => SyncLibraryBook.fromJson(b as Map<String, dynamic>))
            .toList(),
      );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SyncLibrary.decode(String raw) =>
      SyncLibrary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Merge two books by their per-field updatedAt.
/// Returns the merged book. Caller must pass books with the same id.
SyncLibraryBook mergeBook(SyncLibraryBook a, SyncLibraryBook b) {
  assert(a.id == b.id);
  final newer = a.updatedAt.isAfter(b.updatedAt) ? a : b;
  final older = identical(newer, a) ? b : a;

  final mergedProgress = mergeProgress(a.progress, b.progress);
  final mergedDeletedAt = _laterNullable(a.deletedAt, b.deletedAt);
  final mergedRating = _mergeRating(
    a.rating, a.ratingUpdatedAt,
    b.rating, b.ratingUpdatedAt,
  );

  return SyncLibraryBook(
    id: a.id,
    title: newer.title,
    author: newer.author ?? older.author,
    totalWords: newer.totalWords != 0 ? newer.totalWords : older.totalWords,
    chapterCount:
        newer.chapterCount != 0 ? newer.chapterCount : older.chapterCount,
    importedAt: _earlier(a.importedAt, b.importedAt),
    lastReadAt: _laterNullable(a.lastReadAt, b.lastReadAt),
    hasEpubFile: a.hasEpubFile || b.hasEpubFile,
    syncFileName: newer.syncFileName ?? older.syncFileName,
    progress: mergedProgress,
    deletedAt: mergedDeletedAt,
    updatedAt: _later(a.updatedAt, b.updatedAt),
    rating: mergedRating.$1,
    ratingUpdatedAt: mergedRating.$2,
  );
}

/// LWW on rating using its dedicated timestamp. When one side has no
/// timestamp (legacy data from before v7), the side with a timestamp wins
/// if it has a rating; otherwise the rated side wins. Returns a tuple of
/// `(rating, ratingUpdatedAt)` so callers can apply both atomically.
(int?, DateTime?) _mergeRating(
  int? aRating,
  DateTime? aAt,
  int? bRating,
  DateTime? bAt,
) {
  if (aAt == null && bAt == null) {
    // No timestamps anywhere — accept whichever side has a rating; if both
    // do, prefer `a` (deterministic but arbitrary; both sides agree).
    return (aRating ?? bRating, null);
  }
  if (aAt == null) return (bRating, bAt);
  if (bAt == null) return (aRating, aAt);
  return aAt.isAfter(bAt) ? (aRating, aAt) : (bRating, bAt);
}

/// Merge progress records. LWW by updatedAt, with a 60s tiebreaker:
/// if timestamps are within 60s of each other, prefer the larger wordIndex
/// so progress never goes backwards.
SyncLibraryProgress? mergeProgress(
  SyncLibraryProgress? a,
  SyncLibraryProgress? b,
) {
  if (a == null) return b;
  if (b == null) return a;

  final diff = a.updatedAt.difference(b.updatedAt).abs();
  if (diff.inSeconds <= 60) {
    return _globalOrder(a) >= _globalOrder(b) ? a : b;
  }
  return a.updatedAt.isAfter(b.updatedAt) ? a : b;
}

/// Orders progress records without knowledge of chapter word counts:
/// chapterIndex dominates, wordIndex breaks ties.
int _globalOrder(SyncLibraryProgress p) => p.chapterIndex * 1000000 + p.wordIndex;

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime? _laterNullable(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return _later(a, b);
}

/// Merge two libraries. Result contains the union of books, each merged,
/// and the newer of the two settings snapshots.
SyncLibrary mergeLibraries(SyncLibrary a, SyncLibrary b, String deviceId) {
  final byId = <String, SyncLibraryBook>{};
  for (final book in a.books) {
    byId[book.id] = book;
  }
  for (final book in b.books) {
    final existing = byId[book.id];
    byId[book.id] = existing == null ? book : mergeBook(existing, book);
  }

  SyncLibrarySettings? settings;
  if (a.settings == null) {
    settings = b.settings;
  } else if (b.settings == null) {
    settings = a.settings;
  } else {
    settings = a.settings!.updatedAt.isAfter(b.settings!.updatedAt)
        ? a.settings
        : b.settings;
  }

  return SyncLibrary(
    updatedAt: _later(a.updatedAt, b.updatedAt),
    updatedBy: deviceId,
    settings: settings,
    books: byId.values.toList()..sort((x, y) => x.id.compareTo(y.id)),
  );
}

// ---------------------------------------------------------------------------
// Sharded manifest (current format). The monolithic SyncLibrary above is kept
// only for one-shot migration off of `library.json`.
// ---------------------------------------------------------------------------

/// Books shard: `library/books.json`. Carries the same per-book records as
/// the legacy manifest plus the new rating fields, with its own meta block.
class SyncBooksShard {
  final int schemaVersion;
  final DateTime updatedAt;
  final String updatedBy;
  final List<SyncLibraryBook> books;

  const SyncBooksShard({
    this.schemaVersion = syncShardSchemaVersion,
    required this.updatedAt,
    required this.updatedBy,
    required this.books,
  });

  factory SyncBooksShard.empty(String deviceId) => SyncBooksShard(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedBy: deviceId,
        books: const [],
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'updatedBy': updatedBy,
        'books': books.map((b) => b.toJson()).toList(),
      };

  factory SyncBooksShard.fromJson(Map<String, dynamic> json) => SyncBooksShard(
        schemaVersion:
            json['schemaVersion'] as int? ?? syncShardSchemaVersion,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        updatedBy: json['updatedBy'] as String? ?? '',
        books: (json['books'] as List? ?? const [])
            .map((b) => SyncLibraryBook.fromJson(b as Map<String, dynamic>))
            .toList(),
      );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SyncBooksShard.decode(String raw) =>
      SyncBooksShard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Settings shard: `library/settings.json`. Just the [SyncLibrarySettings]
/// payload wrapped in shard meta. We keep settings in its own file so a UI
/// tweak doesn't force a re-upload of books or sessions.
class SyncSettingsShard {
  final int schemaVersion;
  final DateTime updatedAt;
  final String updatedBy;
  final SyncLibrarySettings? settings;

  const SyncSettingsShard({
    this.schemaVersion = syncShardSchemaVersion,
    required this.updatedAt,
    required this.updatedBy,
    this.settings,
  });

  factory SyncSettingsShard.empty(String deviceId) => SyncSettingsShard(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedBy: deviceId,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'updatedBy': updatedBy,
        'settings': settings?.toJson(),
      };

  factory SyncSettingsShard.fromJson(Map<String, dynamic> json) =>
      SyncSettingsShard(
        schemaVersion:
            json['schemaVersion'] as int? ?? syncShardSchemaVersion,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        updatedBy: json['updatedBy'] as String? ?? '',
        settings: json['settings'] == null
            ? null
            : SyncLibrarySettings.fromJson(
                json['settings'] as Map<String, dynamic>),
      );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SyncSettingsShard.decode(String raw) =>
      SyncSettingsShard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Per-row record for a reading session. Sessions never mutate after insert,
/// so they're append-only by id — merging across devices is just a set union.
class SyncReadingSession {
  final String id;
  final String bookId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMs;
  final int wordsRead;
  final int startWordIndex;
  final int endWordIndex;
  final int avgWpm;

  const SyncReadingSession({
    required this.id,
    required this.bookId,
    required this.startedAt,
    required this.endedAt,
    required this.durationMs,
    required this.wordsRead,
    required this.startWordIndex,
    required this.endWordIndex,
    required this.avgWpm,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'durationMs': durationMs,
        'wordsRead': wordsRead,
        'startWordIndex': startWordIndex,
        'endWordIndex': endWordIndex,
        'avgWpm': avgWpm,
      };

  factory SyncReadingSession.fromJson(Map<String, dynamic> json) =>
      SyncReadingSession(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        durationMs: (json['durationMs'] as num).toInt(),
        wordsRead: (json['wordsRead'] as num).toInt(),
        startWordIndex: (json['startWordIndex'] as num).toInt(),
        endWordIndex: (json['endWordIndex'] as num).toInt(),
        avgWpm: (json['avgWpm'] as num).toInt(),
      );
}

/// Sessions shard: `library/sessions.json`. Append-only by id. We keep this
/// in one file (not per-book) because for typical libraries the row count
/// stays well within "small JSON" territory — even 10 books × 500 sessions
/// is ~150KB, an order of magnitude smaller than uploading the books shard
/// on every progress change.
class SyncSessionsShard {
  final int schemaVersion;
  final DateTime updatedAt;
  final String updatedBy;
  final List<SyncReadingSession> sessions;

  const SyncSessionsShard({
    this.schemaVersion = syncShardSchemaVersion,
    required this.updatedAt,
    required this.updatedBy,
    required this.sessions,
  });

  factory SyncSessionsShard.empty(String deviceId) => SyncSessionsShard(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedBy: deviceId,
        sessions: const [],
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'updatedBy': updatedBy,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory SyncSessionsShard.fromJson(Map<String, dynamic> json) =>
      SyncSessionsShard(
        schemaVersion:
            json['schemaVersion'] as int? ?? syncShardSchemaVersion,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        updatedBy: json['updatedBy'] as String? ?? '',
        sessions: (json['sessions'] as List? ?? const [])
            .map((s) => SyncReadingSession.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SyncSessionsShard.decode(String raw) =>
      SyncSessionsShard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

// ---------------------------------------------------------------------------
// Shard merges.
// ---------------------------------------------------------------------------

SyncBooksShard mergeBooksShard(
  SyncBooksShard a,
  SyncBooksShard b,
  String deviceId,
) {
  final byId = <String, SyncLibraryBook>{};
  for (final book in a.books) {
    byId[book.id] = book;
  }
  for (final book in b.books) {
    final existing = byId[book.id];
    byId[book.id] = existing == null ? book : mergeBook(existing, book);
  }
  return SyncBooksShard(
    updatedAt: _later(a.updatedAt, b.updatedAt),
    updatedBy: deviceId,
    books: byId.values.toList()..sort((x, y) => x.id.compareTo(y.id)),
  );
}

SyncSettingsShard mergeSettingsShard(
  SyncSettingsShard a,
  SyncSettingsShard b,
  String deviceId,
) {
  SyncLibrarySettings? settings;
  if (a.settings == null) {
    settings = b.settings;
  } else if (b.settings == null) {
    settings = a.settings;
  } else {
    settings = a.settings!.updatedAt.isAfter(b.settings!.updatedAt)
        ? a.settings
        : b.settings;
  }
  return SyncSettingsShard(
    updatedAt: _later(a.updatedAt, b.updatedAt),
    updatedBy: deviceId,
    settings: settings,
  );
}

/// Union by id. Sessions don't mutate after insert, so collisions on id mean
/// the same logical row — we keep [a]'s copy (arbitrary but deterministic).
SyncSessionsShard mergeSessionsShard(
  SyncSessionsShard a,
  SyncSessionsShard b,
  String deviceId,
) {
  final byId = <String, SyncReadingSession>{};
  for (final s in a.sessions) {
    byId[s.id] = s;
  }
  for (final s in b.sessions) {
    byId.putIfAbsent(s.id, () => s);
  }
  return SyncSessionsShard(
    updatedAt: _later(a.updatedAt, b.updatedAt),
    updatedBy: deviceId,
    sessions: byId.values.toList()..sort((x, y) => x.id.compareTo(y.id)),
  );
}

/// Per-row bookmark record. LWW by [updatedAt]; [deletedAt] carries
/// tombstone semantics so deletes converge across devices.
class SyncLibraryBookmark {
  final String id;
  final String bookId;
  final int globalWordIndex;
  final int chapterIndex;
  final String? label;
  final String? contextSnippet;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const SyncLibraryBookmark({
    required this.id,
    required this.bookId,
    required this.globalWordIndex,
    required this.chapterIndex,
    this.label,
    this.contextSnippet,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'globalWordIndex': globalWordIndex,
        'chapterIndex': chapterIndex,
        'label': label,
        'contextSnippet': contextSnippet,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
      };

  factory SyncLibraryBookmark.fromJson(Map<String, dynamic> json) =>
      SyncLibraryBookmark(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        globalWordIndex: (json['globalWordIndex'] as num).toInt(),
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        label: json['label'] as String?,
        contextSnippet: json['contextSnippet'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
      );
}

/// Bookmarks shard: `library/bookmarks.json`. Same envelope as the other
/// shards. Kept in its own file so creating / deleting a bookmark doesn't
/// drag books or sessions data over the wire.
class SyncBookmarksShard {
  final int schemaVersion;
  final DateTime updatedAt;
  final String updatedBy;
  final List<SyncLibraryBookmark> bookmarks;

  const SyncBookmarksShard({
    this.schemaVersion = syncShardSchemaVersion,
    required this.updatedAt,
    required this.updatedBy,
    required this.bookmarks,
  });

  factory SyncBookmarksShard.empty(String deviceId) => SyncBookmarksShard(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedBy: deviceId,
        bookmarks: const [],
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'updatedBy': updatedBy,
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      };

  factory SyncBookmarksShard.fromJson(Map<String, dynamic> json) =>
      SyncBookmarksShard(
        schemaVersion:
            json['schemaVersion'] as int? ?? syncShardSchemaVersion,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        updatedBy: json['updatedBy'] as String? ?? '',
        bookmarks: (json['bookmarks'] as List? ?? const [])
            .map((b) =>
                SyncLibraryBookmark.fromJson(b as Map<String, dynamic>))
            .toList(),
      );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SyncBookmarksShard.decode(String raw) =>
      SyncBookmarksShard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// LWW per bookmark id, by [updatedAt]. A tombstone (non-null [deletedAt])
/// follows the same comparison — whichever side has the latest update
/// wins, including its [deletedAt].
SyncLibraryBookmark mergeBookmark(
  SyncLibraryBookmark a,
  SyncLibraryBookmark b,
) {
  assert(a.id == b.id);
  return a.updatedAt.isAfter(b.updatedAt) ? a : b;
}

SyncBookmarksShard mergeBookmarksShard(
  SyncBookmarksShard a,
  SyncBookmarksShard b,
  String deviceId,
) {
  final byId = <String, SyncLibraryBookmark>{};
  for (final bm in a.bookmarks) {
    byId[bm.id] = bm;
  }
  for (final bm in b.bookmarks) {
    final existing = byId[bm.id];
    byId[bm.id] = existing == null ? bm : mergeBookmark(existing, bm);
  }
  return SyncBookmarksShard(
    updatedAt: _later(a.updatedAt, b.updatedAt),
    updatedBy: deviceId,
    bookmarks: byId.values.toList()..sort((x, y) => x.id.compareTo(y.id)),
  );
}
