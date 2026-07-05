import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/rsvp_reader/domain/entities/display_settings.dart';
import 'package:ledor/features/rsvp_reader/presentation/widgets/wpm_selector.dart';

void main() {
  group('buildWpmPresets', () {
    test('centres the current value with step-sized chips on each side', () {
      expect(
        buildWpmPresets(300, step: 50, radius: 2),
        [200, 250, 300, 350, 400],
      );
    });

    test('keeps an off-multiple current value in the list', () {
      expect(
        buildWpmPresets(325, step: 50, radius: 1),
        [275, 325, 375],
      );
    });

    test('clamps to min/max instead of emitting out-of-range chips', () {
      expect(
        buildWpmPresets(100, step: 50, radius: 3, min: 50, max: 1000),
        [50, 100, 150, 200, 250], // 0 and -50 dropped
      );
      expect(
        buildWpmPresets(950, step: 50, radius: 3, min: 50, max: 1000),
        [800, 850, 900, 950, 1000], // 1050+ dropped
      );
    });
  });

  group('WpmSelector', () {
    Future<int?> pumpSelector(
      WidgetTester tester, {
      required int wpm,
      required void Function(int) onChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WpmSelector(
              settings: const DisplaySettings(),
              currentWpm: wpm,
              onChanged: onChanged,
              labelFormatter: (v) => '$v wpm',
            ),
          ),
        ),
      );
      return null;
    }

    testWidgets('plus/minus adjust by the fine step (25)', (tester) async {
      final changes = <int>[];
      await pumpSelector(tester, wpm: 300, onChanged: changes.add);

      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));

      expect(changes, [325, 275]);
    });

    testWidgets('does not fire when already at the bound', (tester) async {
      final changes = <int>[];
      await pumpSelector(tester, wpm: 1000, onChanged: changes.add);

      await tester.tap(find.byIcon(Icons.add));

      expect(changes, isEmpty);
    });

    testWidgets('tapping the value opens the preset drawer', (tester) async {
      await pumpSelector(tester, wpm: 300, onChanged: (_) {});
      expect(find.byType(WpmPresetRow), findsNothing);

      await tester.tap(find.text('300 wpm'));
      await tester.pumpAndSettle();

      expect(find.byType(WpmPresetRow), findsOneWidget);
      // Drawer chips step by 50 around the current value.
      expect(find.text('250 wpm'), findsOneWidget);
      expect(find.text('350 wpm'), findsOneWidget);
    });

    testWidgets('selecting a preset fires onChanged and closes the drawer',
        (tester) async {
      final changes = <int>[];
      await pumpSelector(tester, wpm: 300, onChanged: changes.add);

      await tester.tap(find.text('300 wpm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('350 wpm'));
      await tester.pumpAndSettle();

      expect(changes, [350]);
      expect(find.byType(WpmPresetRow), findsNothing);
    });
  });
}
