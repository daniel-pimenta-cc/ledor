import 'dart:convert';

import '../../features/epub_import/domain/entities/word_token.dart';

/// Serialização dos tokens de um capítulo para a coluna `tokensJson`.
///
/// Formato v2 (compacto): em vez de um map JSON com 9+ chaves por palavra
/// (~150 bytes/palavra), grava só o que não é derivável da estrutura:
///
/// ```json
/// {"v":2,"g":123,"p":[[["palavra",2,1.0], ...], [{"i":"path"}]]}
/// ```
///
/// - `g`: globalIndex do primeiro token do capítulo (os demais são
///   sequenciais — invariante dos dois parsers).
/// - `p`: lista de parágrafos; `paragraphIndex` = posição na lista,
///   `isParagraphStart` = primeiro token do parágrafo, `isChapterStart` =
///   primeiro token do capítulo.
/// - palavra = `[text, orpIndex, timingMultiplier]`; imagem = map
///   `{"i": path}` (imagens têm sempre `text:'', orp:0, mult:1.0`).
/// - `chapterIndex` vem da própria row de `cached_tokens` no decode.
///
/// Isso reduz o JSON ~8-10x e corta o custo de parse na abertura do livro.
/// [encode] valida as invariantes acima token a token; qualquer desvio cai
/// no formato v1 (lista de maps via `WordToken.toJson`) — nunca perde dados.
/// [decode] detecta o formato pelo primeiro caractere (`{` = v2, `[` = v1).
abstract final class TokenCodec {
  static const _version = 2;

  /// True quando [tokensJson] já está no formato compacto v2.
  static bool isCompact(String s) => s.trimLeft().startsWith('{');

  static String encode(List<WordToken> tokens) {
    final compact = _tryEncodeCompact(tokens);
    if (compact != null) return compact;
    // Fallback: formato v1 legado, sem suposição estrutural.
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

  /// Encode v2, ou `null` se os tokens violarem alguma invariante que o
  /// decode reconstrói (sequência de globalIndex, paragraphIndex denso,
  /// flags de início, campos fixos de imagem).
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
