import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/token_codec.dart';
import '../../../../database/app_database.dart';
import '../../../../database/daos/books_dao.dart';
import '../../../../database/daos/cached_tokens_dao.dart';
import '../../../../database/tables/book_source.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/parsed_book.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import 'inline_image_storage.dart';

/// Inserts a [ParsedBook] and all its tokenized chapters. Shared between
/// the EPUB and article import pipelines — both produce a `ParsedBook` and
/// then need the same Book row + per-chapter cached-tokens fan-out.
///
/// Image tokens carry their bytes in `pendingImageBytes` from the parser.
/// We write each one to `<docs>/book_images/<bookId>/...` here, replace the
/// in-memory bytes with the saved relative path, and only then serialize
/// the chapter to JSON — bytes never get inlined into the database.
///
/// Returns the generated book id.
Future<String> persistParsedBook({
  required ParsedBook book,
  required BooksDao booksDao,
  required CachedTokensDao tokensDao,
  String source = BookSource.epub,
  String? id,
  String? filePath,
  String? syncFileName,
  String? sourceUrl,
  String? siteName,
  Uint8List? coverImage,
  InlineImageStorage imageStorage = const InlineImageStorage(),
}) async {
  final bookId = id ?? const Uuid().v4();
  final effectiveCover = coverImage ?? book.coverImage;

  await booksDao.insertBook(BooksTableCompanion.insert(
    id: bookId,
    title: book.title,
    author: book.author.isEmpty ? const Value.absent() : Value(book.author),
    filePath: filePath ?? '',
    coverImage: Value(effectiveCover),
    totalWords: Value(book.totalWords),
    chapterCount: Value(book.chapters.length),
    importedAt: DateTime.now(),
    syncFileName: Value(syncFileName),
    source: Value(source),
    sourceUrl: Value(sourceUrl),
    siteName: Value(siteName),
  ));

  await persistChaptersWithImages(
    bookId: bookId,
    chapters: book.chapters,
    tokensDao: tokensDao,
    imageStorage: imageStorage,
  );

  return bookId;
}

/// Writes pending image bytes to disk, swaps each image token's
/// `pendingImageBytes` for an `imageRelativePath`, and inserts one
/// `cached_tokens` row per chapter.
///
/// Shared between [persistParsedBook] and the Drive sync paths
/// (`_importFromRemoteEpub`, `_autoImportOrphan`) so both honour image
/// extraction. Keeping the byte-saving step in one place avoids the
/// "tokens reference an image file that doesn't exist on disk" failure
/// mode when an EPUB enters the library via sync.
Future<void> persistChaptersWithImages({
  required String bookId,
  required List<Chapter> chapters,
  required CachedTokensDao tokensDao,
  InlineImageStorage imageStorage = const InlineImageStorage(),
}) async {
  int imageSeq = 0;
  for (int i = 0; i < chapters.length; i++) {
    final chapter = chapters[i];
    final persistedTokens = <WordToken>[];
    for (final token in chapter.tokens) {
      if (token.isImage && token.pendingImageBytes != null) {
        final relPath = await imageStorage.writeImage(
          bookId: bookId,
          sequenceIndex: imageSeq++,
          bytes: token.pendingImageBytes!,
        );
        persistedTokens.add(token.copyWith(
          imageRelativePath: relPath,
          pendingImageBytes: null,
        ));
      } else {
        persistedTokens.add(token);
      }
    }
    final tokensJson = TokenCodec.encode(persistedTokens);
    await tokensDao.insertChapterTokens(CachedTokensTableCompanion.insert(
      bookId: bookId,
      chapterIndex: i,
      chapterTitle: Value(chapter.title),
      tokensJson: tokensJson,
      wordCount: persistedTokens.length,
      paragraphCount: Value(
        persistedTokens.isEmpty
            ? 0
            : persistedTokens.last.paragraphIndex + 1,
      ),
    ));
  }
}
