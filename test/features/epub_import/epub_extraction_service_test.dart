import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/features/epub_import/data/services/epub_extraction_service.dart';

import '../../fixtures/build_minimal_epub.dart';

/// Valid 1x1 transparent PNG — epub_pro decodes the first manifest image
/// as a cover candidate, so the bytes must be a real image.
final _fakePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  group('EpubExtractionService image resolver', () {
    // Regression: Uri.decodeFull throws ArgumentError on a literal `%` not
    // followed by two hex digits. Before the fix this aborted the whole
    // book import from inside the resolver closure.
    test(
        'malformed percent-escape in <img src> degrades to a skipped image, '
        'not an aborted import', () async {
      final epub = buildMinimalEpub(
        title: 'Percent Book',
        author: 'Author',
        bodyIsRawHtml: true,
        chapters: [
          (
            title: 'Chapter One',
            body: '<p>before <img src="missing%.jpg"/> after</p>',
          ),
        ],
        // A real manifest image so the resolver doesn't short-circuit on
        // an empty image map before reaching the decode.
        images: [(name: 'real.png', bytes: _fakePng)],
      );

      final parsed = await EpubExtractionService().extractBook(epub);

      final tokens = parsed.chapters.single.tokens;
      expect(
        tokens.where((t) => !t.isImage).map((t) => t.text),
        containsAll(['before', 'after']),
      );
      // The broken reference resolves to nothing — no image token emitted.
      expect(tokens.any((t) => t.isImage), isFalse);
    });

    // The realistic malformed-EPUB shape: the manifest escapes the file
    // name correctly (href 100%25.png, which is also the raw map key
    // epub_pro exposes), but the chapter HTML references it raw (100%.png).
    // decodeFull throws on the raw src, so the resolver's re-encoded
    // candidate (Uri.encodeFull -> 100%25.png) is what hits the key.
    test(
        'raw % src referencing a correctly-escaped manifest entry resolves '
        'via the re-encoded candidate', () async {
      final epub = buildMinimalEpub(
        title: 'Percent Book',
        author: 'Author',
        bodyIsRawHtml: true,
        chapters: [
          (
            title: 'Chapter One',
            body: '<p>before <img src="images/100%.png"/> after</p>',
          ),
        ],
        images: [(name: '100%.png', bytes: _fakePng)],
      );

      final parsed = await EpubExtractionService().extractBook(epub);

      final tokens = parsed.chapters.single.tokens;
      expect(tokens.any((t) => t.isImage), isTrue,
          reason: 'the undecoded src should hit the decoded manifest key');
      expect(
        tokens.where((t) => !t.isImage).map((t) => t.text),
        containsAll(['before', 'after']),
      );
    });

    // The well-formed EPUB shape: src and manifest href agree on the same
    // escaped spelling (my%20pic.png), which is also the raw map key, so
    // the rawPath candidate hits directly. The old decode-only resolver
    // missed this case (it looked up the decoded "my pic.png" against the
    // raw key) — this pins the fix for that latent miss.
    test('escaped src matching an equally-escaped manifest href resolves',
        () async {
      final epub = buildMinimalEpub(
        title: 'Percent Book',
        author: 'Author',
        bodyIsRawHtml: true,
        chapters: [
          (
            title: 'Chapter One',
            body: '<p>before <img src="images/my%20pic.png"/> after</p>',
          ),
        ],
        // Stored as "my pic.png"; the fixture encodes the href to %20 form.
        images: [(name: 'my pic.png', bytes: _fakePng)],
      );

      final parsed = await EpubExtractionService().extractBook(epub);

      expect(parsed.chapters.single.tokens.any((t) => t.isImage), isTrue);
    });
  });
}
