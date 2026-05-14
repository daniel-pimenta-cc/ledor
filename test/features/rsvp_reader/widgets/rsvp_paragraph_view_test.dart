import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/features/epub_import/domain/entities/word_token.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/display_settings.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/widgets/rsvp_paragraph_view.dart';

WordToken _token(String text, int globalIndex) => WordToken(
      text: text,
      orpIndex: 1,
      timingMultiplier: 1.0,
      globalIndex: globalIndex,
      chapterIndex: 0,
      paragraphIndex: 0,
    );

List<WordToken> _sample() => [
      _token('the', 0),
      _token('quick', 1),
      _token('brown', 2),
      _token('fox', 3),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required List<WordToken> tokens,
  required int currentGlobalIndex,
  ValueChanged<WordToken>? onWordTap,
  DisplaySettings settings = const DisplaySettings(),
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: RsvpParagraphView(
              tokens: tokens,
              currentGlobalIndex: currentGlobalIndex,
              settings: settings,
              onWordTap: onWordTap,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The highlighted-word container has a unique combination of properties
/// (BoxDecoration + boxShadow). We pick that combination as the signal
/// rather than reaching into private widget types.
bool _isHighlightPill(Widget w) {
  if (w is! Container) return false;
  final d = w.decoration;
  if (d is! BoxDecoration) return false;
  return d.boxShadow != null && d.boxShadow!.isNotEmpty;
}

/// Walks the [span] tree and collects every leaf [TextSpan] (the ones with
/// actual text). `Text.rich` may wrap the user-supplied span in a parent
/// [TextSpan] to apply [DefaultTextStyle], so reaching the rendered
/// children needs a recursive descent.
List<TextSpan> _collectLeafTextSpans(InlineSpan span) {
  final out = <TextSpan>[];
  span.visitChildren((child) {
    if (child is TextSpan && child.text != null) {
      out.add(child);
    }
    return true;
  });
  return out;
}

/// Finds the [RichText] that belongs to the paragraph under test. The
/// inner [Text] children inside the highlight pill also render as
/// [RichText]s, so a global `find.byType(RichText)` is ambiguous.
RichText _findParagraphRichText(WidgetTester tester) {
  final candidates = tester.widgetList<RichText>(
    find.descendant(
      of: find.byType(RsvpParagraphView),
      matching: find.byType(RichText),
    ),
  );
  // The outermost RichText is the one with the most direct children — the
  // pill's Text widgets each render a RichText with a single leaf.
  RichText? best;
  int bestChildren = -1;
  for (final r in candidates) {
    final children = (r.text is TextSpan)
        ? ((r.text as TextSpan).children?.length ?? 0)
        : 0;
    if (children > bestChildren) {
      bestChildren = children;
      best = r;
    }
  }
  return best!;
}

void main() {
  group('RsvpParagraphView', () {
    testWidgets('renders all tokens in order in the rich text', (tester) async {
      await _pump(tester, tokens: _sample(), currentGlobalIndex: -1);

      final richText = _findParagraphRichText(tester);
      final root = richText.text as TextSpan;
      final concatenated = root.toPlainText();
      // Words are space-joined; the final word has no trailing space.
      expect(concatenated.trim(), 'the quick brown fox');
    });

    testWidgets('wraps the current word in a highlight pill', (tester) async {
      await _pump(tester, tokens: _sample(), currentGlobalIndex: 2);

      final pill = find.byWidgetPredicate(_isHighlightPill);
      expect(pill, findsOneWidget);
      // The pill wraps a Text with the matching token text.
      final pillText = find.descendant(of: pill, matching: find.text('brown'));
      expect(pillText, findsOneWidget);
    });

    testWidgets('renders no pill when currentGlobalIndex is outside the set',
        (tester) async {
      await _pump(tester, tokens: _sample(), currentGlobalIndex: -1);

      expect(find.byWidgetPredicate(_isHighlightPill), findsNothing);
    });

    testWidgets(
      'attaches the provided highlightKey to the current pill',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RsvpParagraphView(
                tokens: _sample(),
                currentGlobalIndex: 1,
                settings: const DisplaySettings(),
                onWordTap: null,
                highlightKey: key,
              ),
            ),
          ),
        );
        // currentContext is non-null exactly when the keyed widget is
        // mounted — proving the pill is rendered with our key.
        expect(key.currentContext, isNotNull);
      },
    );

    testWidgets('tap on the highlight pill invokes onWordTap',
        (tester) async {
      WordToken? tapped;
      await _pump(
        tester,
        tokens: _sample(),
        currentGlobalIndex: 1,
        onWordTap: (t) => tapped = t,
      );
      await tester.tap(find.byWidgetPredicate(_isHighlightPill));
      await tester.pump();
      expect(tapped, isNotNull);
      expect(tapped!.text, 'quick');
    });

    testWidgets(
      'tap on the highlight pill is a no-op when onWordTap is null '
      '(ereader mode)',
      (tester) async {
        await _pump(
          tester,
          tokens: _sample(),
          currentGlobalIndex: 1,
          onWordTap: null,
        );
        // No callback wired → tap should not throw and not advance any
        // state. We just exercise the path to ensure it doesn't crash.
        await tester.tap(find.byWidgetPredicate(_isHighlightPill));
        await tester.pump();
      },
    );

    testWidgets(
      'plain (non-highlighted) words carry a tap recognizer when onWordTap '
      'is provided',
      (tester) async {
        await _pump(
          tester,
          tokens: _sample(),
          currentGlobalIndex: 2,
          onWordTap: (_) {},
        );
        final richText = _findParagraphRichText(tester);
        final plainSpans = _collectLeafTextSpans(richText.text);
        expect(plainSpans, isNotEmpty);
        for (final s in plainSpans) {
          expect(s.recognizer, isA<TapGestureRecognizer>());
        }
      },
    );

    testWidgets(
      'plain words have no recognizer when onWordTap is null (ereader mode)',
      (tester) async {
        await _pump(
          tester,
          tokens: _sample(),
          currentGlobalIndex: -1,
          onWordTap: null,
        );
        final richText = _findParagraphRichText(tester);
        for (final s in _collectLeafTextSpans(richText.text)) {
          expect(s.recognizer, isNull);
        }
      },
    );

    testWidgets(
      'hyphenated sub-tokens (text ending with -) join the next word '
      'without a trailing space',
      (tester) async {
        final tokens = [
          _token('guarda-', 0),
          _token('chuva', 1),
        ];
        await _pump(tester, tokens: tokens, currentGlobalIndex: -1);
        final richText = _findParagraphRichText(tester);
        // Plaintext should keep the dash flush against the next word.
        expect(richText.text.toPlainText(), startsWith('guarda-chuva'));
      },
    );
  });
}
