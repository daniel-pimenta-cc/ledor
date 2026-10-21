import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/constants/responsive_defaults.dart';
import 'package:ledor/features/epub_import/domain/entities/word_token.dart';
import 'package:ledor/features/rsvp_reader/domain/entities/display_settings.dart';
import 'package:ledor/features/rsvp_reader/presentation/widgets/rsvp_word_display.dart';

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

    Finder focusLine() => find.descendant(
          of: find.byType(RsvpWordDisplay),
          matching: find.byType(LinearProgressIndicator),
        );

    testWidgets('focus line is hidden when showFocusLine is false',
        (tester) async {
      const settings = DisplaySettings(showFocusLine: false);
      await _pump(tester, word: _token('reading'), settings: settings);
      expect(focusLine(), findsNothing);
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
        // Determinate bar filled to the reading progress.
        expect(
          tester.widget<LinearProgressIndicator>(focusLine()).value,
          0.5,
        );
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
        // Value 0 keeps the whole track as a plain focus aid (no fill).
        expect(
          tester.widget<LinearProgressIndicator>(focusLine()).value,
          0.0,
        );
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

    testWidgets('focus line and notch stay put when a long word shrinks',
        (tester) async {
      const settings = DisplaySettings(fontSize: 80.0, showFocusLine: true);
      // Mirrors the reader, which centers the display in a taller area — a
      // per-word box height would re-center and move the indicators.
      Future<(double, double)> indicatorTops(String text) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 400,
                child: Align(
                  child: RsvpWordDisplay(word: _token(text), settings: settings),
                ),
              ),
            ),
          ),
        );
        return (
          tester.getTopLeft(focusLine()).dy,
          tester.getTopLeft(find.byKey(orpIndicatorNotchKey)).dy,
        );
      }

      final short = await indicatorTops('word');
      final long = await indicatorTops('extraordinarily');
      expect(long, short);
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

    group('orp centering', () {
      /// Horizontal center of the rendered ORP letter in display-local
      /// coordinates, measured with an independent layout of the spans the
      /// widget actually rendered.
      double letterCenterLocal(WidgetTester tester) {
        final richText =
            tester.widget<RichText>(find.byType(RichText).first);
        final richBox = tester.renderObject<RenderBox>(
          find.byType(RichText).first,
        );
        final displayBox = tester.renderObject<RenderBox>(
          find.descendant(
            of: find.byType(RsvpWordDisplay),
            matching: find.byType(Stack),
          ),
        );
        final spans =
            (richText.text as TextSpan).children!.cast<TextSpan>();
        final painter = TextPainter(
          text: TextSpan(children: spans),
          textDirection: TextDirection.ltr,
        )..layout();
        final beforeLen = (spans[0].text ?? '').length;
        final orpLen = (spans[1].text ?? '').length;
        final start = painter
            .getOffsetForCaret(TextPosition(offset: beforeLen), Rect.zero)
            .dx;
        final end = painter
            .getOffsetForCaret(
              TextPosition(offset: beforeLen + orpLen),
              Rect.zero,
            )
            .dx;
        final letterGlobalX =
            richBox.localToGlobal(Offset.zero).dx + (start + end) / 2;
        return letterGlobalX - displayBox.localToGlobal(Offset.zero).dx;
      }

      double anchorX(
        WidgetTester tester, {
        required double width,
        required double horizontalPosition,
      }) {
        final context = tester.element(find.byType(RsvpWordDisplay));
        final margin = ResponsiveDefaults.rsvpWordMargin(context);
        return margin + (width - margin * 2) * horizontalPosition;
      }

      testWidgets('short word: highlighted letter lands on the anchor',
          (tester) async {
        // Small explicit font so the word fits with room to spare (no
        // clamp in any font environment) — pure anchor placement.
        await _pump(
          tester,
          word: _token('reading', orpIndex: 2),
          settings: const DisplaySettings(fontSize: 20.0),
        );
        expect(
          letterCenterLocal(tester),
          closeTo(anchorX(tester, width: 400, horizontalPosition: 0.5), 1.0),
        );
      });

      testWidgets('long Russian word stays strictly centered', (tester) async {
        // The reported case: a 21-char Russian word. The display shrinks
        // the font (past the old 16px floor if needed) so that both the
        // highlighted letter and the notch sit exactly on the anchor.
        await _pump(
          tester,
          word: _token('достопримечательность', orpIndex: 7),
        );
        expect(
          letterCenterLocal(tester),
          closeTo(anchorX(tester, width: 400, horizontalPosition: 0.5), 1.0),
        );
        final notchCenter =
            tester.getCenter(find.byKey(orpIndicatorNotchKey)).dx;
        final displayLeft = tester
            .renderObject<RenderBox>(
              find.descendant(
                of: find.byType(RsvpWordDisplay),
                matching: find.byType(Stack),
              ),
            )
            .localToGlobal(Offset.zero)
            .dx;
        expect(
          notchCenter - displayLeft,
          closeTo(anchorX(tester, width: 400, horizontalPosition: 0.5), 1.0),
        );
      });

      testWidgets('long word shrinks the font to hold the anchor',
          (tester) async {
        await _pump(
          tester,
          word: _token('достопримечательность', orpIndex: 7),
        );
        final richText =
            tester.widget<RichText>(find.byType(RichText).first);
        final span =
            (richText.text as TextSpan).children!.cast<TextSpan>().first;
        // Keeps shrinking past the old 16px floor until the ORP letter
        // fits exactly on the anchor.
        expect(span.style!.fontSize!, lessThan(16.0));
        expect(
          letterCenterLocal(tester),
          closeTo(anchorX(tester, width: 400, horizontalPosition: 0.5), 1.0),
        );
      });

      testWidgets('notch follows the highlighted letter on a clamped word',
          (tester) async {
        // Narrow slot + huge font forces the word to shift to fit; the
        // notch must track the letter instead of staying at the anchor.
        await _pump(
          tester,
          word: _token('extraordinarily', orpIndex: 3),
          settings: const DisplaySettings(fontSize: 80.0),
          width: 200,
        );
        final notchCenter =
            tester.getCenter(find.byKey(orpIndicatorNotchKey)).dx;
        final displayLeft = tester
            .renderObject<RenderBox>(
              find.descendant(
                of: find.byType(RsvpWordDisplay),
                matching: find.byType(Stack),
              ),
            )
            .localToGlobal(Offset.zero)
            .dx;
        expect(
          notchCenter - displayLeft,
          closeTo(letterCenterLocal(tester), 1.0),
        );
      });

      testWidgets('lineAbove follows the highlighted letter on a clamped word',
          (tester) async {
        await _pump(
          tester,
          word: _token('extraordinarily', orpIndex: 3),
          settings: const DisplaySettings(
            fontSize: 80.0,
            orpIndicator: OrpIndicatorStyle.lineAbove,
          ),
          width: 200,
        );
        final lineCenter =
            tester.getCenter(find.byKey(orpIndicatorTopLineKey)).dx;
        final displayLeft = tester
            .renderObject<RenderBox>(
              find.descendant(
                of: find.byType(RsvpWordDisplay),
                matching: find.byType(Stack),
              ),
            )
            .localToGlobal(Offset.zero)
            .dx;
        expect(
          lineCenter - displayLeft,
          closeTo(letterCenterLocal(tester), 1.0),
        );
      });
    });

    group('orpIndicator', () {      testWidgets('defaults to notch — triangle present, other marks absent',
          (tester) async {
        await _pump(tester, word: _token('reading'));
        expect(find.byKey(orpIndicatorNotchKey), findsOneWidget);
        expect(find.byKey(orpIndicatorTopLineKey), findsNothing);
        expect(find.byKey(orpIndicatorTopTickKey), findsNothing);
        expect(find.byKey(orpIndicatorBottomTickKey), findsNothing);
      });

      testWidgets('lineAbove draws the top line and hides the notch',
          (tester) async {
        const settings =
            DisplaySettings(orpIndicator: OrpIndicatorStyle.lineAbove);
        await _pump(tester, word: _token('reading'), settings: settings);
        expect(find.byKey(orpIndicatorNotchKey), findsNothing);
        expect(find.byKey(orpIndicatorTopLineKey), findsOneWidget);
        expect(find.byKey(orpIndicatorTopTickKey), findsNothing);
        expect(find.byKey(orpIndicatorBottomTickKey), findsNothing);
      });

      testWidgets('linesAround draws short vertical ticks above and below',
          (tester) async {
        const settings =
            DisplaySettings(orpIndicator: OrpIndicatorStyle.linesAround);
        await _pump(tester, word: _token('reading'), settings: settings);
        expect(find.byKey(orpIndicatorNotchKey), findsNothing);
        expect(find.byKey(orpIndicatorTopLineKey), findsNothing);
        expect(find.byKey(orpIndicatorTopTickKey), findsOneWidget);
        expect(find.byKey(orpIndicatorBottomTickKey), findsOneWidget);
      });

      testWidgets('off hides every indicator', (tester) async {
        const settings =
            DisplaySettings(orpIndicator: OrpIndicatorStyle.off);
        await _pump(tester, word: _token('reading'), settings: settings);
        expect(find.byKey(orpIndicatorNotchKey), findsNothing);
        expect(find.byKey(orpIndicatorTopLineKey), findsNothing);
        expect(find.byKey(orpIndicatorTopTickKey), findsNothing);
        expect(find.byKey(orpIndicatorBottomTickKey), findsNothing);
      });

      testWidgets(
        'linesAround ticks share the same x — vertically aligned on the ORP letter',
        (tester) async {
          const settings =
              DisplaySettings(orpIndicator: OrpIndicatorStyle.linesAround);
          await _pump(tester, word: _token('reading', orpIndex: 2),
              settings: settings);

          final topBox = tester
              .renderObject<RenderBox>(find.byKey(orpIndicatorTopTickKey));
          final bottomBox = tester
              .renderObject<RenderBox>(find.byKey(orpIndicatorBottomTickKey));

          final topPos = topBox.localToGlobal(Offset.zero);
          final bottomPos = bottomBox.localToGlobal(Offset.zero);

          // Top + bottom ticks share the same x, with bottom positioned
          // lower than top.
          expect(topPos.dx, closeTo(bottomPos.dx, 0.5));
          expect(bottomPos.dy, greaterThan(topPos.dy));
        },
      );
    });
  });
}
