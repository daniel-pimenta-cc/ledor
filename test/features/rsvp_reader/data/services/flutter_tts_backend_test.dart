import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/rsvp_reader/data/services/flutter_tts_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  late List<MethodCall> log;

  /// When set, the mock handler suspends the named method on this completer
  /// so tests can prove ordering through the backend's serialising queue.
  String? suspendedMethod;
  Completer<void>? gate;

  setUp(() {
    log = [];
    suspendedMethod = null;
    gate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      if (call.method == suspendedMethod) {
        await gate!.future;
      }
      return 1;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> methods(String name) =>
      [for (final c in log) if (c.method == name) c.method];

  group('flutterTtsRate', () {
    test('halves the audiobook scale (plugin treats 0.5 as normal)', () {
      expect(flutterTtsRate(1.0), 0.5);
      expect(flutterTtsRate(2.0), 1.0);
      expect(flutterTtsRate(3.0), 1.5);
      expect(flutterTtsRate(0.5), 0.25);
    });

    test('clamps to the plugin safe band [0.1, 1.5]', () {
      expect(flutterTtsRate(0.1), 0.1);
      expect(flutterTtsRate(4.0), 1.5);
    });
  });

  group('FlutterTtsBackend', () {
    test('setRate sends the converted value to the plugin', () async {
      final backend = FlutterTtsBackend();
      await backend.setRate(1.0);

      final call = log.singleWhere((c) => c.method == 'setSpeechRate');
      expect(call.arguments, 0.5);
    });

    test('setEngine dedups by id and stops the outgoing client first',
        () async {
      final backend = FlutterTtsBackend();
      await backend.setEngine('engine.a');
      await backend.setEngine('engine.a'); // same id — no plugin roundtrip
      await backend.setEngine('engine.b');

      expect(methods('setEngine'), hasLength(2));
      // Each switch is preceded by a stop of the outgoing client, which
      // flutter_tts itself never silences (overlapping audio + ghost
      // completions otherwise).
      final sequence = [
        for (final c in log)
          if (c.method == 'setEngine' || c.method == 'stop') c.method,
      ];
      expect(sequence, ['stop', 'setEngine', 'stop', 'setEngine']);
    });

    test('operations are serialised: a slow call blocks later ones', () async {
      final backend = FlutterTtsBackend();
      // Warm up init outside the measurement window.
      await backend.setPitch(1.0);
      log.clear();

      suspendedMethod = 'setLanguage';
      gate = Completer<void>();

      final first = backend.setLanguage('en-US');
      final second = backend.setRate(2.0);
      // Let microtasks run: without the queue, setSpeechRate would hit the
      // channel while setLanguage is still suspended.
      await Future<void>.delayed(Duration.zero);
      expect(methods('setSpeechRate'), isEmpty);

      gate!.complete();
      await first;
      await second;
      expect(methods('setSpeechRate'), hasLength(1));
    });

    test('setVoice(null) clears back to the engine default voice', () async {
      final backend = FlutterTtsBackend();
      await backend.setVoice(null);

      expect(methods('clearVoice'), hasLength(1));
    });
  });
}
