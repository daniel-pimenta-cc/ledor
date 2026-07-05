import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledor/features/article_import/data/services/article_extraction_service.dart';

const _articleHtml = '''
<html>
  <head><title>My Post</title><meta name="author" content="Jane Doe"></head>
  <body>
    <article>
      <p>This is the first real paragraph of the article and it has enough
      text to count as substantial content for scoring purposes.</p>
      <p>Another paragraph, with a comma, also substantial enough to matter.</p>
    </article>
  </body>
</html>
''';

ArticleExtractionService _serving(
  http.Response Function(http.Request) handler,
) {
  return ArticleExtractionService(
    client: MockClient((req) async => handler(req)),
  );
}

void main() {
  group('ArticleExtractionService.extractFromUrl', () {
    test('turns a fetched page into a single-chapter ParsedBook', () async {
      final service = _serving((_) => http.Response(_articleHtml, 200));

      final result =
          await service.extractFromUrl('https://example.com/my-post');

      expect(result.book.title, 'My Post');
      expect(result.book.author, 'Jane Doe');
      expect(result.book.chapters, hasLength(1));
      expect(result.book.totalWords, result.book.chapters.single.tokens.length);
      expect(result.book.totalWords, greaterThan(10));
      expect(result.sourceUrl, 'https://example.com/my-post');
    });

    test('infers https:// for scheme-less input', () async {
      late Uri requested;
      final service = _serving((req) {
        requested = req.url;
        return http.Response(_articleHtml, 200);
      });

      await service.extractFromUrl('example.com/my-post');

      expect(requested.toString(), 'https://example.com/my-post');
    });

    test('decodes UTF-8 bytes even when the header lies about the charset',
        () async {
      final html = _articleHtml.replaceFirst('paragraph', 'coração emoção');
      final service = _serving(
        (_) => http.Response.bytes(
          utf8.encode(html),
          200,
          headers: {'content-type': 'text/html; charset=iso-8859-1'},
        ),
      );

      final result = await service.extractFromUrl('https://example.com/x');

      final words =
          result.book.chapters.single.tokens.map((t) => t.text).toList();
      expect(words, contains('coração'));
    });

    test('throws on an invalid URL', () {
      final service = _serving((_) => http.Response('', 200));
      expect(
        () => service.extractFromUrl(''),
        throwsA(isA<ArticleExtractionException>()),
      );
    });

    test('throws on non-2xx responses', () {
      final service = _serving((_) => http.Response('gone', 404));
      expect(
        () => service.extractFromUrl('https://example.com/x'),
        throwsA(isA<ArticleExtractionException>()),
      );
    });

    test('wraps network errors in ArticleExtractionException', () {
      final service = _serving((_) => throw http.ClientException('boom'));
      expect(
        () => service.extractFromUrl('https://example.com/x'),
        throwsA(isA<ArticleExtractionException>()),
      );
    });
  });

  group('ArticleExtractionService.extractFromHtml', () {
    final service = ArticleExtractionService(
      client: MockClient((_) async => http.Response('', 500)),
    );

    test('throws when the page has no readable content', () {
      expect(
        () => service.extractFromHtml(
          '<html><body><nav>menu</nav></body></html>',
          url: 'https://example.com/x',
        ),
        throwsA(isA<ArticleExtractionException>()),
      );
    });

    test('falls back to a title derived from the URL slug', () {
      final html = '<html><body><article>'
          '<p>${'long enough readable content ' * 20}</p>'
          '</article></body></html>';

      final result = service.extractFromHtml(
        html,
        url: 'https://example.com/my-article_slug',
      );

      expect(result.book.title, 'my article slug');
    });
  });
}
