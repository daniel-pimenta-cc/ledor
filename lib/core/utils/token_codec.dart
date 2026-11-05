import 'dart:convert';

import '../../features/epub_import/domain/entities/word_token.dart';

/// Serializes a chapter's tokens for the `tokensJson` column.
///
/// v2 format (compact): instead of a JSON map with 9+ keys per word
/// (~150 bytes/word), it stores only what can't be derived from structure:
///
/// ```json
/// {"v":2,"g":123,"p":[[["word",2,1.0], ...], [{"i":"path"}]]}
/// ```
///
/// - `g`: globalIndex of the chapter's first token (the rest are
///   sequential — an invariant of both parsers).
/// - `p`: list of paragraphs; `paragraphIndex` = position in the list,
///   `isParagraphStart` = first token of the paragraph, `isChapterStart` =
///   first token of the chapter.
/// - word = `[text, orpIndex, timingMultiplier]`; image = map
///   `{"i": path}` (images always have `text:'', orp:0, mult:1.0`).
/// - `chapterIndex` comes from the `cached_tokens` row itself on decode.
///
/// This shrinks the JSON ~8-10x and cuts parse cost when opening a book.
/// [encode] checks the invariants above token by token; any violation
/// falls back to the v1 format (list of maps via `WordToken.toJson`) — no
/// data is ever lost. [decode] detects the format from the first character
/// (`{` = v2, `[` = v1).
abstract final class TokenCodec {
  static const _version = 2;

  /// True when the string is already in the compact v2 format.
  static bool isCompact(String s) => s.trimLeft().startsWith('{');

  static String encode(List<WordToken> tokens) {
    final compact = _tryEncodeCompact(tokens);
    if (compact != null) return compact;
    // Fallback: legacy v1 format, no structural assumptions.
    return jsonEncode([for (final t in tokens) t.toJson()]);
  }

  static List<WordToken> decode(
    String tokensJson, {
    required int chapterIndex,
  }) {
    if (!isCompact(tokensJson)) {
      return [
        for (final j in jsonDecode(tokensJson) as List)
          WordToken.fromJson(j as Map<String, dynamic>),
      ];
    }

    final envelope = jsonDecode(tokensJson) as Map<String, dynamic>;
    final version = envelope['v'];
    if (version != _version) {
      throw FormatException('Unknown tokensJson version: $version');
    }

    var globalIndex = (envelope['g'] as num).toInt();
    final paragraphs = envelope['p'] as List;
    final tokens = <WordToken>[];

    for (var p = 0; p < paragraphs.length; p++) {
      final paragraph = paragraphs[p] as List;
      for (var j = 0; j < paragraph.length; j++) {
        final raw = paragraph[j];
        final isChapterStart = tokens.isEmpty;
        final isParagraphStart = j == 0;
        if (raw is List) {
          tokens.add(WordToken(
            text: raw[0] as String,
            orpIndex: (raw[1] as num).toInt(),
            timingMultiplier: (raw[2] as num).toDouble(),
            globalIndex: globalIndex++,
            chapterIndex: chapterIndex,
            paragraphIndex: p,
            isParagraphStart: isParagraphStart,
            isChapterStart: isChapterStart,
          ));
        } else {
          final m = raw as Map<String, dynamic>;
          tokens.add(WordToken(
            text: '',
            orpIndex: 0,
            timingMultiplier: 1.0,
            globalIndex: globalIndex++,
            chapterIndex: chapterIndex,
            paragraphIndex: p,
            isParagraphStart: isParagraphStart,
            isChapterStart: isChapterStart,
            isImage: true,
            imageRelativePath: m['i'] as String?,
          ));
        }
      }
    }
    return tokens;
  }

  /// v2 encoding, or `null` if the tokens break an invariant that decode
  /// reconstructs (globalIndex sequence, dense paragraphIndex, start flags,
  /// fixed image fields).
  static String? _tryEncodeCompact(List<WordToken> tokens) {
    if (tokens.isEmpty) {
      return jsonEncode({'v': _version, 'g': 0, 'p': const []});
    }

    final firstGlobal = tokens.first.globalIndex;
    final chapterIndex = tokens.first.chapterIndex;
    final paragraphs = <List<Object?>>[];
    var lastParagraph = -1;

    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.globalIndex != firstGlobal + i) return null;
      if (t.chapterIndex != chapterIndex) return null;
      if (t.pendingImageBytes != null) return null;

      final newParagraph = t.paragraphIndex != lastParagraph;
      if (newParagraph && t.paragraphIndex != lastParagraph + 1) return null;
      if (t.isParagraphStart != newParagraph) return null;
      if (t.isChapterStart != (i == 0)) return null;
      lastParagraph = t.paragraphIndex;

      final Object encoded;
      if (t.isImage) {
        if (t.text.isNotEmpty || t.orpIndex != 0 || t.timingMultiplier != 1.0) {
          return null;
        }
        encoded = {'i': t.imageRelativePath};
      } else {
        if (t.imageRelativePath != null) {
          return null;
        }
        encoded = [t.text, t.orpIndex, t.timingMultiplier];
      }

      if (newParagraph) paragraphs.add(<Object?>[]);
      paragraphs.last.add(encoded);
    }

    return jsonEncode({'v': _version, 'g': firstGlobal, 'p': paragraphs});
  }
}
