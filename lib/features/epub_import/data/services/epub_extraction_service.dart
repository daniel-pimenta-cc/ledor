import 'dart:typed_data';

import 'package:epub_pro/epub_pro.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/chapter.dart';
import '../../domain/entities/parsed_book.dart';
import 'chapter_parser.dart';

/// Parses an EPUB file and extracts all text content as tokenized chapters.
class EpubExtractionService {
  /// Parse EPUB bytes and return a [ParsedBook] with all chapters tokenized.
  Future<ParsedBook> extractBook(Uint8List epubBytes) async {
    final epubBook = await EpubReader.readBook(epubBytes);

    final title = epubBook.title ?? 'Unknown Title';
    final author = epubBook.author ?? 'Unknown Author';

    // Convert cover image to PNG bytes if available
    Uint8List? coverBytes;
    if (epubBook.coverImage != null) {
      coverBytes = Uint8List.fromList(img.encodePng(epubBook.coverImage!));
    }

    final imageResolver = _buildImageResolver(epubBook);

    final chapters = <Chapter>[];
    int globalOffset = 0;

    for (final epubChapter in epubBook.chapters) {
      final chapter = _processChapter(
        epubChapter,
        chapters.length,
        globalOffset,
        imageResolver,
      );
      if (chapter.tokens.isNotEmpty) {
        globalOffset += chapter.tokens.length;
        chapters.add(chapter);
      }

      for (final sub in epubChapter.subChapters) {
        final subChapter = _processChapter(
          sub,
          chapters.length,
          globalOffset,
          imageResolver,
        );
        if (subChapter.tokens.isNotEmpty) {
          globalOffset += subChapter.tokens.length;
          chapters.add(subChapter);
        }
      }
    }

    return ParsedBook(
      title: title,
      author: author,
      coverImage: coverBytes,
      chapters: chapters,
      totalWords: globalOffset,
    );
  }

  Chapter _processChapter(
    EpubChapter epubChapter,
    int chapterIndex,
    int globalOffset,
    ImageResolver imageResolver,
  ) {
    final htmlContent = epubChapter.htmlContent ?? '';
    final tokens = ChapterParser.parse(
      htmlContent,
      chapterIndex: chapterIndex,
      globalOffset: globalOffset,
      imageResolver: imageResolver,
    );
    return Chapter(
      title: epubChapter.title ?? 'Chapter ${chapterIndex + 1}',
      tokens: tokens,
    );
  }

  /// Builds the closure the [ChapterParser] uses to turn an `<img src>`
  /// reference into the matching bytes inside the EPUB manifest.
  ///
  /// EPUBs are inconsistent about how they spell image paths: the manifest
  /// keys are relative to the OPF file, but `<img src>` is relative to the
  /// chapter HTML. Rather than rebuilding a full URL resolver we try a
  /// short ladder of fallbacks (direct hit, leading `./`/`../` stripped,
  /// basename) — that covers every EPUB I've seen and avoids dragging in
  /// `package:path` for one feature.
  ImageResolver _buildImageResolver(EpubBook epubBook) {
    final images = epubBook.content?.images ?? const <String, dynamic>{};
    if (images.isEmpty) return (_) => null;

    final byBasename = <String, EpubByteContentFile>{};
    for (final entry in images.entries) {
      final value = entry.value;
      if (value is! EpubByteContentFile) continue;
      final base = entry.key.split('/').last.toLowerCase();
      byBasename.putIfAbsent(base, () => value);
    }

    EpubByteContentFile? lookup(String key) {
      final raw = images[key];
      if (raw is EpubByteContentFile) return raw;
      return null;
    }

    return (src) {
      if (src.isEmpty) return null;
      // Strip fragments and query strings.
      final rawPath = src.split('#').first.split('?').first;

      // The manifest map is keyed by the href exactly as the OPF spells it,
      // but `<img src>` doesn't have to match that spelling: either side may
      // be percent-encoded while the other is raw. Try the spellings that
      // cover all combinations, same-spelling first (the common case).
      // A literal `%` not followed by two hex digits (legal in zip entry
      // names) makes decodeFull throw — skip that candidate instead of
      // aborting the whole import.
      String? decoded;
      try {
        decoded = Uri.decodeFull(rawPath);
      } on ArgumentError {
        decoded = null;
      }
      final encoded = Uri.encodeFull(decoded ?? rawPath);
      final candidates = <String>{
        rawPath, // src and manifest agree (raw or escaped)
        ?decoded, // src escaped, manifest raw
        encoded, // src raw, manifest escaped
      };

      for (final cleaned in candidates) {
        // 1. Direct hit on the manifest key.
        var file = lookup(cleaned);

        // 2. Drop any number of leading `./` or `../` segments.
        if (file == null) {
          final stripped = cleaned.replaceAll(RegExp(r'^(\.{1,2}/)+'), '');
          if (stripped != cleaned) file = lookup(stripped);
        }

        // 3. Basename fallback — handles cross-directory references.
        if (file == null) {
          final base = cleaned.split('/').last.toLowerCase();
          file = byBasename[base];
        }

        if (file == null) continue;
        final content = file.content;
        if (content == null || content.isEmpty) return null;
        return ResolvedImage(bytes: Uint8List.fromList(content));
      }
      return null;
    };
  }
}
