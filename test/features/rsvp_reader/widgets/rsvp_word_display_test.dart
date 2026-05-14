import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/features/epub_import/domain/entities/word_token.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/display_settings.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/widgets/rsvp_word_display.dart';

WordToken _token(String text, {int orpIndex = 1}) => WordToken(
      text: text,
      orpIndex: orpIndex,
      timingMultiplier: 1.0,
      globalIndex: 0,
      chapterIndex: 0,
      paragraphIndex: 0,
    );

Future<void> _pump(
  WidgetTester tester, {
  WordToken? word,
  DisplaySettings settings = const DisplaySettings(),
  double progress = 0.0,
  double width = 400,
  double height = 200,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: RsvpWordDisplay(
              word: word,
              settings: settings,
              progress: progress,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('RsvpWordDisplay', () {
    testWidgets('renders nothing when word is null', (tester) async {
      await _pump(tester, word: null);
      // RichText is the rendered word; a SizedBox.shrink puts none in the tree.
      expect(find.byType(RichText), findsNothing);
    });

    testWidgets('renders the word as a RichText', (tester) async {
      await _pump(tester, word: _token('reading'));
      expect(find.byType(RichText), findsWidgets);
      // The three TextSpan children (before/orp/after) concatenate to the
      // full word.
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final span = richText.text as TextSpan;
      final concatenated = (span.children!.cast<TextSpan>())
          .map((c) => c.text ?? '')
          .join();
      expect(concatenated, 'reading');
    });

    testWidgets(
      'ORP letter uses the accent color when showOrpHighlight is on',
      (tester) async {
        await _pump(tester, word: _token('reading', orpIndex: 2));
        final richText = tester.widget<RichText>(find.byType(RichText).first);
        final children =
            (richText.text as TextSpan).children!.cast<TextSpan>();
        // children = [before='re', orp='a', after='ding']
        expect(children[1].text, 'a');
        final orpStyle = children[1].style!;
        final baseStyle = children[0].style!;
        expect(orpStyle.color, isNot(baseStyle.color));
        expect(orpStyle.fontWeight, FontWeight.w700);
        expect(baseStyle.fontWeight, FontWeight.w400);
      },
    );

    testWidgets(
      'ORP letter matches base style when ORP highlight is disabled',
      (tester) async {
        const settings = DisplaySettings(showOrpHighlight: false);
        await _pump(tester, word: _token('reading'), settings: settings);
        final richText = tester.widget<RichText>(find.byType(RichText).first);
        final children =
            (richText.text as TextSpan).children!.cast<TextSpan>();
        expect(children[1].style!.color, children[0].style!.color);
        expect(children[1].style!.fontWeight, FontWeight.w400);
      },
    );

    Finder coloredBoxInside() => find.descendant(
          of: find.byType(RsvpWordDisplay),
          matching: find.byType(ColoredBox),
        );

    testWidgets('focus line is hidden when showFocusLine is false',
        (tester) async {
      const settings = DisplaySettings(showFocusLine: false);
      await _pump(tester, word: _token('reading'), settings: settings);
      expect(coloredBoxInside(), findsNothing);
    });

    testWidgets(
      'focus line draws progress fill when focusLineShowsProgress is on',
      (tester) async {
        const settings = DisplaySettings(
          showFocusLine: true,
          focusLineShowsProgress: true,
        );
        await _pump(
          tester,
          word: _token('reading'),
          settings: settings,
          progress: 0.5,
        );
        // Two ColoredBoxes inside the widget: rest track + filled portion
        // stacked on top.
        expect(coloredBoxInside(), findsNWidgets(2));
      },
    );

    testWidgets(
      'focus line is a single track when progress display is off',
      (tester) async {
        const settings = DisplaySettings(
          showFocusLine: true,
          focusLineShowsProgress: false,
        );
        await _pump(tester, word: _token('reading'), settings: settings);
        expect(coloredBoxInside(), findsOneWidget);
      },
    );

    testWidgets('scales down the font when the word does not fit',
        (tester) async {
      const fontSize = 80.0;
      final word = _token('extraordinarily', orpIndex: 3);
      // The default starting size is 80 here; a 200px-wide slot can't fit
      // a 15-char word at that scale, so the auto-scaler must shrink it.
      const wideSettings = DisplaySettings(fontSize: fontSize);
      await _pump(
        tester,
        word: word,
        settings: wideSettings,
        width: 200,
      );
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final span = (richText.text as TextSpan).children!.cast<TextSpan>().first;
      expect(span.style!.fontSize, lessThan(fontSize));
    });

    testWidgets('horizontal position shifts the word anchor', (tester) async {
      Future<Offset> tapTarget(double horizontalPosition) async {
        await _pump(
          tester,
          word: _token('aligned'),
          settings: DisplaySettings(horizontalPosition: horizontalPosition),
        );
        final box = tester.renderObject<RenderBox>(find.byType(RichText).first);
        return box.localToGlobal(Offset.zero);
      }

      final left = await tapTarget(0.2);
      final right = await tapTarget(0.8);
      // Bigger horizontalPosition moves the word's left edge further right.
      expect(right.dx, greaterThan(left.dx));
    });
  });
}
