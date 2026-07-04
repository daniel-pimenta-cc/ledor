import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/readability_extractor.dart';

void main() {
  group('ReadabilityExtractor', () {
    test('picks the <article> element when present', () {
      const html = '''
<html>
  <head><title>My Post</title></head>
  <body>
    <nav><a href="/home">Home</a></nav>
    <article>
      <h1>My Post</h1>
      <p>This is the first real paragraph of the article and it has enough text to count as substantial content for scoring purposes.</p>
      <p>Another paragraph, with a comma, also substantial enough to matter.</p>
    </article>
    <footer>footer noise</footer>
  </body>
</html>
''';
      final result = ReadabilityExtractor.extract(html);
      expect(result.title, 'My Post');
      expect(result.contentHtml, contains('first real paragraph'));
      expect(result.contentHtml, isNot(contains('footer noise')));
      expect(result.contentHtml, isNot(contains('Home')));
    });

    test('prefers og:title over <title> and h1', () {
      final html = '''
<html>
  <head>
    <title>Plain title</title>
    <meta property="og:title" content="OG title wins">
  </head>
  <body><article><h1>H1 title</h1><p>${'lorem ipsum ' * 30}</p></article></body>
</html>
''';
      final result = ReadabilityExtractor.extract(html);
      expect(result.title, 'OG title wins');
    });

    test('extracts byline from meta author', () {
      final html = '''
<html>
  <head>
    <title>x</title>
    <meta name="author" content="Jane Doe">
  </head>
  <body><article><p>${'content ' * 30}</p></article></body>
</html>
''';
      final result = ReadabilityExtractor.extract(html);
      expect(result.byline, 'Jane Doe');
    });

    test('extracts og:site_name', () {
      final html = '''
<html>
  <head>
    <title>x</title>
    <meta property="og:site_name" content="Example News">
  </head>
  <body><article><p>${'content ' * 30}</p></article></body>
</html>
''';
      final result = ReadabilityExtractor.extract(html);
      expect(result.siteName, 'Example News');
    });

    test('scores content div over sidebar when no <article>', () {
      const html = '''
<html>
  <head><title>Post</title></head>
  <body>
    <div class="sidebar"><p>Short blurb.</p></div>
    <div class="post-content">
      <p>This is a genuine article paragraph with enough substance and commas, yes commas, to score well.</p>
      <p>Another paragraph with real content that should win the scoring against a short sidebar blurb.</p>
      <p>Third paragraph just to push the score higher, with some commas, here and there.</p>
    </div>
  </body>
</html>
''';
      final result = ReadabilityExtractor.extract(html);
      expect(result.contentHtml, contains('genuine article paragraph'));
      expect(result.contentHtml, isNot(contains('Short blurb')));
    });

    test('strips script and style tags', () {
      const html = '''
<html>
  <head><title>x</title></head>
  <body>
    <article>
      <script>alert('xss')</script>
      <style>.foo { color: red }</style>
      <p>The actual article content goes here with enough length to be scored as meaningful.</p>
    </article>
  </body>
</html>
''';
      final result = ReadabilityExtractor.extract(html);
      expect(result.contentHtml, contains('actual article content'));
      expect(result.contentHtml, isNot(contains('alert')));
      expect(result.contentHtml, isNot(contains('color: red')));
    });

    test('falls back to body when no strong candidate exists', () {
      const html =
          '<html><body><p>Just a single paragraph with no containers.</p></body></html>';
      final result = ReadabilityExtractor.extract(html);
      expect(result.contentHtml, contains('single paragraph'));
    });

    test('negative patterns on classes penalize comment sections', () {
      const html = '''
<html>
  <head><title>x</title></head>
  <body>
    <div class="comments">
      <p>User comment one, with commas, here and there, just chatting.</p>
      <p>Another user comment with enough words to look substantial on its own.</p>
      <p>A third comment to make the block heavy enough to compete with real content.</p>
    </div>
    <div class="entry-content">
      <p>This is the real article body with commas, sentences, and enough words to be chosen.</p>
      <p>A second paragraph of real content that should push this div's score above the comments.</p>
    </div>
  </body>
</html>
''';
      final result = ReadabilityExtractor.extract(html);
      expect(result.contentHtml, contains('real article body'));
      expect(result.contentHtml, isNot(contains('User comment one')));
    });
  });
}
