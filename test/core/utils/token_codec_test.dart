import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/core/utils/text_tokenizer.dart';
import 'package:rsvp_reader/core/utils/token_codec.dart';
import 'package:rsvp_reader/features/epub_import/domain/entities/word_token.dart';

void main() {
  group('TokenCodec', () {
    test('round-trips tokenizer output exactly', () {
      final tokens = TextTokenizer.tokenize(
        'Primeira frase do parágrafo um.\n\n'
        'Segundo parágrafo, com guarda-chuva e mais palavras.\n\n'
        'Terceiro.',
        chapterIndex: 3,
        globalOffset: 1200,
      );

      final encoded = TokenCodec.encode(tokens);
      final decoded = TokenCodec.decode(encoded, chapterIndex: 3);

      expect(TokenCodec.isCompact(encoded), isTrue);
      expect(decoded, equals(tokens));
    });

    test('compact format is much smaller than the legacy one', () {
      final tokens = TextTokenizer.tokenize(
        List.generate(500, (i) => 'palavra$i').join(' '),
        chapterIndex: 0,
        globalOffset: 0,
      );

      final compact = TokenCodec.encode(tokens);
      final legacy = jsonEncode([for (final t in tokens) t.toJson()]);

      expect(compact.length, lessThan(legacy.length ~/ 4));
    });

    test('round-trips image tokens', () {
      const image = WordToken(
        text: '',
        orpIndex: 0,
        timingMultiplier: 1.0,
        globalIndex: 10,
        chapterIndex: 1,
        paragraphIndex: 0,
        isParagraphStart: true,
        isChapterStart: true,
        isImage: true,
        imageRelativePath: 'book_images/abc/0.png',
        imageWidth: 300,
        imageHeight: 200,
      );
      final words = TextTokenizer.tokenize(
        'Texto depois da imagem.',
        chapterIndex: 1,
        globalOffset: 11,
      );
      // A imagem ocupa o parágrafo 0; o texto começa no parágrafo 1 e não
      // é mais chapter start — espelha o que o ChapterParser produz.
      final tokens = [
        image,
        for (final t in words)
          t.copyWith(paragraphIndex: 1, isChapterStart: false),
      ];

      final encoded = TokenCodec.encode(tokens);
      final decoded = TokenCodec.decode(encoded, chapterIndex: 1);

      expect(TokenCodec.isCompact(encoded), isTrue);
      expect(decoded, equals(tokens));
    });

    test('decodes the legacy v1 map-list format', () {
      final tokens = TextTokenizer.tokenize(
        'Um livro antigo no banco.\n\nSegundo parágrafo.',
        chapterIndex: 2,
        globalOffset: 40,
      );
      final legacyJson = jsonEncode([for (final t in tokens) t.toJson()]);

      expect(TokenCodec.isCompact(legacyJson), isFalse);
      expect(
        TokenCodec.decode(legacyJson, chapterIndex: 2),
        equals(tokens),
      );
    });

    test('falls back to v1 when invariants do not hold', () {
      final tokens = TextTokenizer.tokenize(
        'Sequência com buraco no índice global.',
        chapterIndex: 0,
        globalOffset: 0,
      );
      // Quebra a sequência de globalIndex no último token.
      final broken = [
        ...tokens.sublist(0, tokens.length - 1),
        tokens.last.copyWith(globalIndex: tokens.last.globalIndex + 5),
      ];

      final encoded = TokenCodec.encode(broken);

      expect(TokenCodec.isCompact(encoded), isFalse);
      expect(TokenCodec.decode(encoded, chapterIndex: 0), equals(broken));
    });

    test('encodes an empty chapter as compact and decodes it back', () {
      final encoded = TokenCodec.encode(const []);
      expect(TokenCodec.isCompact(encoded), isTrue);
      expect(TokenCodec.decode(encoded, chapterIndex: 7), isEmpty);
    });

    test('isCompact tolerates leading whitespace', () {
      expect(TokenCodec.isCompact('  \n\t{"v":2,"g":0,"p":[]}'), isTrue);
      expect(TokenCodec.isCompact('  \n\t[{"text":"a"}]'), isFalse);
      expect(TokenCodec.isCompact(''), isFalse);
    });
  });
}
