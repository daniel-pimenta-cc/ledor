import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/features/epub_import/domain/entities/chapter.dart';
import 'package:rsvp_reader/features/epub_import/domain/entities/word_token.dart';
import 'package:rsvp_reader/features/rsvp_reader/data/services/tts_backend.dart';
import 'package:rsvp_reader/features/rsvp_reader/data/services/tts_player.dart';

WordToken _token(String text, int globalIdx) => WordToken(
      text: text,
      orpIndex: 0,
      timingMultiplier: 1.0,
      globalIndex: globalIdx,
      chapterIndex: 0,
      paragraphIndex: 0,
    );

Chapter _chapter(String title, List<String> words, int startGlobal) =>
    Chapter(
      title: title,
      tokens: [
        for (var i = 0; i < words.length; i++)
          _token(words[i], startGlobal + i),
      ],
    );

class _RecorderBackend implements TtsBackend {
  bool canPipelineValue;
  final List<String> speakTexts = [];
  final List<TtsQueueMode> speakModes = [];
  int setRateCount = 0;
  int setLanguageCount = 0;
  bool stopCalled = false;

  TtsProgressHandler? _onProgress;
  VoidCallback? _onCompletion;

  _RecorderBackend({this.canPipelineValue = true});

  @override
  bool get canPipeline => canPipelineValue;

  void emitProgress(int offset, int end, String word) =>
      _onProgress?.call(offset, end, word);
  void emitCompletion() => _onCompletion?.call();

  @override
  Future<void> init() async {}

  @override
  Future<List<TtsVoice>> getVoices() async => const [];

  @override
  Future<List<String>> getLanguages() async => const [];

  @override
  Future<List<TtsEngine>> getEngines() async => const [];

  @override
  Future<void> setEngine(String id) async {}

  @override
  Future<void> setVoice(TtsVoice? v) async {}

  @override
  Future<void> setLanguage(String iso) async {
    setLanguageCount++;
  }

  @override
  Future<void> setRate(double r) async {
    setRateCount++;
  }

  @override
  Future<void> setPitch(double p) async {}

  @override
  Future<void> speak(
    String text, {
    TtsQueueMode mode = TtsQueueMode.flush,
  }) async {
    speakTexts.add(text);
    speakModes.add(mode);
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> dispose() async {}

  @override
  set onProgress(TtsProgressHandler? cb) => _onProgress = cb;
  @override
  set onCompletion(VoidCallback? cb) => _onCompletion = cb;
  // These tests never emit errors or "start" events; we accept the
  // setters to satisfy the TtsBackend contract.
  @override
  set onError(void Function(String)? cb) {}
  @override
  set onStart(VoidCallback? cb) {}
}

Future<void> _pump([int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.value();
  }
}

void main() {
  group('TtsPlayer lookahead respects backend.canPipeline', () {
    test('canPipeline=true → enqueues 2 segments (flush + add)', () async {
      final backend = _RecorderBackend(canPipelineValue: true);
      final player = TtsPlayer(backend);
      await player.init();
      player.setContent(
        [
          _chapter('one', ['alpha'], 0),
          _chapter('two', ['beta'], 1),
        ],
        2,
      );

      await player.play(fromGlobalIndex: 0);
      await _pump();

      expect(backend.speakTexts, hasLength(2));
      expect(backend.speakModes, [TtsQueueMode.flush, TtsQueueMode.add]);
    });

    test('canPipeline=false → enqueues only 1 segment (flush)', () async {
      final backend = _RecorderBackend(canPipelineValue: false);
      final player = TtsPlayer(backend);
      await player.init();
      player.setContent(
        [
          _chapter('one', ['alpha'], 0),
          _chapter('two', ['beta'], 1),
        ],
        2,
      );

      await player.play(fromGlobalIndex: 0);
      await _pump();

      // Sequential backends would have the new speak() cancel the
      // previous one — the player must not pre-queue.
      expect(backend.speakTexts, hasLength(1));
      expect(backend.speakModes, [TtsQueueMode.flush]);
    });
  });

  group('TtsPlayer settings dedup', () {
    test('setRate with same value does not double-call backend', () async {
      final backend = _RecorderBackend();
      final player = TtsPlayer(backend);
      await player.init();
      // Push initial settings — sets rate once.
      player.setSettings(const TtsPlayerSettings(rate: 1.0));
      await player.applySettings();
      final after1 = backend.setRateCount;

      // Same rate again — no extra backend call.
      await player.setRate(1.0);
      expect(backend.setRateCount, after1);

      // Different rate — exactly one extra call.
      await player.setRate(1.5);
      expect(backend.setRateCount, after1 + 1);
    });

    test('applySettings does not re-push fields that already match', () async {
      final backend = _RecorderBackend();
      final player = TtsPlayer(backend);
      await player.init();

      player.setSettings(const TtsPlayerSettings(language: 'en-US'));
      await player.applySettings();
      final lang1 = backend.setLanguageCount;

      // Same snapshot a second time — backend shouldn't see another
      // setLanguage call.
      player.setSettings(const TtsPlayerSettings(language: 'en-US'));
      await player.applySettings();
      expect(backend.setLanguageCount, lang1);

      // Genuine change → one call.
      player.setSettings(const TtsPlayerSettings(language: 'pt-BR'));
      await player.applySettings();
      expect(backend.setLanguageCount, lang1 + 1);
    });
  });

  group('TtsPlayer end-of-book handling', () {
    test('onBookFinished fires on completion of the last segment', () async {
      final backend = _RecorderBackend();
      final player = TtsPlayer(backend);
      bool finished = false;
      player.onBookFinished = () => finished = true;
      await player.init();
      player.setContent([_chapter('only', ['alpha'], 0)], 1);

      await player.play(fromGlobalIndex: 0);
      await _pump();
      backend.emitCompletion();
      await _pump();

      expect(finished, isTrue);
      expect(player.isPlaying, isFalse);
    });
  });

  group('TtsPlayer pause clears heartbeat', () {
    test('pause resets _lastProgressAt so a stale heartbeat does not trigger',
        () async {
      // We can't directly observe _lastProgressAt; instead we verify the
      // invariant via restartIfStalled: after pause + play, a stall has
      // not occurred yet, so restartIfStalled is a no-op.
      final backend = _RecorderBackend();
      final player = TtsPlayer(backend);
      await player.init();
      player.setContent(
        [_chapter('only', ['alpha', 'beta'], 0)],
        2,
      );

      await player.play(fromGlobalIndex: 0);
      await _pump();
      backend.emitProgress(0, 5, 'alpha'); // heartbeat at "now"
      await _pump();

      await player.pause();
      await player.play(fromGlobalIndex: 0);
      await _pump();
      final speaksBeforeStallCheck = backend.speakTexts.length;

      await player.restartIfStalled();
      // No restart issued: the heartbeat was nulled by pause(), and play()
      // hasn't yet received a progress callback (none was emitted), but
      // the queue isn't empty either. The function should bail without
      // issuing additional speaks.
      expect(backend.speakTexts.length, speaksBeforeStallCheck);
    });
  });
}
