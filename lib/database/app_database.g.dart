// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTableTable extends BooksTable
    with TableInfo<$BooksTableTable, BooksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverImageMeta = const VerificationMeta(
    'coverImage',
  );
  @override
  late final GeneratedColumn<Uint8List> coverImage = GeneratedColumn<Uint8List>(
    'cover_image',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalWordsMeta = const VerificationMeta(
    'totalWords',
  );
  @override
  late final GeneratedColumn<int> totalWords = GeneratedColumn<int>(
    'total_words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _chapterCountMeta = const VerificationMeta(
    'chapterCount',
  );
  @override
  late final GeneratedColumn<int> chapterCount = GeneratedColumn<int>(
    'chapter_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncFileNameMeta = const VerificationMeta(
    'syncFileName',
  );
  @override
  late final GeneratedColumn<String> syncFileName = GeneratedColumn<String>(
    'sync_file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(BookSource.epub),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _siteNameMeta = const VerificationMeta(
    'siteName',
  );
  @override
  late final GeneratedColumn<String> siteName = GeneratedColumn<String>(
    'site_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingUpdatedAtMeta = const VerificationMeta(
    'ratingUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> ratingUpdatedAt =
      GeneratedColumn<DateTime>(
        'rating_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    filePath,
    coverImage,
    totalWords,
    chapterCount,
    importedAt,
    lastReadAt,
    syncFileName,
    source,
    sourceUrl,
    siteName,
    rating,
    ratingUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<BooksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('cover_image')) {
      context.handle(
        _coverImageMeta,
        coverImage.isAcceptableOrUnknown(data['cover_image']!, _coverImageMeta),
      );
    }
    if (data.containsKey('total_words')) {
      context.handle(
        _totalWordsMeta,
        totalWords.isAcceptableOrUnknown(data['total_words']!, _totalWordsMeta),
      );
    }
    if (data.containsKey('chapter_count')) {
      context.handle(
        _chapterCountMeta,
        chapterCount.isAcceptableOrUnknown(
          data['chapter_count']!,
          _chapterCountMeta,
        ),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_file_name')) {
      context.handle(
        _syncFileNameMeta,
        syncFileName.isAcceptableOrUnknown(
          data['sync_file_name']!,
          _syncFileNameMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('site_name')) {
      context.handle(
        _siteNameMeta,
        siteName.isAcceptableOrUnknown(data['site_name']!, _siteNameMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('rating_updated_at')) {
      context.handle(
        _ratingUpdatedAtMeta,
        ratingUpdatedAt.isAcceptableOrUnknown(
          data['rating_updated_at']!,
          _ratingUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BooksTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BooksTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      coverImage: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}cover_image'],
      ),
      totalWords: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_words'],
      )!,
      chapterCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_count'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      ),
      syncFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_file_name'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      siteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_name'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      ratingUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}rating_updated_at'],
      ),
    );
  }

  @override
  $BooksTableTable createAlias(String alias) {
    return $BooksTableTable(attachedDatabase, alias);
  }
}

class BooksTableData extends DataClass implements Insertable<BooksTableData> {
  final String id;
  final String title;
  final String? author;
  final String filePath;
  final Uint8List? coverImage;
  final int totalWords;
  final int chapterCount;
  final DateTime importedAt;
  final DateTime? lastReadAt;

  /// Filename used when storing this book's EPUB in the sync folder. We keep
  /// the user's original filename (with numeric suffix to disambiguate
  /// collisions) instead of the UUID so the folder is browsable.
  /// Null for books imported before the sync-filename feature landed.
  final String? syncFileName;

  /// Origin of the content. See [BookSource] for the allowed values.
  /// Drives library tab filtering and whether the row participates in EPUB sync.
  final String source;

  /// For `source = article`: the URL it was imported from.
  final String? sourceUrl;

  /// For `source = article`: the site name (extracted by readability), used
  /// as a subtitle/attribution in the library card.
  final String? siteName;

  /// Reader rating: null = unrated, 1..5 otherwise. Rendered on the book
  /// completion card and persisted so rating survives re-reading.
  final int? rating;

  /// Stamped when [rating] is written (including clears). Needed by sync's
  /// per-field LWW merge — without it, a fresh rating on one device can be
  /// overwritten by another device whose unrelated update (progress, etc.)
  /// bumped the parent updatedAt later.
  final DateTime? ratingUpdatedAt;
  const BooksTableData({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    this.coverImage,
    required this.totalWords,
    required this.chapterCount,
    required this.importedAt,
    this.lastReadAt,
    this.syncFileName,
    required this.source,
    this.sourceUrl,
    this.siteName,
    this.rating,
    this.ratingUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || coverImage != null) {
      map['cover_image'] = Variable<Uint8List>(coverImage);
    }
    map['total_words'] = Variable<int>(totalWords);
    map['chapter_count'] = Variable<int>(chapterCount);
    map['imported_at'] = Variable<DateTime>(importedAt);
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt);
    }
    if (!nullToAbsent || syncFileName != null) {
      map['sync_file_name'] = Variable<String>(syncFileName);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || siteName != null) {
      map['site_name'] = Variable<String>(siteName);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    if (!nullToAbsent || ratingUpdatedAt != null) {
      map['rating_updated_at'] = Variable<DateTime>(ratingUpdatedAt);
    }
    return map;
  }

  BooksTableCompanion toCompanion(bool nullToAbsent) {
    return BooksTableCompanion(
      id: Value(id),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      filePath: Value(filePath),
      coverImage: coverImage == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImage),
      totalWords: Value(totalWords),
      chapterCount: Value(chapterCount),
      importedAt: Value(importedAt),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
      syncFileName: syncFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(syncFileName),
      source: Value(source),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      siteName: siteName == null && nullToAbsent
          ? const Value.absent()
          : Value(siteName),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      ratingUpdatedAt: ratingUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(ratingUpdatedAt),
    );
  }

  factory BooksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BooksTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      filePath: serializer.fromJson<String>(json['filePath']),
      coverImage: serializer.fromJson<Uint8List?>(json['coverImage']),
      totalWords: serializer.fromJson<int>(json['totalWords']),
      chapterCount: serializer.fromJson<int>(json['chapterCount']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      lastReadAt: serializer.fromJson<DateTime?>(json['lastReadAt']),
      syncFileName: serializer.fromJson<String?>(json['syncFileName']),
      source: serializer.fromJson<String>(json['source']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      siteName: serializer.fromJson<String?>(json['siteName']),
      rating: serializer.fromJson<int?>(json['rating']),
      ratingUpdatedAt: serializer.fromJson<DateTime?>(json['ratingUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'filePath': serializer.toJson<String>(filePath),
      'coverImage': serializer.toJson<Uint8List?>(coverImage),
      'totalWords': serializer.toJson<int>(totalWords),
      'chapterCount': serializer.toJson<int>(chapterCount),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'lastReadAt': serializer.toJson<DateTime?>(lastReadAt),
      'syncFileName': serializer.toJson<String?>(syncFileName),
      'source': serializer.toJson<String>(source),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'siteName': serializer.toJson<String?>(siteName),
      'rating': serializer.toJson<int?>(rating),
      'ratingUpdatedAt': serializer.toJson<DateTime?>(ratingUpdatedAt),
    };
  }

  BooksTableData copyWith({
    String? id,
    String? title,
    Value<String?> author = const Value.absent(),
    String? filePath,
    Value<Uint8List?> coverImage = const Value.absent(),
    int? totalWords,
    int? chapterCount,
    DateTime? importedAt,
    Value<DateTime?> lastReadAt = const Value.absent(),
    Value<String?> syncFileName = const Value.absent(),
    String? source,
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> siteName = const Value.absent(),
    Value<int?> rating = const Value.absent(),
    Value<DateTime?> ratingUpdatedAt = const Value.absent(),
  }) => BooksTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    filePath: filePath ?? this.filePath,
    coverImage: coverImage.present ? coverImage.value : this.coverImage,
    totalWords: totalWords ?? this.totalWords,
    chapterCount: chapterCount ?? this.chapterCount,
    importedAt: importedAt ?? this.importedAt,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
    syncFileName: syncFileName.present ? syncFileName.value : this.syncFileName,
    source: source ?? this.source,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    siteName: siteName.present ? siteName.value : this.siteName,
    rating: rating.present ? rating.value : this.rating,
    ratingUpdatedAt: ratingUpdatedAt.present
        ? ratingUpdatedAt.value
        : this.ratingUpdatedAt,
  );
  BooksTableData copyWithCompanion(BooksTableCompanion data) {
    return BooksTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      coverImage: data.coverImage.present
          ? data.coverImage.value
          : this.coverImage,
      totalWords: data.totalWords.present
          ? data.totalWords.value
          : this.totalWords,
      chapterCount: data.chapterCount.present
          ? data.chapterCount.value
          : this.chapterCount,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      syncFileName: data.syncFileName.present
          ? data.syncFileName.value
          : this.syncFileName,
      source: data.source.present ? data.source.value : this.source,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      siteName: data.siteName.present ? data.siteName.value : this.siteName,
      rating: data.rating.present ? data.rating.value : this.rating,
      ratingUpdatedAt: data.ratingUpdatedAt.present
          ? data.ratingUpdatedAt.value
          : this.ratingUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BooksTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('filePath: $filePath, ')
          ..write('coverImage: $coverImage, ')
          ..write('totalWords: $totalWords, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('importedAt: $importedAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('syncFileName: $syncFileName, ')
          ..write('source: $source, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('siteName: $siteName, ')
          ..write('rating: $rating, ')
          ..write('ratingUpdatedAt: $ratingUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    filePath,
    $driftBlobEquality.hash(coverImage),
    totalWords,
    chapterCount,
    importedAt,
    lastReadAt,
    syncFileName,
    source,
    sourceUrl,
    siteName,
    rating,
    ratingUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BooksTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.filePath == this.filePath &&
          $driftBlobEquality.equals(other.coverImage, this.coverImage) &&
          other.totalWords == this.totalWords &&
          other.chapterCount == this.chapterCount &&
          other.importedAt == this.importedAt &&
          other.lastReadAt == this.lastReadAt &&
          other.syncFileName == this.syncFileName &&
          other.source == this.source &&
          other.sourceUrl == this.sourceUrl &&
          other.siteName == this.siteName &&
          other.rating == this.rating &&
          other.ratingUpdatedAt == this.ratingUpdatedAt);
}

class BooksTableCompanion extends UpdateCompanion<BooksTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> author;
  final Value<String> filePath;
  final Value<Uint8List?> coverImage;
  final Value<int> totalWords;
  final Value<int> chapterCount;
  final Value<DateTime> importedAt;
  final Value<DateTime?> lastReadAt;
  final Value<String?> syncFileName;
  final Value<String> source;
  final Value<String?> sourceUrl;
  final Value<String?> siteName;
  final Value<int?> rating;
  final Value<DateTime?> ratingUpdatedAt;
  final Value<int> rowid;
  const BooksTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.filePath = const Value.absent(),
    this.coverImage = const Value.absent(),
    this.totalWords = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.syncFileName = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.siteName = const Value.absent(),
    this.rating = const Value.absent(),
    this.ratingUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksTableCompanion.insert({
    required String id,
    required String title,
    this.author = const Value.absent(),
    required String filePath,
    this.coverImage = const Value.absent(),
    this.totalWords = const Value.absent(),
    this.chapterCount = const Value.absent(),
    required DateTime importedAt,
    this.lastReadAt = const Value.absent(),
    this.syncFileName = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.siteName = const Value.absent(),
    this.rating = const Value.absent(),
    this.ratingUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       filePath = Value(filePath),
       importedAt = Value(importedAt);
  static Insertable<BooksTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? filePath,
    Expression<Uint8List>? coverImage,
    Expression<int>? totalWords,
    Expression<int>? chapterCount,
    Expression<DateTime>? importedAt,
    Expression<DateTime>? lastReadAt,
    Expression<String>? syncFileName,
    Expression<String>? source,
    Expression<String>? sourceUrl,
    Expression<String>? siteName,
    Expression<int>? rating,
    Expression<DateTime>? ratingUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (filePath != null) 'file_path': filePath,
      if (coverImage != null) 'cover_image': coverImage,
      if (totalWords != null) 'total_words': totalWords,
      if (chapterCount != null) 'chapter_count': chapterCount,
      if (importedAt != null) 'imported_at': importedAt,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (syncFileName != null) 'sync_file_name': syncFileName,
      if (source != null) 'source': source,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (siteName != null) 'site_name': siteName,
      if (rating != null) 'rating': rating,
      if (ratingUpdatedAt != null) 'rating_updated_at': ratingUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? author,
    Value<String>? filePath,
    Value<Uint8List?>? coverImage,
    Value<int>? totalWords,
    Value<int>? chapterCount,
    Value<DateTime>? importedAt,
    Value<DateTime?>? lastReadAt,
    Value<String?>? syncFileName,
    Value<String>? source,
    Value<String?>? sourceUrl,
    Value<String?>? siteName,
    Value<int?>? rating,
    Value<DateTime?>? ratingUpdatedAt,
    Value<int>? rowid,
  }) {
    return BooksTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverImage: coverImage ?? this.coverImage,
      totalWords: totalWords ?? this.totalWords,
      chapterCount: chapterCount ?? this.chapterCount,
      importedAt: importedAt ?? this.importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      syncFileName: syncFileName ?? this.syncFileName,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      siteName: siteName ?? this.siteName,
      rating: rating ?? this.rating,
      ratingUpdatedAt: ratingUpdatedAt ?? this.ratingUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (coverImage.present) {
      map['cover_image'] = Variable<Uint8List>(coverImage.value);
    }
    if (totalWords.present) {
      map['total_words'] = Variable<int>(totalWords.value);
    }
    if (chapterCount.present) {
      map['chapter_count'] = Variable<int>(chapterCount.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (syncFileName.present) {
      map['sync_file_name'] = Variable<String>(syncFileName.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (siteName.present) {
      map['site_name'] = Variable<String>(siteName.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (ratingUpdatedAt.present) {
      map['rating_updated_at'] = Variable<DateTime>(ratingUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('filePath: $filePath, ')
          ..write('coverImage: $coverImage, ')
          ..write('totalWords: $totalWords, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('importedAt: $importedAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('syncFileName: $syncFileName, ')
          ..write('source: $source, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('siteName: $siteName, ')
          ..write('rating: $rating, ')
          ..write('ratingUpdatedAt: $ratingUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTableTable extends ReadingProgressTable
    with TableInfo<$ReadingProgressTableTable, ReadingProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books_table (id)',
    ),
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordIndexMeta = const VerificationMeta(
    'wordIndex',
  );
  @override
  late final GeneratedColumn<int> wordIndex = GeneratedColumn<int>(
    'word_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wpmMeta = const VerificationMeta('wpm');
  @override
  late final GeneratedColumn<int> wpm = GeneratedColumn<int>(
    'wpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(300),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readerModeMeta = const VerificationMeta(
    'readerMode',
  );
  @override
  late final GeneratedColumn<String> readerMode = GeneratedColumn<String>(
    'reader_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    chapterIndex,
    wordIndex,
    wpm,
    updatedAt,
    readerMode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('word_index')) {
      context.handle(
        _wordIndexMeta,
        wordIndex.isAcceptableOrUnknown(data['word_index']!, _wordIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIndexMeta);
    }
    if (data.containsKey('wpm')) {
      context.handle(
        _wpmMeta,
        wpm.isAcceptableOrUnknown(data['wpm']!, _wpmMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('reader_mode')) {
      context.handle(
        _readerModeMeta,
        readerMode.isAcceptableOrUnknown(data['reader_mode']!, _readerModeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressTableData(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      wordIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_index'],
      )!,
      wpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wpm'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      readerMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reader_mode'],
      ),
    );
  }

  @override
  $ReadingProgressTableTable createAlias(String alias) {
    return $ReadingProgressTableTable(attachedDatabase, alias);
  }
}

class ReadingProgressTableData extends DataClass
    implements Insertable<ReadingProgressTableData> {
  final String bookId;
  final int chapterIndex;
  final int wordIndex;
  final int wpm;
  final DateTime updatedAt;

  /// Last reader mode (`'rsvp'`, `'ereader'`, or `'tts'`) the user
  /// explicitly chose for this book. `scroll` collapses into `rsvp` here
  /// since the two share a single user-facing identity — `scroll` is just
  /// the paused half of the RSVP experience.
  ///
  /// `null` means "never chosen" (default behaviour: open in scroll/RSVP).
  /// Added in schema v8.
  final String? readerMode;
  const ReadingProgressTableData({
    required this.bookId,
    required this.chapterIndex,
    required this.wordIndex,
    required this.wpm,
    required this.updatedAt,
    this.readerMode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['word_index'] = Variable<int>(wordIndex);
    map['wpm'] = Variable<int>(wpm);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || readerMode != null) {
      map['reader_mode'] = Variable<String>(readerMode);
    }
    return map;
  }

  ReadingProgressTableCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressTableCompanion(
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      wordIndex: Value(wordIndex),
      wpm: Value(wpm),
      updatedAt: Value(updatedAt),
      readerMode: readerMode == null && nullToAbsent
          ? const Value.absent()
          : Value(readerMode),
    );
  }

  factory ReadingProgressTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressTableData(
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      wordIndex: serializer.fromJson<int>(json['wordIndex']),
      wpm: serializer.fromJson<int>(json['wpm']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      readerMode: serializer.fromJson<String?>(json['readerMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'wordIndex': serializer.toJson<int>(wordIndex),
      'wpm': serializer.toJson<int>(wpm),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'readerMode': serializer.toJson<String?>(readerMode),
    };
  }

  ReadingProgressTableData copyWith({
    String? bookId,
    int? chapterIndex,
    int? wordIndex,
    int? wpm,
    DateTime? updatedAt,
    Value<String?> readerMode = const Value.absent(),
  }) => ReadingProgressTableData(
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    wordIndex: wordIndex ?? this.wordIndex,
    wpm: wpm ?? this.wpm,
    updatedAt: updatedAt ?? this.updatedAt,
    readerMode: readerMode.present ? readerMode.value : this.readerMode,
  );
  ReadingProgressTableData copyWithCompanion(
    ReadingProgressTableCompanion data,
  ) {
    return ReadingProgressTableData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      wordIndex: data.wordIndex.present ? data.wordIndex.value : this.wordIndex,
      wpm: data.wpm.present ? data.wpm.value : this.wpm,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      readerMode: data.readerMode.present
          ? data.readerMode.value
          : this.readerMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressTableData(')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('wordIndex: $wordIndex, ')
          ..write('wpm: $wpm, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('readerMode: $readerMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(bookId, chapterIndex, wordIndex, wpm, updatedAt, readerMode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressTableData &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.wordIndex == this.wordIndex &&
          other.wpm == this.wpm &&
          other.updatedAt == this.updatedAt &&
          other.readerMode == this.readerMode);
}

class ReadingProgressTableCompanion
    extends UpdateCompanion<ReadingProgressTableData> {
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> wordIndex;
  final Value<int> wpm;
  final Value<DateTime> updatedAt;
  final Value<String?> readerMode;
  final Value<int> rowid;
  const ReadingProgressTableCompanion({
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.wordIndex = const Value.absent(),
    this.wpm = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.readerMode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressTableCompanion.insert({
    required String bookId,
    required int chapterIndex,
    required int wordIndex,
    this.wpm = const Value.absent(),
    required DateTime updatedAt,
    this.readerMode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       wordIndex = Value(wordIndex),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingProgressTableData> custom({
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? wordIndex,
    Expression<int>? wpm,
    Expression<DateTime>? updatedAt,
    Expression<String>? readerMode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (wordIndex != null) 'word_index': wordIndex,
      if (wpm != null) 'wpm': wpm,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (readerMode != null) 'reader_mode': readerMode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressTableCompanion copyWith({
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<int>? wordIndex,
    Value<int>? wpm,
    Value<DateTime>? updatedAt,
    Value<String?>? readerMode,
    Value<int>? rowid,
  }) {
    return ReadingProgressTableCompanion(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      wordIndex: wordIndex ?? this.wordIndex,
      wpm: wpm ?? this.wpm,
      updatedAt: updatedAt ?? this.updatedAt,
      readerMode: readerMode ?? this.readerMode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (wordIndex.present) {
      map['word_index'] = Variable<int>(wordIndex.value);
    }
    if (wpm.present) {
      map['wpm'] = Variable<int>(wpm.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (readerMode.present) {
      map['reader_mode'] = Variable<String>(readerMode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressTableCompanion(')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('wordIndex: $wordIndex, ')
          ..write('wpm: $wpm, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('readerMode: $readerMode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingSessionTableTable extends ReadingSessionTable
    with TableInfo<$ReadingSessionTableTable, ReadingSessionTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingSessionTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordsReadMeta = const VerificationMeta(
    'wordsRead',
  );
  @override
  late final GeneratedColumn<int> wordsRead = GeneratedColumn<int>(
    'words_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startWordIndexMeta = const VerificationMeta(
    'startWordIndex',
  );
  @override
  late final GeneratedColumn<int> startWordIndex = GeneratedColumn<int>(
    'start_word_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endWordIndexMeta = const VerificationMeta(
    'endWordIndex',
  );
  @override
  late final GeneratedColumn<int> endWordIndex = GeneratedColumn<int>(
    'end_word_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgWpmMeta = const VerificationMeta('avgWpm');
  @override
  late final GeneratedColumn<int> avgWpm = GeneratedColumn<int>(
    'avg_wpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    startedAt,
    endedAt,
    durationMs,
    wordsRead,
    startWordIndex,
    endWordIndex,
    avgWpm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_session_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingSessionTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('words_read')) {
      context.handle(
        _wordsReadMeta,
        wordsRead.isAcceptableOrUnknown(data['words_read']!, _wordsReadMeta),
      );
    } else if (isInserting) {
      context.missing(_wordsReadMeta);
    }
    if (data.containsKey('start_word_index')) {
      context.handle(
        _startWordIndexMeta,
        startWordIndex.isAcceptableOrUnknown(
          data['start_word_index']!,
          _startWordIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startWordIndexMeta);
    }
    if (data.containsKey('end_word_index')) {
      context.handle(
        _endWordIndexMeta,
        endWordIndex.isAcceptableOrUnknown(
          data['end_word_index']!,
          _endWordIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endWordIndexMeta);
    }
    if (data.containsKey('avg_wpm')) {
      context.handle(
        _avgWpmMeta,
        avgWpm.isAcceptableOrUnknown(data['avg_wpm']!, _avgWpmMeta),
      );
    } else if (isInserting) {
      context.missing(_avgWpmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingSessionTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingSessionTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      wordsRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}words_read'],
      )!,
      startWordIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_word_index'],
      )!,
      endWordIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_word_index'],
      )!,
      avgWpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_wpm'],
      )!,
    );
  }

  @override
  $ReadingSessionTableTable createAlias(String alias) {
    return $ReadingSessionTableTable(attachedDatabase, alias);
  }
}

class ReadingSessionTableData extends DataClass
    implements Insertable<ReadingSessionTableData> {
  final String id;
  final String bookId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMs;
  final int wordsRead;
  final int startWordIndex;
  final int endWordIndex;
  final int avgWpm;
  const ReadingSessionTableData({
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
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['words_read'] = Variable<int>(wordsRead);
    map['start_word_index'] = Variable<int>(startWordIndex);
    map['end_word_index'] = Variable<int>(endWordIndex);
    map['avg_wpm'] = Variable<int>(avgWpm);
    return map;
  }

  ReadingSessionTableCompanion toCompanion(bool nullToAbsent) {
    return ReadingSessionTableCompanion(
      id: Value(id),
      bookId: Value(bookId),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      durationMs: Value(durationMs),
      wordsRead: Value(wordsRead),
      startWordIndex: Value(startWordIndex),
      endWordIndex: Value(endWordIndex),
      avgWpm: Value(avgWpm),
    );
  }

  factory ReadingSessionTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingSessionTableData(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      wordsRead: serializer.fromJson<int>(json['wordsRead']),
      startWordIndex: serializer.fromJson<int>(json['startWordIndex']),
      endWordIndex: serializer.fromJson<int>(json['endWordIndex']),
      avgWpm: serializer.fromJson<int>(json['avgWpm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'wordsRead': serializer.toJson<int>(wordsRead),
      'startWordIndex': serializer.toJson<int>(startWordIndex),
      'endWordIndex': serializer.toJson<int>(endWordIndex),
      'avgWpm': serializer.toJson<int>(avgWpm),
    };
  }

  ReadingSessionTableData copyWith({
    String? id,
    String? bookId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationMs,
    int? wordsRead,
    int? startWordIndex,
    int? endWordIndex,
    int? avgWpm,
  }) => ReadingSessionTableData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    durationMs: durationMs ?? this.durationMs,
    wordsRead: wordsRead ?? this.wordsRead,
    startWordIndex: startWordIndex ?? this.startWordIndex,
    endWordIndex: endWordIndex ?? this.endWordIndex,
    avgWpm: avgWpm ?? this.avgWpm,
  );
  ReadingSessionTableData copyWithCompanion(ReadingSessionTableCompanion data) {
    return ReadingSessionTableData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      wordsRead: data.wordsRead.present ? data.wordsRead.value : this.wordsRead,
      startWordIndex: data.startWordIndex.present
          ? data.startWordIndex.value
          : this.startWordIndex,
      endWordIndex: data.endWordIndex.present
          ? data.endWordIndex.value
          : this.endWordIndex,
      avgWpm: data.avgWpm.present ? data.avgWpm.value : this.avgWpm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionTableData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('wordsRead: $wordsRead, ')
          ..write('startWordIndex: $startWordIndex, ')
          ..write('endWordIndex: $endWordIndex, ')
          ..write('avgWpm: $avgWpm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    startedAt,
    endedAt,
    durationMs,
    wordsRead,
    startWordIndex,
    endWordIndex,
    avgWpm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingSessionTableData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationMs == this.durationMs &&
          other.wordsRead == this.wordsRead &&
          other.startWordIndex == this.startWordIndex &&
          other.endWordIndex == this.endWordIndex &&
          other.avgWpm == this.avgWpm);
}

class ReadingSessionTableCompanion
    extends UpdateCompanion<ReadingSessionTableData> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<int> durationMs;
  final Value<int> wordsRead;
  final Value<int> startWordIndex;
  final Value<int> endWordIndex;
  final Value<int> avgWpm;
  final Value<int> rowid;
  const ReadingSessionTableCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.wordsRead = const Value.absent(),
    this.startWordIndex = const Value.absent(),
    this.endWordIndex = const Value.absent(),
    this.avgWpm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingSessionTableCompanion.insert({
    required String id,
    required String bookId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationMs,
    required int wordsRead,
    required int startWordIndex,
    required int endWordIndex,
    required int avgWpm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       durationMs = Value(durationMs),
       wordsRead = Value(wordsRead),
       startWordIndex = Value(startWordIndex),
       endWordIndex = Value(endWordIndex),
       avgWpm = Value(avgWpm);
  static Insertable<ReadingSessionTableData> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationMs,
    Expression<int>? wordsRead,
    Expression<int>? startWordIndex,
    Expression<int>? endWordIndex,
    Expression<int>? avgWpm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (wordsRead != null) 'words_read': wordsRead,
      if (startWordIndex != null) 'start_word_index': startWordIndex,
      if (endWordIndex != null) 'end_word_index': endWordIndex,
      if (avgWpm != null) 'avg_wpm': avgWpm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingSessionTableCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<int>? durationMs,
    Value<int>? wordsRead,
    Value<int>? startWordIndex,
    Value<int>? endWordIndex,
    Value<int>? avgWpm,
    Value<int>? rowid,
  }) {
    return ReadingSessionTableCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMs: durationMs ?? this.durationMs,
      wordsRead: wordsRead ?? this.wordsRead,
      startWordIndex: startWordIndex ?? this.startWordIndex,
      endWordIndex: endWordIndex ?? this.endWordIndex,
      avgWpm: avgWpm ?? this.avgWpm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (wordsRead.present) {
      map['words_read'] = Variable<int>(wordsRead.value);
    }
    if (startWordIndex.present) {
      map['start_word_index'] = Variable<int>(startWordIndex.value);
    }
    if (endWordIndex.present) {
      map['end_word_index'] = Variable<int>(endWordIndex.value);
    }
    if (avgWpm.present) {
      map['avg_wpm'] = Variable<int>(avgWpm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionTableCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('wordsRead: $wordsRead, ')
          ..write('startWordIndex: $startWordIndex, ')
          ..write('endWordIndex: $endWordIndex, ')
          ..write('avgWpm: $avgWpm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedTokensTableTable extends CachedTokensTable
    with TableInfo<$CachedTokensTableTable, CachedTokensTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTokensTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books_table (id)',
    ),
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterTitleMeta = const VerificationMeta(
    'chapterTitle',
  );
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
    'chapter_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tokensJsonMeta = const VerificationMeta(
    'tokensJson',
  );
  @override
  late final GeneratedColumn<String> tokensJson = GeneratedColumn<String>(
    'tokens_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paragraphCountMeta = const VerificationMeta(
    'paragraphCount',
  );
  @override
  late final GeneratedColumn<int> paragraphCount = GeneratedColumn<int>(
    'paragraph_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    chapterTitle,
    tokensJson,
    wordCount,
    paragraphCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_tokens_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTokensTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
        _chapterTitleMeta,
        chapterTitle.isAcceptableOrUnknown(
          data['chapter_title']!,
          _chapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('tokens_json')) {
      context.handle(
        _tokensJsonMeta,
        tokensJson.isAcceptableOrUnknown(data['tokens_json']!, _tokensJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_tokensJsonMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    } else if (isInserting) {
      context.missing(_wordCountMeta);
    }
    if (data.containsKey('paragraph_count')) {
      context.handle(
        _paragraphCountMeta,
        paragraphCount.isAcceptableOrUnknown(
          data['paragraph_count']!,
          _paragraphCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedTokensTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTokensTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      chapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_title'],
      )!,
      tokensJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tokens_json'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      paragraphCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_count'],
      )!,
    );
  }

  @override
  $CachedTokensTableTable createAlias(String alias) {
    return $CachedTokensTableTable(attachedDatabase, alias);
  }
}

class CachedTokensTableData extends DataClass
    implements Insertable<CachedTokensTableData> {
  final int id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String tokensJson;
  final int wordCount;
  final int paragraphCount;
  const CachedTokensTableData({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.tokensJson,
    required this.wordCount,
    required this.paragraphCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['chapter_title'] = Variable<String>(chapterTitle);
    map['tokens_json'] = Variable<String>(tokensJson);
    map['word_count'] = Variable<int>(wordCount);
    map['paragraph_count'] = Variable<int>(paragraphCount);
    return map;
  }

  CachedTokensTableCompanion toCompanion(bool nullToAbsent) {
    return CachedTokensTableCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      chapterTitle: Value(chapterTitle),
      tokensJson: Value(tokensJson),
      wordCount: Value(wordCount),
      paragraphCount: Value(paragraphCount),
    );
  }

  factory CachedTokensTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTokensTableData(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterTitle: serializer.fromJson<String>(json['chapterTitle']),
      tokensJson: serializer.fromJson<String>(json['tokensJson']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      paragraphCount: serializer.fromJson<int>(json['paragraphCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'chapterTitle': serializer.toJson<String>(chapterTitle),
      'tokensJson': serializer.toJson<String>(tokensJson),
      'wordCount': serializer.toJson<int>(wordCount),
      'paragraphCount': serializer.toJson<int>(paragraphCount),
    };
  }

  CachedTokensTableData copyWith({
    int? id,
    String? bookId,
    int? chapterIndex,
    String? chapterTitle,
    String? tokensJson,
    int? wordCount,
    int? paragraphCount,
  }) => CachedTokensTableData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterTitle: chapterTitle ?? this.chapterTitle,
    tokensJson: tokensJson ?? this.tokensJson,
    wordCount: wordCount ?? this.wordCount,
    paragraphCount: paragraphCount ?? this.paragraphCount,
  );
  CachedTokensTableData copyWithCompanion(CachedTokensTableCompanion data) {
    return CachedTokensTableData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      chapterTitle: data.chapterTitle.present
          ? data.chapterTitle.value
          : this.chapterTitle,
      tokensJson: data.tokensJson.present
          ? data.tokensJson.value
          : this.tokensJson,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      paragraphCount: data.paragraphCount.present
          ? data.paragraphCount.value
          : this.paragraphCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTokensTableData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('tokensJson: $tokensJson, ')
          ..write('wordCount: $wordCount, ')
          ..write('paragraphCount: $paragraphCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    chapterTitle,
    tokensJson,
    wordCount,
    paragraphCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTokensTableData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterTitle == this.chapterTitle &&
          other.tokensJson == this.tokensJson &&
          other.wordCount == this.wordCount &&
          other.paragraphCount == this.paragraphCount);
}

class CachedTokensTableCompanion
    extends UpdateCompanion<CachedTokensTableData> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<String> chapterTitle;
  final Value<String> tokensJson;
  final Value<int> wordCount;
  final Value<int> paragraphCount;
  const CachedTokensTableCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.tokensJson = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.paragraphCount = const Value.absent(),
  });
  CachedTokensTableCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required int chapterIndex,
    this.chapterTitle = const Value.absent(),
    required String tokensJson,
    required int wordCount,
    this.paragraphCount = const Value.absent(),
  }) : bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       tokensJson = Value(tokensJson),
       wordCount = Value(wordCount);
  static Insertable<CachedTokensTableData> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<String>? chapterTitle,
    Expression<String>? tokensJson,
    Expression<int>? wordCount,
    Expression<int>? paragraphCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (tokensJson != null) 'tokens_json': tokensJson,
      if (wordCount != null) 'word_count': wordCount,
      if (paragraphCount != null) 'paragraph_count': paragraphCount,
    });
  }

  CachedTokensTableCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<String>? chapterTitle,
    Value<String>? tokensJson,
    Value<int>? wordCount,
    Value<int>? paragraphCount,
  }) {
    return CachedTokensTableCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      tokensJson: tokensJson ?? this.tokensJson,
      wordCount: wordCount ?? this.wordCount,
      paragraphCount: paragraphCount ?? this.paragraphCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (tokensJson.present) {
      map['tokens_json'] = Variable<String>(tokensJson.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (paragraphCount.present) {
      map['paragraph_count'] = Variable<int>(paragraphCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTokensTableCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('tokensJson: $tokensJson, ')
          ..write('wordCount: $wordCount, ')
          ..write('paragraphCount: $paragraphCount')
          ..write(')'))
        .toString();
  }
}

class $SyncImportFailuresTableTable extends SyncImportFailuresTable
    with TableInfo<$SyncImportFailuresTableTable, SyncImportFailuresTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncImportFailuresTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedAtMeta = const VerificationMeta(
    'failedAt',
  );
  @override
  late final GeneratedColumn<DateTime> failedAt = GeneratedColumn<DateTime>(
    'failed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [fileName, errorMessage, failedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_import_failures_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncImportFailuresTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_errorMessageMeta);
    }
    if (data.containsKey('failed_at')) {
      context.handle(
        _failedAtMeta,
        failedAt.isAcceptableOrUnknown(data['failed_at']!, _failedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_failedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileName};
  @override
  SyncImportFailuresTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncImportFailuresTableData(
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      )!,
      failedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}failed_at'],
      )!,
    );
  }

  @override
  $SyncImportFailuresTableTable createAlias(String alias) {
    return $SyncImportFailuresTableTable(attachedDatabase, alias);
  }
}

class SyncImportFailuresTableData extends DataClass
    implements Insertable<SyncImportFailuresTableData> {
  final String fileName;
  final String errorMessage;
  final DateTime failedAt;
  const SyncImportFailuresTableData({
    required this.fileName,
    required this.errorMessage,
    required this.failedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_name'] = Variable<String>(fileName);
    map['error_message'] = Variable<String>(errorMessage);
    map['failed_at'] = Variable<DateTime>(failedAt);
    return map;
  }

  SyncImportFailuresTableCompanion toCompanion(bool nullToAbsent) {
    return SyncImportFailuresTableCompanion(
      fileName: Value(fileName),
      errorMessage: Value(errorMessage),
      failedAt: Value(failedAt),
    );
  }

  factory SyncImportFailuresTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncImportFailuresTableData(
      fileName: serializer.fromJson<String>(json['fileName']),
      errorMessage: serializer.fromJson<String>(json['errorMessage']),
      failedAt: serializer.fromJson<DateTime>(json['failedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileName': serializer.toJson<String>(fileName),
      'errorMessage': serializer.toJson<String>(errorMessage),
      'failedAt': serializer.toJson<DateTime>(failedAt),
    };
  }

  SyncImportFailuresTableData copyWith({
    String? fileName,
    String? errorMessage,
    DateTime? failedAt,
  }) => SyncImportFailuresTableData(
    fileName: fileName ?? this.fileName,
    errorMessage: errorMessage ?? this.errorMessage,
    failedAt: failedAt ?? this.failedAt,
  );
  SyncImportFailuresTableData copyWithCompanion(
    SyncImportFailuresTableCompanion data,
  ) {
    return SyncImportFailuresTableData(
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      failedAt: data.failedAt.present ? data.failedAt.value : this.failedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncImportFailuresTableData(')
          ..write('fileName: $fileName, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('failedAt: $failedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fileName, errorMessage, failedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncImportFailuresTableData &&
          other.fileName == this.fileName &&
          other.errorMessage == this.errorMessage &&
          other.failedAt == this.failedAt);
}

class SyncImportFailuresTableCompanion
    extends UpdateCompanion<SyncImportFailuresTableData> {
  final Value<String> fileName;
  final Value<String> errorMessage;
  final Value<DateTime> failedAt;
  final Value<int> rowid;
  const SyncImportFailuresTableCompanion({
    this.fileName = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.failedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncImportFailuresTableCompanion.insert({
    required String fileName,
    required String errorMessage,
    required DateTime failedAt,
    this.rowid = const Value.absent(),
  }) : fileName = Value(fileName),
       errorMessage = Value(errorMessage),
       failedAt = Value(failedAt);
  static Insertable<SyncImportFailuresTableData> custom({
    Expression<String>? fileName,
    Expression<String>? errorMessage,
    Expression<DateTime>? failedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fileName != null) 'file_name': fileName,
      if (errorMessage != null) 'error_message': errorMessage,
      if (failedAt != null) 'failed_at': failedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncImportFailuresTableCompanion copyWith({
    Value<String>? fileName,
    Value<String>? errorMessage,
    Value<DateTime>? failedAt,
    Value<int>? rowid,
  }) {
    return SyncImportFailuresTableCompanion(
      fileName: fileName ?? this.fileName,
      errorMessage: errorMessage ?? this.errorMessage,
      failedAt: failedAt ?? this.failedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (failedAt.present) {
      map['failed_at'] = Variable<DateTime>(failedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncImportFailuresTableCompanion(')
          ..write('fileName: $fileName, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('failedAt: $failedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTableTable extends BookmarksTable
    with TableInfo<$BookmarksTableTable, BookmarksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _globalWordIndexMeta = const VerificationMeta(
    'globalWordIndex',
  );
  @override
  late final GeneratedColumn<int> globalWordIndex = GeneratedColumn<int>(
    'global_word_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _endGlobalWordIndexMeta =
      const VerificationMeta('endGlobalWordIndex');
  @override
  late final GeneratedColumn<int> endGlobalWordIndex = GeneratedColumn<int>(
    'end_global_word_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endChapterIndexMeta = const VerificationMeta(
    'endChapterIndex',
  );
  @override
  late final GeneratedColumn<int> endChapterIndex = GeneratedColumn<int>(
    'end_chapter_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextSnippetMeta = const VerificationMeta(
    'contextSnippet',
  );
  @override
  late final GeneratedColumn<String> contextSnippet = GeneratedColumn<String>(
    'context_snippet',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    globalWordIndex,
    chapterIndex,
    endGlobalWordIndex,
    endChapterIndex,
    label,
    contextSnippet,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('global_word_index')) {
      context.handle(
        _globalWordIndexMeta,
        globalWordIndex.isAcceptableOrUnknown(
          data['global_word_index']!,
          _globalWordIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_globalWordIndexMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('end_global_word_index')) {
      context.handle(
        _endGlobalWordIndexMeta,
        endGlobalWordIndex.isAcceptableOrUnknown(
          data['end_global_word_index']!,
          _endGlobalWordIndexMeta,
        ),
      );
    }
    if (data.containsKey('end_chapter_index')) {
      context.handle(
        _endChapterIndexMeta,
        endChapterIndex.isAcceptableOrUnknown(
          data['end_chapter_index']!,
          _endChapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('context_snippet')) {
      context.handle(
        _contextSnippetMeta,
        contextSnippet.isAcceptableOrUnknown(
          data['context_snippet']!,
          _contextSnippetMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarksTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarksTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      globalWordIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}global_word_index'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      endGlobalWordIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_global_word_index'],
      ),
      endChapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_chapter_index'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      contextSnippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_snippet'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $BookmarksTableTable createAlias(String alias) {
    return $BookmarksTableTable(attachedDatabase, alias);
  }
}

class BookmarksTableData extends DataClass
    implements Insertable<BookmarksTableData> {
  final String id;
  final String bookId;

  /// Global word index inside the book — what the reader engine actually
  /// seeks to. We persist it directly (rather than reconstructing from
  /// chapter+wordIndex) so a bookmark survives even if a re-import shifts
  /// chapter boundaries. The seek path already clamps to total words.
  final int globalWordIndex;

  /// Chapter index at creation time — kept so the list can show
  /// "Ch. N · 42%" without having to re-resolve `globalWordIndex` against
  /// the current chapter table. Survives re-imports trivially: if the
  /// chapter shape changed, the seek path normalises through
  /// `_globalToLocal`, and only the displayed chapter number drifts.
  final int chapterIndex;

  /// Last word of a multi-word selection (inclusive). Null for the common
  /// single-word case. When set, the UI can render the selected range
  /// verbatim and the seek path still uses [globalWordIndex] (the start)
  /// — the end is informational + used to rebuild the snippet on devices
  /// that import the book later.
  final int? endGlobalWordIndex;

  /// Chapter of the [endGlobalWordIndex] anchor. Null for single-word
  /// bookmarks; useful for ranges that cross a chapter boundary.
  final int? endChapterIndex;

  /// Optional user-supplied note shown as the primary label in the list.
  /// When null, the UI falls back to [contextSnippet].
  final String? label;

  /// Few words around the bookmarked word, captured at creation time, so
  /// the list has a meaningful preview even when [label] is null and the
  /// book hasn't been loaded into the engine yet (e.g. opening Bookmarks
  /// from outside the reader, syncing in fresh on a new device).
  final String? contextSnippet;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Non-null marks the row as a tombstone. Sync ships these to peers so
  /// deletes converge; the DAO hides them from the reader UI.
  final DateTime? deletedAt;
  const BookmarksTableData({
    required this.id,
    required this.bookId,
    required this.globalWordIndex,
    required this.chapterIndex,
    this.endGlobalWordIndex,
    this.endChapterIndex,
    this.label,
    this.contextSnippet,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['global_word_index'] = Variable<int>(globalWordIndex);
    map['chapter_index'] = Variable<int>(chapterIndex);
    if (!nullToAbsent || endGlobalWordIndex != null) {
      map['end_global_word_index'] = Variable<int>(endGlobalWordIndex);
    }
    if (!nullToAbsent || endChapterIndex != null) {
      map['end_chapter_index'] = Variable<int>(endChapterIndex);
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || contextSnippet != null) {
      map['context_snippet'] = Variable<String>(contextSnippet);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  BookmarksTableCompanion toCompanion(bool nullToAbsent) {
    return BookmarksTableCompanion(
      id: Value(id),
      bookId: Value(bookId),
      globalWordIndex: Value(globalWordIndex),
      chapterIndex: Value(chapterIndex),
      endGlobalWordIndex: endGlobalWordIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(endGlobalWordIndex),
      endChapterIndex: endChapterIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(endChapterIndex),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      contextSnippet: contextSnippet == null && nullToAbsent
          ? const Value.absent()
          : Value(contextSnippet),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory BookmarksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarksTableData(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      globalWordIndex: serializer.fromJson<int>(json['globalWordIndex']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      endGlobalWordIndex: serializer.fromJson<int?>(json['endGlobalWordIndex']),
      endChapterIndex: serializer.fromJson<int?>(json['endChapterIndex']),
      label: serializer.fromJson<String?>(json['label']),
      contextSnippet: serializer.fromJson<String?>(json['contextSnippet']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'globalWordIndex': serializer.toJson<int>(globalWordIndex),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'endGlobalWordIndex': serializer.toJson<int?>(endGlobalWordIndex),
      'endChapterIndex': serializer.toJson<int?>(endChapterIndex),
      'label': serializer.toJson<String?>(label),
      'contextSnippet': serializer.toJson<String?>(contextSnippet),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  BookmarksTableData copyWith({
    String? id,
    String? bookId,
    int? globalWordIndex,
    int? chapterIndex,
    Value<int?> endGlobalWordIndex = const Value.absent(),
    Value<int?> endChapterIndex = const Value.absent(),
    Value<String?> label = const Value.absent(),
    Value<String?> contextSnippet = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => BookmarksTableData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    globalWordIndex: globalWordIndex ?? this.globalWordIndex,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    endGlobalWordIndex: endGlobalWordIndex.present
        ? endGlobalWordIndex.value
        : this.endGlobalWordIndex,
    endChapterIndex: endChapterIndex.present
        ? endChapterIndex.value
        : this.endChapterIndex,
    label: label.present ? label.value : this.label,
    contextSnippet: contextSnippet.present
        ? contextSnippet.value
        : this.contextSnippet,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  BookmarksTableData copyWithCompanion(BookmarksTableCompanion data) {
    return BookmarksTableData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      globalWordIndex: data.globalWordIndex.present
          ? data.globalWordIndex.value
          : this.globalWordIndex,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      endGlobalWordIndex: data.endGlobalWordIndex.present
          ? data.endGlobalWordIndex.value
          : this.endGlobalWordIndex,
      endChapterIndex: data.endChapterIndex.present
          ? data.endChapterIndex.value
          : this.endChapterIndex,
      label: data.label.present ? data.label.value : this.label,
      contextSnippet: data.contextSnippet.present
          ? data.contextSnippet.value
          : this.contextSnippet,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksTableData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('globalWordIndex: $globalWordIndex, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('endGlobalWordIndex: $endGlobalWordIndex, ')
          ..write('endChapterIndex: $endChapterIndex, ')
          ..write('label: $label, ')
          ..write('contextSnippet: $contextSnippet, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    globalWordIndex,
    chapterIndex,
    endGlobalWordIndex,
    endChapterIndex,
    label,
    contextSnippet,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarksTableData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.globalWordIndex == this.globalWordIndex &&
          other.chapterIndex == this.chapterIndex &&
          other.endGlobalWordIndex == this.endGlobalWordIndex &&
          other.endChapterIndex == this.endChapterIndex &&
          other.label == this.label &&
          other.contextSnippet == this.contextSnippet &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class BookmarksTableCompanion extends UpdateCompanion<BookmarksTableData> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> globalWordIndex;
  final Value<int> chapterIndex;
  final Value<int?> endGlobalWordIndex;
  final Value<int?> endChapterIndex;
  final Value<String?> label;
  final Value<String?> contextSnippet;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const BookmarksTableCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.globalWordIndex = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.endGlobalWordIndex = const Value.absent(),
    this.endChapterIndex = const Value.absent(),
    this.label = const Value.absent(),
    this.contextSnippet = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksTableCompanion.insert({
    required String id,
    required String bookId,
    required int globalWordIndex,
    this.chapterIndex = const Value.absent(),
    this.endGlobalWordIndex = const Value.absent(),
    this.endChapterIndex = const Value.absent(),
    this.label = const Value.absent(),
    this.contextSnippet = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       globalWordIndex = Value(globalWordIndex),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookmarksTableData> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? globalWordIndex,
    Expression<int>? chapterIndex,
    Expression<int>? endGlobalWordIndex,
    Expression<int>? endChapterIndex,
    Expression<String>? label,
    Expression<String>? contextSnippet,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (globalWordIndex != null) 'global_word_index': globalWordIndex,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (endGlobalWordIndex != null)
        'end_global_word_index': endGlobalWordIndex,
      if (endChapterIndex != null) 'end_chapter_index': endChapterIndex,
      if (label != null) 'label': label,
      if (contextSnippet != null) 'context_snippet': contextSnippet,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? globalWordIndex,
    Value<int>? chapterIndex,
    Value<int?>? endGlobalWordIndex,
    Value<int?>? endChapterIndex,
    Value<String?>? label,
    Value<String?>? contextSnippet,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return BookmarksTableCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      globalWordIndex: globalWordIndex ?? this.globalWordIndex,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      endGlobalWordIndex: endGlobalWordIndex ?? this.endGlobalWordIndex,
      endChapterIndex: endChapterIndex ?? this.endChapterIndex,
      label: label ?? this.label,
      contextSnippet: contextSnippet ?? this.contextSnippet,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (globalWordIndex.present) {
      map['global_word_index'] = Variable<int>(globalWordIndex.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (endGlobalWordIndex.present) {
      map['end_global_word_index'] = Variable<int>(endGlobalWordIndex.value);
    }
    if (endChapterIndex.present) {
      map['end_chapter_index'] = Variable<int>(endChapterIndex.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (contextSnippet.present) {
      map['context_snippet'] = Variable<String>(contextSnippet.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksTableCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('globalWordIndex: $globalWordIndex, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('endGlobalWordIndex: $endGlobalWordIndex, ')
          ..write('endChapterIndex: $endChapterIndex, ')
          ..write('label: $label, ')
          ..write('contextSnippet: $contextSnippet, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTableTable booksTable = $BooksTableTable(this);
  late final $ReadingProgressTableTable readingProgressTable =
      $ReadingProgressTableTable(this);
  late final $ReadingSessionTableTable readingSessionTable =
      $ReadingSessionTableTable(this);
  late final $CachedTokensTableTable cachedTokensTable =
      $CachedTokensTableTable(this);
  late final $SyncImportFailuresTableTable syncImportFailuresTable =
      $SyncImportFailuresTableTable(this);
  late final $BookmarksTableTable bookmarksTable = $BookmarksTableTable(this);
  late final Index readingSessionStartedAtIdx = Index(
    'reading_session_started_at_idx',
    'CREATE INDEX reading_session_started_at_idx ON reading_session_table (started_at)',
  );
  late final Index readingSessionBookIdIdx = Index(
    'reading_session_book_id_idx',
    'CREATE INDEX reading_session_book_id_idx ON reading_session_table (book_id)',
  );
  late final Index bookmarksBookIdIdx = Index(
    'bookmarks_book_id_idx',
    'CREATE INDEX bookmarks_book_id_idx ON bookmarks_table (book_id)',
  );
  late final BooksDao booksDao = BooksDao(this as AppDatabase);
  late final ReadingProgressDao readingProgressDao = ReadingProgressDao(
    this as AppDatabase,
  );
  late final ReadingSessionDao readingSessionDao = ReadingSessionDao(
    this as AppDatabase,
  );
  late final CachedTokensDao cachedTokensDao = CachedTokensDao(
    this as AppDatabase,
  );
  late final SyncImportFailuresDao syncImportFailuresDao =
      SyncImportFailuresDao(this as AppDatabase);
  late final BookmarksDao bookmarksDao = BookmarksDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    booksTable,
    readingProgressTable,
    readingSessionTable,
    cachedTokensTable,
    syncImportFailuresTable,
    bookmarksTable,
    readingSessionStartedAtIdx,
    readingSessionBookIdIdx,
    bookmarksBookIdIdx,
  ];
}

typedef $$BooksTableTableCreateCompanionBuilder =
    BooksTableCompanion Function({
      required String id,
      required String title,
      Value<String?> author,
      required String filePath,
      Value<Uint8List?> coverImage,
      Value<int> totalWords,
      Value<int> chapterCount,
      required DateTime importedAt,
      Value<DateTime?> lastReadAt,
      Value<String?> syncFileName,
      Value<String> source,
      Value<String?> sourceUrl,
      Value<String?> siteName,
      Value<int?> rating,
      Value<DateTime?> ratingUpdatedAt,
      Value<int> rowid,
    });
typedef $$BooksTableTableUpdateCompanionBuilder =
    BooksTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> author,
      Value<String> filePath,
      Value<Uint8List?> coverImage,
      Value<int> totalWords,
      Value<int> chapterCount,
      Value<DateTime> importedAt,
      Value<DateTime?> lastReadAt,
      Value<String?> syncFileName,
      Value<String> source,
      Value<String?> sourceUrl,
      Value<String?> siteName,
      Value<int?> rating,
      Value<DateTime?> ratingUpdatedAt,
      Value<int> rowid,
    });

final class $$BooksTableTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTableTable, BooksTableData> {
  $$BooksTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $ReadingProgressTableTable,
    List<ReadingProgressTableData>
  >
  _readingProgressTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.readingProgressTable,
        aliasName: $_aliasNameGenerator(
          db.booksTable.id,
          db.readingProgressTable.bookId,
        ),
      );

  $$ReadingProgressTableTableProcessedTableManager
  get readingProgressTableRefs {
    final manager = $$ReadingProgressTableTableTableManager(
      $_db,
      $_db.readingProgressTable,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingProgressTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CachedTokensTableTable,
    List<CachedTokensTableData>
  >
  _cachedTokensTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cachedTokensTable,
        aliasName: $_aliasNameGenerator(
          db.booksTable.id,
          db.cachedTokensTable.bookId,
        ),
      );

  $$CachedTokensTableTableProcessedTableManager get cachedTokensTableRefs {
    final manager = $$CachedTokensTableTableTableManager(
      $_db,
      $_db.cachedTokensTable,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cachedTokensTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableTableFilterComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalWords => $composableBuilder(
    column: $table.totalWords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncFileName => $composableBuilder(
    column: $table.syncFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siteName => $composableBuilder(
    column: $table.siteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ratingUpdatedAt => $composableBuilder(
    column: $table.ratingUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> readingProgressTableRefs(
    Expression<bool> Function($$ReadingProgressTableTableFilterComposer f) f,
  ) {
    final $$ReadingProgressTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgressTable,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressTableTableFilterComposer(
            $db: $db,
            $table: $db.readingProgressTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cachedTokensTableRefs(
    Expression<bool> Function($$CachedTokensTableTableFilterComposer f) f,
  ) {
    final $$CachedTokensTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedTokensTable,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedTokensTableTableFilterComposer(
            $db: $db,
            $table: $db.cachedTokensTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalWords => $composableBuilder(
    column: $table.totalWords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncFileName => $composableBuilder(
    column: $table.syncFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siteName => $composableBuilder(
    column: $table.siteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ratingUpdatedAt => $composableBuilder(
    column: $table.ratingUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<Uint8List> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalWords => $composableBuilder(
    column: $table.totalWords,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncFileName => $composableBuilder(
    column: $table.syncFileName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get siteName =>
      $composableBuilder(column: $table.siteName, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get ratingUpdatedAt => $composableBuilder(
    column: $table.ratingUpdatedAt,
    builder: (column) => column,
  );

  Expression<T> readingProgressTableRefs<T extends Object>(
    Expression<T> Function($$ReadingProgressTableTableAnnotationComposer a) f,
  ) {
    final $$ReadingProgressTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.readingProgressTable,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ReadingProgressTableTableAnnotationComposer(
                $db: $db,
                $table: $db.readingProgressTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cachedTokensTableRefs<T extends Object>(
    Expression<T> Function($$CachedTokensTableTableAnnotationComposer a) f,
  ) {
    final $$CachedTokensTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cachedTokensTable,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CachedTokensTableTableAnnotationComposer(
                $db: $db,
                $table: $db.cachedTokensTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$BooksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTableTable,
          BooksTableData,
          $$BooksTableTableFilterComposer,
          $$BooksTableTableOrderingComposer,
          $$BooksTableTableAnnotationComposer,
          $$BooksTableTableCreateCompanionBuilder,
          $$BooksTableTableUpdateCompanionBuilder,
          (BooksTableData, $$BooksTableTableReferences),
          BooksTableData,
          PrefetchHooks Function({
            bool readingProgressTableRefs,
            bool cachedTokensTableRefs,
          })
        > {
  $$BooksTableTableTableManager(_$AppDatabase db, $BooksTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<Uint8List?> coverImage = const Value.absent(),
                Value<int> totalWords = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<String?> syncFileName = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> siteName = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<DateTime?> ratingUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksTableCompanion(
                id: id,
                title: title,
                author: author,
                filePath: filePath,
                coverImage: coverImage,
                totalWords: totalWords,
                chapterCount: chapterCount,
                importedAt: importedAt,
                lastReadAt: lastReadAt,
                syncFileName: syncFileName,
                source: source,
                sourceUrl: sourceUrl,
                siteName: siteName,
                rating: rating,
                ratingUpdatedAt: ratingUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> author = const Value.absent(),
                required String filePath,
                Value<Uint8List?> coverImage = const Value.absent(),
                Value<int> totalWords = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                required DateTime importedAt,
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<String?> syncFileName = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> siteName = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<DateTime?> ratingUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksTableCompanion.insert(
                id: id,
                title: title,
                author: author,
                filePath: filePath,
                coverImage: coverImage,
                totalWords: totalWords,
                chapterCount: chapterCount,
                importedAt: importedAt,
                lastReadAt: lastReadAt,
                syncFileName: syncFileName,
                source: source,
                sourceUrl: sourceUrl,
                siteName: siteName,
                rating: rating,
                ratingUpdatedAt: ratingUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BooksTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                readingProgressTableRefs = false,
                cachedTokensTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (readingProgressTableRefs) db.readingProgressTable,
                    if (cachedTokensTableRefs) db.cachedTokensTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (readingProgressTableRefs)
                        await $_getPrefetchedData<
                          BooksTableData,
                          $BooksTableTable,
                          ReadingProgressTableData
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableTableReferences
                              ._readingProgressTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableTableReferences(
                                db,
                                table,
                                p0,
                              ).readingProgressTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cachedTokensTableRefs)
                        await $_getPrefetchedData<
                          BooksTableData,
                          $BooksTableTable,
                          CachedTokensTableData
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableTableReferences
                              ._cachedTokensTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableTableReferences(
                                db,
                                table,
                                p0,
                              ).cachedTokensTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BooksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTableTable,
      BooksTableData,
      $$BooksTableTableFilterComposer,
      $$BooksTableTableOrderingComposer,
      $$BooksTableTableAnnotationComposer,
      $$BooksTableTableCreateCompanionBuilder,
      $$BooksTableTableUpdateCompanionBuilder,
      (BooksTableData, $$BooksTableTableReferences),
      BooksTableData,
      PrefetchHooks Function({
        bool readingProgressTableRefs,
        bool cachedTokensTableRefs,
      })
    >;
typedef $$ReadingProgressTableTableCreateCompanionBuilder =
    ReadingProgressTableCompanion Function({
      required String bookId,
      required int chapterIndex,
      required int wordIndex,
      Value<int> wpm,
      required DateTime updatedAt,
      Value<String?> readerMode,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableTableUpdateCompanionBuilder =
    ReadingProgressTableCompanion Function({
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<int> wordIndex,
      Value<int> wpm,
      Value<DateTime> updatedAt,
      Value<String?> readerMode,
      Value<int> rowid,
    });

final class $$ReadingProgressTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTableTable,
          ReadingProgressTableData
        > {
  $$ReadingProgressTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTableTable _bookIdTable(_$AppDatabase db) =>
      db.booksTable.createAlias(
        $_aliasNameGenerator(db.readingProgressTable.bookId, db.booksTable.id),
      );

  $$BooksTableTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableTableManager(
      $_db,
      $_db.booksTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordIndex => $composableBuilder(
    column: $table.wordIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wpm => $composableBuilder(
    column: $table.wpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readerMode => $composableBuilder(
    column: $table.readerMode,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableTableFilterComposer get bookId {
    final $$BooksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.booksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableTableFilterComposer(
            $db: $db,
            $table: $db.booksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordIndex => $composableBuilder(
    column: $table.wordIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wpm => $composableBuilder(
    column: $table.wpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readerMode => $composableBuilder(
    column: $table.readerMode,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableTableOrderingComposer get bookId {
    final $$BooksTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.booksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableTableOrderingComposer(
            $db: $db,
            $table: $db.booksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTableTable> {
  $$ReadingProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordIndex =>
      $composableBuilder(column: $table.wordIndex, builder: (column) => column);

  GeneratedColumn<int> get wpm =>
      $composableBuilder(column: $table.wpm, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get readerMode => $composableBuilder(
    column: $table.readerMode,
    builder: (column) => column,
  );

  $$BooksTableTableAnnotationComposer get bookId {
    final $$BooksTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.booksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableTableAnnotationComposer(
            $db: $db,
            $table: $db.booksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTableTable,
          ReadingProgressTableData,
          $$ReadingProgressTableTableFilterComposer,
          $$ReadingProgressTableTableOrderingComposer,
          $$ReadingProgressTableTableAnnotationComposer,
          $$ReadingProgressTableTableCreateCompanionBuilder,
          $$ReadingProgressTableTableUpdateCompanionBuilder,
          (ReadingProgressTableData, $$ReadingProgressTableTableReferences),
          ReadingProgressTableData,
          PrefetchHooks Function({bool bookId})
        > {
  $$ReadingProgressTableTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> wordIndex = const Value.absent(),
                Value<int> wpm = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> readerMode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressTableCompanion(
                bookId: bookId,
                chapterIndex: chapterIndex,
                wordIndex: wordIndex,
                wpm: wpm,
                updatedAt: updatedAt,
                readerMode: readerMode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required int chapterIndex,
                required int wordIndex,
                Value<int> wpm = const Value.absent(),
                required DateTime updatedAt,
                Value<String?> readerMode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressTableCompanion.insert(
                bookId: bookId,
                chapterIndex: chapterIndex,
                wordIndex: wordIndex,
                wpm: wpm,
                updatedAt: updatedAt,
                readerMode: readerMode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingProgressTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable:
                                    $$ReadingProgressTableTableReferences
                                        ._bookIdTable(db),
                                referencedColumn:
                                    $$ReadingProgressTableTableReferences
                                        ._bookIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingProgressTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTableTable,
      ReadingProgressTableData,
      $$ReadingProgressTableTableFilterComposer,
      $$ReadingProgressTableTableOrderingComposer,
      $$ReadingProgressTableTableAnnotationComposer,
      $$ReadingProgressTableTableCreateCompanionBuilder,
      $$ReadingProgressTableTableUpdateCompanionBuilder,
      (ReadingProgressTableData, $$ReadingProgressTableTableReferences),
      ReadingProgressTableData,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$ReadingSessionTableTableCreateCompanionBuilder =
    ReadingSessionTableCompanion Function({
      required String id,
      required String bookId,
      required DateTime startedAt,
      required DateTime endedAt,
      required int durationMs,
      required int wordsRead,
      required int startWordIndex,
      required int endWordIndex,
      required int avgWpm,
      Value<int> rowid,
    });
typedef $$ReadingSessionTableTableUpdateCompanionBuilder =
    ReadingSessionTableCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<int> durationMs,
      Value<int> wordsRead,
      Value<int> startWordIndex,
      Value<int> endWordIndex,
      Value<int> avgWpm,
      Value<int> rowid,
    });

class $$ReadingSessionTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingSessionTableTable> {
  $$ReadingSessionTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordsRead => $composableBuilder(
    column: $table.wordsRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startWordIndex => $composableBuilder(
    column: $table.startWordIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endWordIndex => $composableBuilder(
    column: $table.endWordIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgWpm => $composableBuilder(
    column: $table.avgWpm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingSessionTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingSessionTableTable> {
  $$ReadingSessionTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordsRead => $composableBuilder(
    column: $table.wordsRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startWordIndex => $composableBuilder(
    column: $table.startWordIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endWordIndex => $composableBuilder(
    column: $table.endWordIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgWpm => $composableBuilder(
    column: $table.avgWpm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingSessionTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingSessionTableTable> {
  $$ReadingSessionTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordsRead =>
      $composableBuilder(column: $table.wordsRead, builder: (column) => column);

  GeneratedColumn<int> get startWordIndex => $composableBuilder(
    column: $table.startWordIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endWordIndex => $composableBuilder(
    column: $table.endWordIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avgWpm =>
      $composableBuilder(column: $table.avgWpm, builder: (column) => column);
}

class $$ReadingSessionTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingSessionTableTable,
          ReadingSessionTableData,
          $$ReadingSessionTableTableFilterComposer,
          $$ReadingSessionTableTableOrderingComposer,
          $$ReadingSessionTableTableAnnotationComposer,
          $$ReadingSessionTableTableCreateCompanionBuilder,
          $$ReadingSessionTableTableUpdateCompanionBuilder,
          (
            ReadingSessionTableData,
            BaseReferences<
              _$AppDatabase,
              $ReadingSessionTableTable,
              ReadingSessionTableData
            >,
          ),
          ReadingSessionTableData,
          PrefetchHooks Function()
        > {
  $$ReadingSessionTableTableTableManager(
    _$AppDatabase db,
    $ReadingSessionTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingSessionTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingSessionTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReadingSessionTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> wordsRead = const Value.absent(),
                Value<int> startWordIndex = const Value.absent(),
                Value<int> endWordIndex = const Value.absent(),
                Value<int> avgWpm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingSessionTableCompanion(
                id: id,
                bookId: bookId,
                startedAt: startedAt,
                endedAt: endedAt,
                durationMs: durationMs,
                wordsRead: wordsRead,
                startWordIndex: startWordIndex,
                endWordIndex: endWordIndex,
                avgWpm: avgWpm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required DateTime startedAt,
                required DateTime endedAt,
                required int durationMs,
                required int wordsRead,
                required int startWordIndex,
                required int endWordIndex,
                required int avgWpm,
                Value<int> rowid = const Value.absent(),
              }) => ReadingSessionTableCompanion.insert(
                id: id,
                bookId: bookId,
                startedAt: startedAt,
                endedAt: endedAt,
                durationMs: durationMs,
                wordsRead: wordsRead,
                startWordIndex: startWordIndex,
                endWordIndex: endWordIndex,
                avgWpm: avgWpm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingSessionTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingSessionTableTable,
      ReadingSessionTableData,
      $$ReadingSessionTableTableFilterComposer,
      $$ReadingSessionTableTableOrderingComposer,
      $$ReadingSessionTableTableAnnotationComposer,
      $$ReadingSessionTableTableCreateCompanionBuilder,
      $$ReadingSessionTableTableUpdateCompanionBuilder,
      (
        ReadingSessionTableData,
        BaseReferences<
          _$AppDatabase,
          $ReadingSessionTableTable,
          ReadingSessionTableData
        >,
      ),
      ReadingSessionTableData,
      PrefetchHooks Function()
    >;
typedef $$CachedTokensTableTableCreateCompanionBuilder =
    CachedTokensTableCompanion Function({
      Value<int> id,
      required String bookId,
      required int chapterIndex,
      Value<String> chapterTitle,
      required String tokensJson,
      required int wordCount,
      Value<int> paragraphCount,
    });
typedef $$CachedTokensTableTableUpdateCompanionBuilder =
    CachedTokensTableCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<String> chapterTitle,
      Value<String> tokensJson,
      Value<int> wordCount,
      Value<int> paragraphCount,
    });

final class $$CachedTokensTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CachedTokensTableTable,
          CachedTokensTableData
        > {
  $$CachedTokensTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTableTable _bookIdTable(_$AppDatabase db) =>
      db.booksTable.createAlias(
        $_aliasNameGenerator(db.cachedTokensTable.bookId, db.booksTable.id),
      );

  $$BooksTableTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableTableManager(
      $_db,
      $_db.booksTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CachedTokensTableTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTokensTableTable> {
  $$CachedTokensTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokensJson => $composableBuilder(
    column: $table.tokensJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphCount => $composableBuilder(
    column: $table.paragraphCount,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableTableFilterComposer get bookId {
    final $$BooksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.booksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableTableFilterComposer(
            $db: $db,
            $table: $db.booksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedTokensTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTokensTableTable> {
  $$CachedTokensTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokensJson => $composableBuilder(
    column: $table.tokensJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphCount => $composableBuilder(
    column: $table.paragraphCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableTableOrderingComposer get bookId {
    final $$BooksTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.booksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableTableOrderingComposer(
            $db: $db,
            $table: $db.booksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedTokensTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTokensTableTable> {
  $$CachedTokensTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokensJson => $composableBuilder(
    column: $table.tokensJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<int> get paragraphCount => $composableBuilder(
    column: $table.paragraphCount,
    builder: (column) => column,
  );

  $$BooksTableTableAnnotationComposer get bookId {
    final $$BooksTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.booksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableTableAnnotationComposer(
            $db: $db,
            $table: $db.booksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedTokensTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedTokensTableTable,
          CachedTokensTableData,
          $$CachedTokensTableTableFilterComposer,
          $$CachedTokensTableTableOrderingComposer,
          $$CachedTokensTableTableAnnotationComposer,
          $$CachedTokensTableTableCreateCompanionBuilder,
          $$CachedTokensTableTableUpdateCompanionBuilder,
          (CachedTokensTableData, $$CachedTokensTableTableReferences),
          CachedTokensTableData,
          PrefetchHooks Function({bool bookId})
        > {
  $$CachedTokensTableTableTableManager(
    _$AppDatabase db,
    $CachedTokensTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTokensTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTokensTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTokensTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> chapterTitle = const Value.absent(),
                Value<String> tokensJson = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<int> paragraphCount = const Value.absent(),
              }) => CachedTokensTableCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                tokensJson: tokensJson,
                wordCount: wordCount,
                paragraphCount: paragraphCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required int chapterIndex,
                Value<String> chapterTitle = const Value.absent(),
                required String tokensJson,
                required int wordCount,
                Value<int> paragraphCount = const Value.absent(),
              }) => CachedTokensTableCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                tokensJson: tokensJson,
                wordCount: wordCount,
                paragraphCount: paragraphCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedTokensTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable:
                                    $$CachedTokensTableTableReferences
                                        ._bookIdTable(db),
                                referencedColumn:
                                    $$CachedTokensTableTableReferences
                                        ._bookIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CachedTokensTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedTokensTableTable,
      CachedTokensTableData,
      $$CachedTokensTableTableFilterComposer,
      $$CachedTokensTableTableOrderingComposer,
      $$CachedTokensTableTableAnnotationComposer,
      $$CachedTokensTableTableCreateCompanionBuilder,
      $$CachedTokensTableTableUpdateCompanionBuilder,
      (CachedTokensTableData, $$CachedTokensTableTableReferences),
      CachedTokensTableData,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$SyncImportFailuresTableTableCreateCompanionBuilder =
    SyncImportFailuresTableCompanion Function({
      required String fileName,
      required String errorMessage,
      required DateTime failedAt,
      Value<int> rowid,
    });
typedef $$SyncImportFailuresTableTableUpdateCompanionBuilder =
    SyncImportFailuresTableCompanion Function({
      Value<String> fileName,
      Value<String> errorMessage,
      Value<DateTime> failedAt,
      Value<int> rowid,
    });

class $$SyncImportFailuresTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncImportFailuresTableTable> {
  $$SyncImportFailuresTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncImportFailuresTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncImportFailuresTableTable> {
  $$SyncImportFailuresTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncImportFailuresTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncImportFailuresTableTable> {
  $$SyncImportFailuresTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get failedAt =>
      $composableBuilder(column: $table.failedAt, builder: (column) => column);
}

class $$SyncImportFailuresTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncImportFailuresTableTable,
          SyncImportFailuresTableData,
          $$SyncImportFailuresTableTableFilterComposer,
          $$SyncImportFailuresTableTableOrderingComposer,
          $$SyncImportFailuresTableTableAnnotationComposer,
          $$SyncImportFailuresTableTableCreateCompanionBuilder,
          $$SyncImportFailuresTableTableUpdateCompanionBuilder,
          (
            SyncImportFailuresTableData,
            BaseReferences<
              _$AppDatabase,
              $SyncImportFailuresTableTable,
              SyncImportFailuresTableData
            >,
          ),
          SyncImportFailuresTableData,
          PrefetchHooks Function()
        > {
  $$SyncImportFailuresTableTableTableManager(
    _$AppDatabase db,
    $SyncImportFailuresTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncImportFailuresTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SyncImportFailuresTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SyncImportFailuresTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> fileName = const Value.absent(),
                Value<String> errorMessage = const Value.absent(),
                Value<DateTime> failedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncImportFailuresTableCompanion(
                fileName: fileName,
                errorMessage: errorMessage,
                failedAt: failedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fileName,
                required String errorMessage,
                required DateTime failedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncImportFailuresTableCompanion.insert(
                fileName: fileName,
                errorMessage: errorMessage,
                failedAt: failedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncImportFailuresTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncImportFailuresTableTable,
      SyncImportFailuresTableData,
      $$SyncImportFailuresTableTableFilterComposer,
      $$SyncImportFailuresTableTableOrderingComposer,
      $$SyncImportFailuresTableTableAnnotationComposer,
      $$SyncImportFailuresTableTableCreateCompanionBuilder,
      $$SyncImportFailuresTableTableUpdateCompanionBuilder,
      (
        SyncImportFailuresTableData,
        BaseReferences<
          _$AppDatabase,
          $SyncImportFailuresTableTable,
          SyncImportFailuresTableData
        >,
      ),
      SyncImportFailuresTableData,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableTableCreateCompanionBuilder =
    BookmarksTableCompanion Function({
      required String id,
      required String bookId,
      required int globalWordIndex,
      Value<int> chapterIndex,
      Value<int?> endGlobalWordIndex,
      Value<int?> endChapterIndex,
      Value<String?> label,
      Value<String?> contextSnippet,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableTableUpdateCompanionBuilder =
    BookmarksTableCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> globalWordIndex,
      Value<int> chapterIndex,
      Value<int?> endGlobalWordIndex,
      Value<int?> endChapterIndex,
      Value<String?> label,
      Value<String?> contextSnippet,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$BookmarksTableTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTableTable> {
  $$BookmarksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get globalWordIndex => $composableBuilder(
    column: $table.globalWordIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endGlobalWordIndex => $composableBuilder(
    column: $table.endGlobalWordIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endChapterIndex => $composableBuilder(
    column: $table.endChapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextSnippet => $composableBuilder(
    column: $table.contextSnippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTableTable> {
  $$BookmarksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get globalWordIndex => $composableBuilder(
    column: $table.globalWordIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endGlobalWordIndex => $composableBuilder(
    column: $table.endGlobalWordIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endChapterIndex => $composableBuilder(
    column: $table.endChapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextSnippet => $composableBuilder(
    column: $table.contextSnippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTableTable> {
  $$BookmarksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get globalWordIndex => $composableBuilder(
    column: $table.globalWordIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endGlobalWordIndex => $composableBuilder(
    column: $table.endGlobalWordIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endChapterIndex => $composableBuilder(
    column: $table.endChapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get contextSnippet => $composableBuilder(
    column: $table.contextSnippet,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$BookmarksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTableTable,
          BookmarksTableData,
          $$BookmarksTableTableFilterComposer,
          $$BookmarksTableTableOrderingComposer,
          $$BookmarksTableTableAnnotationComposer,
          $$BookmarksTableTableCreateCompanionBuilder,
          $$BookmarksTableTableUpdateCompanionBuilder,
          (
            BookmarksTableData,
            BaseReferences<
              _$AppDatabase,
              $BookmarksTableTable,
              BookmarksTableData
            >,
          ),
          BookmarksTableData,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableTableManager(
    _$AppDatabase db,
    $BookmarksTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> globalWordIndex = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int?> endGlobalWordIndex = const Value.absent(),
                Value<int?> endChapterIndex = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> contextSnippet = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksTableCompanion(
                id: id,
                bookId: bookId,
                globalWordIndex: globalWordIndex,
                chapterIndex: chapterIndex,
                endGlobalWordIndex: endGlobalWordIndex,
                endChapterIndex: endChapterIndex,
                label: label,
                contextSnippet: contextSnippet,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int globalWordIndex,
                Value<int> chapterIndex = const Value.absent(),
                Value<int?> endGlobalWordIndex = const Value.absent(),
                Value<int?> endChapterIndex = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> contextSnippet = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksTableCompanion.insert(
                id: id,
                bookId: bookId,
                globalWordIndex: globalWordIndex,
                chapterIndex: chapterIndex,
                endGlobalWordIndex: endGlobalWordIndex,
                endChapterIndex: endChapterIndex,
                label: label,
                contextSnippet: contextSnippet,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTableTable,
      BookmarksTableData,
      $$BookmarksTableTableFilterComposer,
      $$BookmarksTableTableOrderingComposer,
      $$BookmarksTableTableAnnotationComposer,
      $$BookmarksTableTableCreateCompanionBuilder,
      $$BookmarksTableTableUpdateCompanionBuilder,
      (
        BookmarksTableData,
        BaseReferences<_$AppDatabase, $BookmarksTableTable, BookmarksTableData>,
      ),
      BookmarksTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableTableManager get booksTable =>
      $$BooksTableTableTableManager(_db, _db.booksTable);
  $$ReadingProgressTableTableTableManager get readingProgressTable =>
      $$ReadingProgressTableTableTableManager(_db, _db.readingProgressTable);
  $$ReadingSessionTableTableTableManager get readingSessionTable =>
      $$ReadingSessionTableTableTableManager(_db, _db.readingSessionTable);
  $$CachedTokensTableTableTableManager get cachedTokensTable =>
      $$CachedTokensTableTableTableManager(_db, _db.cachedTokensTable);
  $$SyncImportFailuresTableTableTableManager get syncImportFailuresTable =>
      $$SyncImportFailuresTableTableTableManager(
        _db,
        _db.syncImportFailuresTable,
      );
  $$BookmarksTableTableTableManager get bookmarksTable =>
      $$BookmarksTableTableTableManager(_db, _db.bookmarksTable);
}
