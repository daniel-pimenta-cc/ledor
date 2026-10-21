import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/epub_import/data/services/chapter_parser.dart';

void main() {
  // Tiny PNG-like blob; bytes content doesn't matter for parsing — the
  // resolver only has to hand back something non-null.
  final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);

  group('ChapterParser', () {
    test('produces only text tokens when the chapter has no images', () {
      final tokens = ChapterParser.parse(
        '<p>Hello world</p><p>Second paragraph</p>',
        chapterIndex: 0,
        globalOffset: 0,
        imageResolver: (_) => null,
      );

      expect(tokens.map((t) => t.text),
          orderedEquals(['Hello', 'world', 'Second', 'paragraph']));
      expect(tokens.every((t) => !t.isImage), isTrue);
      expect(tokens.first.isChapterStart, isTrue);
      expect(tokens.first.isParagraphStart, isTrue);
      expect(tokens[2].isParagraphStart, isTrue);
      expect(tokens[2].paragraphIndex, 1);
    });

    test('emits an image token at the position of an <img>', () {
      final tokens = ChapterParser.parse(
        '<p>Before image.</p><p><img src="fig.png" /></p><p>After.</p>',
        chapterIndex: 2,
        globalOffset: 100,
        imageResolver: (src) =>
            src == 'fig.png' ? ResolvedImage(bytes: pngBytes) : null,
      );

      final imageTokens = tokens.where((t) => t.isImage).toList();
      expect(imageTokens, hasLength(1));
      final img = imageTokens.single;
      expect(img.pendingImageBytes, pngBytes);
      expect(img.chapterIndex, 2);
      expect(img.globalIndex, greaterThan(100));
      // The image sits between "Before image." and "After." in the stream.
      final imgPos = tokens.indexOf(img);
      expect(tokens[imgPos - 1].text, 'image.');
      expect(tokens[imgPos + 1].text, 'After.');
    });

    test('skips <img> when the resolver returns null', () {
      final tokens = ChapterParser.parse(
        '<p>One <img src="missing.png"/> two</p>',
        chapterIndex: 0,
        globalOffset: 0,
        imageResolver: (_) => null,
      );

      expect(tokens.where((t) => t.isImage), isEmpty);
      expect(tokens.map((t) => t.text), ['One', 'two']);
    });

    test('only the first text/image gets isChapterStart', () {
      final tokens = ChapterParser.parse(
        '<p><img src="lead.png"/></p><p>Body text here.</p>',
        chapterIndex: 0,
        globalOffset: 0,
        imageResolver: (_) => ResolvedImage(bytes: pngBytes),
      );

      expect(tokens.first.isImage, isTrue);
      expect(tokens.first.isChapterStart, isTrue);
      // No other token should claim chapter-start.
      expect(tokens.skip(1).any((t) => t.isChapterStart), isFalse);
    });

    test('paragraph index advances across image-only paragraphs', () {
      final tokens = ChapterParser.parse(
        '<p>First.</p><p><img src="a"/></p><p>Third.</p>',
        chapterIndex: 0,
        globalOffset: 0,
        imageResolver: (_) => ResolvedImage(bytes: pngBytes),
      );

      // "First." → para 0, image → para 1, "Third." → para 2.
      final firstWord = tokens.firstWhere((t) => t.text == 'First.');
      final image = tokens.firstWhere((t) => t.isImage);
      final third = tokens.firstWhere((t) => t.text == 'Third.');
      expect(firstWord.paragraphIndex, 0);
      expect(image.paragraphIndex, 1);
      expect(third.paragraphIndex, 2);
    });

    test('returns an empty list for blank HTML', () {
      final tokens = ChapterParser.parse(
        '   ',
        chapterIndex: 0,
        globalOffset: 0,
        imageResolver: (_) => null,
      );
      expect(tokens, isEmpty);
    });

    test('recovers body text when head has a self-closing <title/> (FB2EPUB)',
        () {
      // FB2EPUB 0.5.x emits `<title/>` with no closing tag. HTML parsers
      // treat it as an opening raw-text tag and swallow the whole body
      // into the skipped title element — this used to yield zero tokens.
      const fb2Chapter = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title/>
<link rel="stylesheet" href="style.css" type="text/css"/>
</head>
<body class="z">
<span><p class="p1">Hello world.</p><p class="p1">Second paragraph here.</p></span>
</body>
</html>''';
      final tokens = ChapterParser.parse(
        fb2Chapter,
        chapterIndex: 0,
        globalOffset: 0,
        imageResolver: (_) => null,
      );

      expect(tokens.map((t) => t.text),
          orderedEquals(['Hello', 'world.', 'Second', 'paragraph', 'here.']));
      expect(tokens.first.isChapterStart, isTrue);
    });

    test('self-closing style/script do not swallow body text', () {
      final tokens = ChapterParser.parse(
        '<head><style/><script src="x.js"/></head>'
        '<body><p>Visible text.</p></body>',
        chapterIndex: 0,
        globalOffset: 0,
        imageResolver: (_) => null,
      );

      expect(tokens.map((t) => t.text), orderedEquals(['Visible', 'text.']));
    });

    test('well-formed <title>text</title> is still skipped', () {
      final tokens = ChapterParser.parse(
        '<html><head><title>Real Title</title></head>'
        '<body><p>Body words.</p></body></html>',
        chapterIndex: 0,
        globalOffset: 0,
        imageResolver: (_) => null,
      );

      expect(tokens.map((t) => t.text), orderedEquals(['Body', 'words.']));
    });
  });
}
