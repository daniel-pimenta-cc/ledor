import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/url_utils.dart';

void main() {
  group('UrlUtils.extractHttpUrl', () {
    test('returns a bare URL unchanged', () {
      expect(
        UrlUtils.extractHttpUrl('https://example.com/post'),
        'https://example.com/post',
      );
    });

    test('picks the URL out of browser share text (title + newline + URL)', () {
      expect(
        UrlUtils.extractHttpUrl('Great Article\nhttps://example.com/a?b=1'),
        'https://example.com/a?b=1',
      );
    });

    test('accepts http:// as well as https://', () {
      expect(
        UrlUtils.extractHttpUrl('see http://old.site/page here'),
        'http://old.site/page',
      );
    });

    test('returns the first URL when several are present', () {
      expect(
        UrlUtils.extractHttpUrl('https://first.com https://second.com'),
        'https://first.com',
      );
    });

    test('returns null when no URL token exists', () {
      expect(UrlUtils.extractHttpUrl('just some plain text'), isNull);
      // Scheme must lead the token — mid-token URLs are not extracted.
      expect(UrlUtils.extractHttpUrl('foohttps://example.com'), isNull);
    });

    test('returns null for empty or whitespace-only input', () {
      expect(UrlUtils.extractHttpUrl(''), isNull);
      expect(UrlUtils.extractHttpUrl('   \n\t'), isNull);
    });
  });

  group('UrlUtils.parseWithHttpsFallback', () {
    test('keeps an explicit scheme', () {
      expect(
        UrlUtils.parseWithHttpsFallback('http://example.com/a').toString(),
        'http://example.com/a',
      );
      expect(
        UrlUtils.parseWithHttpsFallback('https://example.com/a').toString(),
        'https://example.com/a',
      );
    });

    test('prefixes https:// when the scheme is missing', () {
      expect(
        UrlUtils.parseWithHttpsFallback('example.com/post?q=1').toString(),
        'https://example.com/post?q=1',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        UrlUtils.parseWithHttpsFallback('  example.com  ').toString(),
        'https://example.com',
      );
    });

    test('returns null for empty input', () {
      expect(UrlUtils.parseWithHttpsFallback(''), isNull);
      expect(UrlUtils.parseWithHttpsFallback('   '), isNull);
    });

    test('returns null when no host can be parsed', () {
      expect(UrlUtils.parseWithHttpsFallback('https://'), isNull);
    });
  });
}
