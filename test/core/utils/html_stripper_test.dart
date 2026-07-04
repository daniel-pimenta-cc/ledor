import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/html_stripper.dart';

void main() {
  group('HtmlStripper', () {
    test('strips simple p tags', () {
      final result = HtmlStripper.strip('<p>Hello world</p>');
      expect(result, 'Hello world');
    });

    test('preserves paragraph breaks between p elements', () {
      final result =
          HtmlStripper.strip('<p>First paragraph.</p><p>Second paragraph.</p>');
      expect(result, contains('First paragraph.'));
      expect(result, contains('Second paragraph.'));
      // Should have paragraph break (double newline) between them
      expect(result.contains('\n\n'), true);
    });

    test('handles HTML entities', () {
      final result = HtmlStripper.strip('<p>Tom &amp; Jerry &lt;3</p>');
      expect(result, contains('Tom & Jerry <3'));
    });

    test('handles nested tags', () {
      final result =
          HtmlStripper.strip('<p>This is <em>italic</em> and <strong>bold</strong></p>');
      expect(result, contains('This is italic and bold'));
    });

    test('handles br tags', () {
      final result = HtmlStripper.strip('Line one<br>Line two');
      expect(result, contains('Line one'));
      expect(result, contains('Line two'));
    });

    test('handles empty HTML', () {
      expect(HtmlStripper.strip(''), '');
      expect(HtmlStripper.strip('   '), '');
    });

    test('handles heading tags with paragraph breaks', () {
      final result =
          HtmlStripper.strip('<h1>Title</h1><p>Content here.</p>');
      expect(result, contains('Title'));
      expect(result, contains('Content here.'));
    });

    test('handles list items', () {
      final result =
          HtmlStripper.strip('<ul><li>Item one</li><li>Item two</li></ul>');
      expect(result, contains('Item one'));
      expect(result, contains('Item two'));
    });

    test('collapses excessive whitespace', () {
      final result =
          HtmlStripper.strip('<p>   Multiple    spaces   here   </p>');
      expect(result, 'Multiple spaces here');
    });

    test('handles real EPUB XHTML content', () {
      const xhtml = '''
        <div class="chapter">
          <h2>Chapter 1</h2>
          <p>It was a dark and stormy night.</p>
          <p>"Who goes there?" asked the guard.</p>
        </div>
      ''';
      final result = HtmlStripper.strip(xhtml);
      expect(result, contains('Chapter 1'));
      expect(result, contains('It was a dark and stormy night.'));
      expect(result, contains('"Who goes there?" asked the guard.'));
    });

    test('skips <style> blocks entirely', () {
      const xhtml = '''
        <p>Before.</p>
        <style>
          .drop-cap { font-size: 2em; font-weight: bold; }
          h2 { text-transform: uppercase; }
        </style>
        <p>After.</p>
      ''';
      final result = HtmlStripper.strip(xhtml);
      expect(result, contains('Before.'));
      expect(result, contains('After.'));
      expect(result, isNot(contains('drop-cap')));
      expect(result, isNot(contains('font-size')));
      expect(result, isNot(contains('text-transform')));
      expect(result, isNot(contains('{')));
      expect(result, isNot(contains('}')));
    });

    test('skips <script> blocks entirely', () {
      const xhtml = '''
        <p>Hello.</p>
        <script>var x = 1; alert("hi");</script>
        <p>World.</p>
      ''';
      final result = HtmlStripper.strip(xhtml);
      expect(result, contains('Hello.'));
      expect(result, contains('World.'));
      expect(result, isNot(contains('alert')));
      expect(result, isNot(contains('var')));
    });

    test('skips multiple style blocks around image figures', () {
      const xhtml = '''
        <p>Chapter intro.</p>
        <figure>
          <style>.fig { width: 100%; }</style>
          <img src="cover.jpg" alt="cover"/>
          <figcaption>Figure 1</figcaption>
        </figure>
        <style>.body { line-height: 1.5; }</style>
        <p>Continuing the story.</p>
      ''';
      final result = HtmlStripper.strip(xhtml);
      expect(result, contains('Chapter intro.'));
      expect(result, contains('Figure 1'));
      expect(result, contains('Continuing the story.'));
      expect(result, isNot(contains('width')));
      expect(result, isNot(contains('line-height')));
      expect(result, isNot(contains('100%')));
    });

    test('skips <svg> contents', () {
      const xhtml = '''
        <p>Before svg.</p>
        <svg><text>SVG TEXT</text></svg>
        <p>After svg.</p>
      ''';
      final result = HtmlStripper.strip(xhtml);
      expect(result, contains('Before svg.'));
      expect(result, contains('After svg.'));
      expect(result, isNot(contains('SVG TEXT')));
    });
  });
}
