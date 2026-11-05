import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/rsvp_reader/presentation/focus_mode_controller.dart';

void main() {
  group('FocusModeController', () {
    test('starts visible and inactive', () {
      final controller = FocusModeController();
      expect(controller.visible, isTrue);
      expect(controller.isActive, isFalse);
      controller.dispose();
    });

    test('hides after the idle delay while active', () {
      FakeAsync().run((async) {
        final controller =
            FocusModeController(hideDelay: const Duration(seconds: 3));
        var notified = false;
        controller.addListener(() => notified = true);

        controller.setActive(true);
        expect(controller.visible, isTrue);

        async.elapse(const Duration(seconds: 2, milliseconds: 999));
        expect(controller.visible, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(controller.visible, isFalse);
        expect(notified, isTrue);
        controller.dispose();
      });
    });

    test('leaving active state cancels the timer and shows chrome', () {
      FakeAsync().run((async) {
        final controller =
            FocusModeController(hideDelay: const Duration(seconds: 3));
        controller.setActive(true);
        async.elapse(const Duration(seconds: 1));
        controller.setActive(false);

        async.elapse(const Duration(seconds: 10));
        expect(controller.visible, isTrue);
        controller.dispose();
      });
    });

    test('interaction while hidden reveals and consumes the next tap', () {
      FakeAsync().run((async) {
        final controller =
            FocusModeController(hideDelay: const Duration(seconds: 3));
        controller.setActive(true);
        async.elapse(const Duration(seconds: 3));
        expect(controller.visible, isFalse);

        controller.onUserInteraction();
        expect(controller.visible, isTrue);
        // Reveal-only: the word-area tap must not toggle playback.
        expect(controller.handleWordTap(), isTrue);
        // ...but only once.
        expect(controller.handleWordTap(), isFalse);
        controller.dispose();
      });
    });

    test('interaction while visible only restarts the timer', () {
      FakeAsync().run((async) {
        final controller =
            FocusModeController(hideDelay: const Duration(seconds: 3));
        controller.setActive(true);
        async.elapse(const Duration(seconds: 2));
        controller.onUserInteraction(); // +2s in, clock restarts

        async.elapse(const Duration(seconds: 2, milliseconds: 999));
        expect(controller.visible, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(controller.visible, isFalse);
        // No reveal happened, so taps toggle normally.
        expect(controller.handleWordTap(), isFalse);
        controller.dispose();
      });
    });

    test('drags and long-presses do not eat the next tap', () {
      FakeAsync().run((async) {
        final controller =
            FocusModeController(hideDelay: const Duration(seconds: 3));
        controller.setActive(true);
        async.elapse(const Duration(seconds: 3));

        controller.onUserInteraction();
        controller.clearPendingTap();
        expect(controller.handleWordTap(), isFalse);
        controller.dispose();
      });
    });

    test('interaction while inactive is ignored', () {
      final controller = FocusModeController();
      controller.onUserInteraction();
      expect(controller.visible, isTrue);
      expect(controller.handleWordTap(), isFalse);
      controller.dispose();
    });
  });
}
