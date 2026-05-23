import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rsvp_reader/core/constants/app_constants.dart';
import 'package:rsvp_reader/core/di/providers.dart';
import 'package:rsvp_reader/database/app_database.dart';
import 'package:rsvp_reader/database/daos/books_dao.dart';
import 'package:rsvp_reader/database/daos/cached_tokens_dao.dart';
import 'package:rsvp_reader/database/daos/reading_progress_dao.dart';
import 'package:rsvp_reader/database/daos/reading_session_dao.dart';
import 'package:rsvp_reader/features/epub_import/domain/entities/word_token.dart';
import 'package:rsvp_reader/features/library_sync/presentation/providers/library_sync_provider.dart';
import 'package:rsvp_reader/features/rsvp_reader/data/services/tts_backend.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/display_settings.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/rsvp_state.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/providers/tts_backend_provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MockCachedTokensDao extends Mock implements CachedTokensDao {}

class _MockReadingProgressDao extends Mock implements ReadingProgressDao {}

class _MockReadingSessionDao extends Mock implements ReadingSessionDao {}

class _MockBooksDao extends Mock implements BooksDao {}

/// Stub that no-ops every call into the Drive sync pipeline. The real
/// notifier reads syncConfigProvider on each schedulePush, and that
/// provider's auto-load races the test scaffold's "no pending async"
/// assertion. We swap it out so the engine's _saveProgress can call
/// schedulePush without dragging the sync stack along.
class _StubLibrarySyncNotifier extends LibrarySyncNotifier {
  _StubLibrarySyncNotifier(super.ref);

  @override
  void schedulePush() {}

  @override
  void markSettingsDirty() {}

  @override
  Future<void> triggerSync() async {}
}

/// Minimal TickerProvider for the engine. We never pump frames in these
/// tests; we just need play() to find a non-null vsync and stop short of
/// erroring. The Ticker is created but never sees a real frame callback,
/// so [_onTick] never fires and the state we observe is whatever the
/// public methods set directly.
class _FakeTickerProvider implements TickerProvider {
  Ticker? lastCreated;

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = Ticker(onTick);
    lastCreated = ticker;
    return ticker;
  }
}

WordToken _token({
  required String text,
  required int globalIndex,
  required int chapterIndex,
  int paragraphIndex = 0,
  bool isChapterStart = false,
  bool isParagraphStart = false,
}) =>
    WordToken(
      text: text,
      orpIndex: 1,
      timingMultiplier: 1.0,
      globalIndex: globalIndex,
      chapterIndex: chapterIndex,
      paragraphIndex: paragraphIndex,
      isChapterStart: isChapterStart,
      isParagraphStart: isParagraphStart,
    );

WordToken _imageToken({
  required int globalIndex,
  required int chapterIndex,
  int paragraphIndex = 0,
  String relativePath = 'book_images/test/0.png',
}) =>
    WordToken(
      text: '',
      orpIndex: 0,
      timingMultiplier: 1.0,
      globalIndex: globalIndex,
      chapterIndex: chapterIndex,
      paragraphIndex: paragraphIndex,
      isImage: true,
      imageRelativePath: relativePath,
    );

/// Builds a single chapter where the second token is an inline image,
/// followed by two more text tokens. Used to exercise the engine's
/// image-aware controls without spinning up the full import pipeline.
List<CachedTokensTableData> _chapterWithImageRows() {
  final tokens = [
    _token(text: 'before', globalIndex: 0, chapterIndex: 0, isChapterStart: true),
    _imageToken(globalIndex: 1, chapterIndex: 0, paragraphIndex: 1),
    _token(text: 'after', globalIndex: 2, chapterIndex: 0, paragraphIndex: 2),
    _token(text: 'end', globalIndex: 3, chapterIndex: 0, paragraphIndex: 2),
  ];
  return [
    CachedTokensTableData(
      id: 1,
      bookId: 'book-1',
      chapterIndex: 0,
      chapterTitle: 'Chapter 0',
      tokensJson: jsonEncode([for (final t in tokens) t.toJson()]),
      wordCount: tokens.length,
      paragraphCount: 3,
    ),
  ];
}

/// Builds two chapters with 3 words each — small enough to be cheap, large
/// enough to exercise the chapter boundary advance path.
List<CachedTokensTableData> _twoChapterRows() {
  final ch0 = [
    _token(text: 'alpha', globalIndex: 0, chapterIndex: 0, isChapterStart: true),
    _token(text: 'beta', globalIndex: 1, chapterIndex: 0),
    _token(text: 'gamma', globalIndex: 2, chapterIndex: 0),
  ];
  final ch1 = [
    _token(text: 'delta', globalIndex: 3, chapterIndex: 1, isChapterStart: true),
    _token(text: 'epsilon', globalIndex: 4, chapterIndex: 1),
    _token(text: 'zeta', globalIndex: 5, chapterIndex: 1),
  ];
  return [
    CachedTokensTableData(
      id: 1,
      bookId: 'book-1',
      chapterIndex: 0,
      chapterTitle: 'Chapter 0',
      tokensJson: jsonEncode([for (final t in ch0) t.toJson()]),
      wordCount: ch0.length,
      paragraphCount: 1,
    ),
    CachedTokensTableData(
      id: 2,
      bookId: 'book-1',
      chapterIndex: 1,
      chapterTitle: 'Chapter 1',
      tokensJson: jsonEncode([for (final t in ch1) t.toJson()]),
      wordCount: ch1.length,
      paragraphCount: 1,
    ),
  ];
}

typedef _Mocks = ({
  _MockCachedTokensDao tokens,
  _MockReadingProgressDao progress,
  _MockReadingSessionDao sessions,
  _MockBooksDao books,
});

_Mocks _wireMocks({
  required List<CachedTokensTableData> chapterRows,
  ReadingProgressTableData? savedProgress,
}) {
  final tokens = _MockCachedTokensDao();
  final progress = _MockReadingProgressDao();
  final sessions = _MockReadingSessionDao();
  final books = _MockBooksDao();

  when(() => tokens.getTokensForBook(any())).thenAnswer((_) async => chapterRows);
  when(() => progress.getProgressForBook(any()))
      .thenAnswer((_) async => savedProgress);
  when(() => progress.upsertProgress(any())).thenAnswer((_) async {});
  when(() => sessions.insertSession(any())).thenAnswer((_) async {});
  when(() => books.updateLastReadAt(any())).thenAnswer((_) async {});
  // Engine reads the book row for the audio-handler media item; tests
  // don't exercise that surface so a null row is fine.
  when(() => books.getBookById(any())).thenAnswer((_) async => null);

  return (tokens: tokens, progress: progress, sessions: sessions, books: books);
}

/// Builds a container with all the DAO providers mocked out and registers
/// a tearDown that lets the engine's debounced [_saveProgress] timer fire
/// before the container disposes — otherwise [RsvpEngineNotifier.dispose]
/// races a half-disposed container and crashes on the final DAO read.
///
/// tearDown callbacks run LIFO, so the wait registered here runs before
/// the container.dispose() that any caller registers afterwards.
ProviderContainer _container(_Mocks mocks) {
  final container = ProviderContainer(
    overrides: [
      cachedTokensDaoProvider.overrideWithValue(mocks.tokens),
      readingProgressDaoProvider.overrideWithValue(mocks.progress),
      readingSessionDaoProvider.overrideWithValue(mocks.sessions),
      booksDaoProvider.overrideWithValue(mocks.books),
      librarySyncProvider
          .overrideWith((ref) => _StubLibrarySyncNotifier(ref)),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
  });
  return container;
}

/// Boots an engine and waits for [_loadBook] to settle. Keeps a listen
/// subscription alive so the autoDispose provider doesn't get garbage
/// collected between assertions in the same test.
///
/// The engine relies on [compute] to decode chapters in a background
/// isolate; awaiting attachVsync gives that future a chance to resolve.
Future<RsvpEngineNotifier> _bootEngine(
  ProviderContainer container,
  _FakeTickerProvider vsync, {
  String bookId = 'book-1',
}) async {
  // listen() holds a strong reference that prevents autoDispose from firing.
  container.listen(rsvpEngineProvider(bookId), (_, _) {});
  final engine = container.read(rsvpEngineProvider(bookId).notifier);
  await engine.attachVsync(vsync);
  // One extra microtask flush for any pending state copies after compute.
  await Future<void>.value();
  return engine;
}

void main() {
  // ProviderContainer drives this; flutter_test binding is needed because
  // compute() uses platform plumbing.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // SharedPreferencesAsync is invoked indirectly via the displaySettings
    // provider in _loadBook. Without an in-memory backing the test fails
    // with MissingPluginException.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    registerFallbackValue(const ReadingProgressTableCompanion());
    registerFallbackValue(ReadingSessionTableCompanion.insert(
      id: '',
      bookId: '',
      startedAt: DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.fromMillisecondsSinceEpoch(0),
      durationMs: 0,
      wordsRead: 0,
      startWordIndex: 0,
      endWordIndex: 0,
      avgWpm: 0,
    ));
  });

  group('computeEffectiveWpm', () {
    test('returns target when ramp-up is disabled', () {
      expect(
        computeEffectiveWpm(
            targetWpm: 400, wordsInSession: 0, rampUpEnabled: false),
        400.0,
      );
      expect(
        computeEffectiveWpm(
            targetWpm: 400, wordsInSession: 5, rampUpEnabled: false),
        400.0,
      );
    });

    test('starts at rampUpStartFraction × target on word 0', () {
      final w = computeEffectiveWpm(
          targetWpm: 400, wordsInSession: 0, rampUpEnabled: true);
      expect(w, 400.0 * AppConstants.rampUpStartFraction);
    });

    test('reaches the full target after rampUpWords words', () {
      final w = computeEffectiveWpm(
        targetWpm: 400,
        wordsInSession: AppConstants.rampUpWords,
        rampUpEnabled: true,
      );
      expect(w, 400.0);
    });

    test('clamps anything past rampUpWords back to target', () {
      final w = computeEffectiveWpm(
        targetWpm: 400,
        wordsInSession: AppConstants.rampUpWords + 50,
        rampUpEnabled: true,
      );
      expect(w, 400.0);
    });

    test('follows an ease-out cubic curve across the ramp window', () {
      const targetWpm = 400;
      const target = 400.0;
      final start = target * AppConstants.rampUpStartFraction;
      final delta = target - start;

      // Ease-out cubic spends most of the ramp near the target — at the
      // halfway point the effective WPM is at 1 - (1 - 0.5)^3 = 0.875 of
      // the way from start to target, well past the linear midpoint.
      final mid = computeEffectiveWpm(
        targetWpm: targetWpm,
        wordsInSession: AppConstants.rampUpWords ~/ 2,
        rampUpEnabled: true,
      );
      expect(mid, closeTo(start + delta * 0.875, 0.01));
      expect(mid, greaterThan((start + target) / 2));

      // Three-quarters of the way through the ramp we're nearly at target
      // (1 - 0.25^3 = 0.984375). The curve glides into the final WPM
      // instead of slamming into it on the last word.
      final lateQuarter = computeEffectiveWpm(
        targetWpm: targetWpm,
        wordsInSession: (AppConstants.rampUpWords * 3) ~/ 4,
        rampUpEnabled: true,
      );
      expect(lateQuarter, closeTo(start + delta * 0.984375, 0.5));
    });

    test('is monotonically non-decreasing as wordsInSession grows', () {
      double previous = double.negativeInfinity;
      for (var i = 0; i <= AppConstants.rampUpWords; i++) {
        final current = computeEffectiveWpm(
          targetWpm: 500,
          wordsInSession: i,
          rampUpEnabled: true,
        );
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }
    });
  });

  group('computeWordIntervalMultiplier', () {
    WordToken word(
      String text, {
      double timing = 1.0,
      bool isChapterStart = false,
    }) =>
        WordToken(
          text: text,
          orpIndex: 0,
          timingMultiplier: timing,
          globalIndex: 0,
          chapterIndex: 0,
          paragraphIndex: 0,
          isChapterStart: isChapterStart,
        );

    test('returns the baked-in timingMultiplier when defaults are unchanged',
        () {
      final m = computeWordIntervalMultiplier(
        currentWord: word('hello', timing: 1.4),
        nextWord: word('world'),
        settings: const DisplaySettings(),
      );
      expect(m, closeTo(1.4, 1e-9));
    });

    test('returns 1.0 when smartTiming is off and no pauses are configured',
        () {
      final m = computeWordIntervalMultiplier(
        currentWord: word('hello', timing: 2.5),
        nextWord: word('world'),
        settings: const DisplaySettings(smartTiming: false),
      );
      expect(m, 1.0);
    });

    test('applies sentence pause when the current word ends a sentence', () {
      for (final ender in const ['end.', 'wow!', 'why?', 'and so on...', 'wait…']) {
        final m = computeWordIntervalMultiplier(
          currentWord: word(ender, timing: 1.0),
          nextWord: word('next'),
          settings: const DisplaySettings(
            smartTiming: false,
            sentencePauseMultiplier: 2.0,
          ),
        );
        expect(m, 2.0, reason: 'expected sentence pause for "$ender"');
      }
    });

    test('does not apply sentence pause for non-sentence-ending punctuation',
        () {
      for (final word in const ['comma,', 'semi;', 'colon:', 'quote"']) {
        final m = computeWordIntervalMultiplier(
          currentWord: WordToken(
            text: word,
            orpIndex: 0,
            timingMultiplier: 1.0,
            globalIndex: 0,
            chapterIndex: 0,
            paragraphIndex: 0,
          ),
          nextWord: null,
          settings: const DisplaySettings(
            smartTiming: false,
            sentencePauseMultiplier: 3.0,
          ),
        );
        expect(m, 1.0,
            reason: '"$word" should not trigger the sentence pause');
      }
    });

    test('applies chapter pause when the next word starts a new chapter', () {
      final m = computeWordIntervalMultiplier(
        currentWord: word('last', timing: 1.0),
        nextWord: word('Chapter', isChapterStart: true),
        settings: const DisplaySettings(
          smartTiming: false,
          chapterPauseMultiplier: 2.5,
        ),
      );
      expect(m, closeTo(2.5, 1e-9));
    });

    test('composes baked-in timing, sentence pause, and chapter pause', () {
      final m = computeWordIntervalMultiplier(
        currentWord: word('end.', timing: 2.0),
        nextWord: word('Chapter', isChapterStart: true),
        settings: const DisplaySettings(
          sentencePauseMultiplier: 1.5,
          chapterPauseMultiplier: 2.0,
        ),
      );
      // 2.0 (baked) * 1.5 (sentence) * 2.0 (chapter) = 6.0
      expect(m, closeTo(6.0, 1e-9));
    });

    test('clamps the combined product to 10.0', () {
      final m = computeWordIntervalMultiplier(
        currentWord: word('end.', timing: 5.0),
        nextWord: word('Chapter', isChapterStart: true),
        settings: const DisplaySettings(
          sentencePauseMultiplier: 4.0,
          chapterPauseMultiplier: 4.0,
        ),
      );
      // 5 * 4 * 4 = 80, clamped to 10.
      expect(m, 10.0);
    });

    test('custom pauses still apply when smartTiming is off', () {
      final m = computeWordIntervalMultiplier(
        currentWord: word('end.', timing: 5.0),
        nextWord: word('Chapter', isChapterStart: true),
        settings: const DisplaySettings(
          smartTiming: false,
          sentencePauseMultiplier: 2.0,
          chapterPauseMultiplier: 2.0,
        ),
      );
      // smartTiming off → baked timing is ignored (treated as 1.0).
      // 1.0 * 2.0 * 2.0 = 4.0
      expect(m, closeTo(4.0, 1e-9));
    });

    test('null currentWord and nextWord short-circuit to base 1.0', () {
      final m = computeWordIntervalMultiplier(
        currentWord: null,
        nextWord: null,
        settings: const DisplaySettings(
          sentencePauseMultiplier: 3.0,
          chapterPauseMultiplier: 3.0,
        ),
      );
      expect(m, 1.0);
    });
  });

  group('RsvpEngineNotifier', () {
    group('initialization', () {
      test('starts at chapter 0 word 0 with no saved progress', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        expect(engine.state.isLoading, isFalse);
        expect(engine.state.chapters, hasLength(2));
        expect(engine.state.currentChapterIndex, 0);
        expect(engine.state.currentWordIndex, 0);
        expect(engine.state.globalWordIndex, 0);
        expect(engine.state.totalWords, 6);
        expect(engine.state.currentWord?.text, 'alpha');
      });

      test('resumes from saved progress when present', () async {
        final mocks = _wireMocks(
          chapterRows: _twoChapterRows(),
          savedProgress: ReadingProgressTableData(
            bookId: 'book-1',
            chapterIndex: 1,
            wordIndex: 2,
            wpm: 420,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        expect(engine.state.currentChapterIndex, 1);
        expect(engine.state.currentWordIndex, 2);
        expect(engine.state.globalWordIndex, 5); // 3 + 2
        expect(engine.state.wpm, 420);
        expect(engine.state.currentWord?.text, 'zeta');
      });

      test('restores ereader mode from saved progress', () async {
        final mocks = _wireMocks(
          chapterRows: _twoChapterRows(),
          savedProgress: ReadingProgressTableData(
            bookId: 'book-1',
            chapterIndex: 0,
            wordIndex: 0,
            wpm: 300,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            readerMode: 'ereader',
          ),
        );
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        expect(engine.state.mode, ReaderMode.ereader);
        expect(engine.state.isLoading, isFalse);
      });

      test('restores tts mode from saved progress (calls enterTtsMode)',
          () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(
          chapterRows: _twoChapterRows(),
          savedProgress: ReadingProgressTableData(
            bookId: 'book-1',
            chapterIndex: 0,
            wordIndex: 0,
            wpm: 300,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            readerMode: 'tts',
          ),
        );
        final container = _ttsContainer(mocks, tts);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        // _loadBook awaits enterTtsMode internally, so by the time
        // _bootEngine returns the mode and backend should be ready.
        await _pumpMicrotasks();

        expect(engine.state.mode, ReaderMode.tts);
        expect(engine.state.isLoading, isFalse);
        expect(tts.initCalled, isTrue);
      });

      test('null readerMode in progress keeps the default scroll mode',
          () async {
        final mocks = _wireMocks(
          chapterRows: _twoChapterRows(),
          savedProgress: ReadingProgressTableData(
            bookId: 'book-1',
            chapterIndex: 0,
            wordIndex: 0,
            wpm: 300,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            readerMode: null,
          ),
        );
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        expect(engine.state.mode, ReaderMode.scroll);
      });
    });

    group('play / pause', () {
      test('play() transitions to isPlaying=true and mode=rsvp', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        expect(engine.state.mode, ReaderMode.scroll);
        expect(engine.state.isPlaying, isFalse);

        engine.play();

        expect(engine.state.isPlaying, isTrue);
        expect(engine.state.mode, ReaderMode.rsvp);
      });

      test('pause() reverts to scroll mode and isPlaying=false', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        engine.play();
        engine.pause();

        expect(engine.state.isPlaying, isFalse);
        expect(engine.state.mode, ReaderMode.scroll);
      });

      test('togglePlayPause flips between rsvp and scroll', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.togglePlayPause();
        expect(engine.state.isPlaying, isTrue);
        expect(engine.state.mode, ReaderMode.rsvp);

        engine.togglePlayPause();
        expect(engine.state.isPlaying, isFalse);
        expect(engine.state.mode, ReaderMode.scroll);
      });

      test('play() is a no-op when isLoading is true', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        // Keep the provider alive without awaiting the load future. While
        // _loadBook is still in flight, isLoading=true and play() bails.
        container.listen(rsvpEngineProvider('book-1'), (_, _) {});
        final engine =
            container.read(rsvpEngineProvider('book-1').notifier);
        expect(engine.state.isLoading, isTrue);

        engine.play();
        expect(engine.state.isPlaying, isFalse);
      });

      test('play() refuses when already at the last word', () async {
        final mocks = _wireMocks(
          chapterRows: _twoChapterRows(),
          savedProgress: ReadingProgressTableData(
            bookId: 'book-1',
            chapterIndex: 1,
            wordIndex: 2,
            wpm: 300,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        expect(engine.state.globalWordIndex, 5);
        expect(engine.state.totalWords, 6);

        engine.play();

        // globalWordIndex == totalWords - 1 → play short-circuits.
        expect(engine.state.isPlaying, isFalse);
      });
    });

    group('ereader mode', () {
      test('enterEreaderMode() sets mode to ereader and clears isPlaying',
          () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        engine.enterEreaderMode();

        expect(engine.state.mode, ReaderMode.ereader);
        expect(engine.state.isPlaying, isFalse);
      });

      test('enterEreaderMode while playing also saves progress', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        engine.play();
        engine.seekToWord(2); // Bump position so upsert isn't deduped.

        engine.enterEreaderMode();

        // Allow the awaited _saveProgress to flush.
        await Future<void>.value();
        verify(() => mocks.progress.upsertProgress(any())).called(greaterThan(0));
      });

      test('exitEreaderMode returns to scroll only when in ereader', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        // Already in scroll — should stay there.
        engine.exitEreaderMode();
        expect(engine.state.mode, ReaderMode.scroll);

        engine.enterEreaderMode();
        engine.exitEreaderMode();
        expect(engine.state.mode, ReaderMode.scroll);
      });

      test('toggleEreaderMode flips between ereader and scroll', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.toggleEreaderMode();
        expect(engine.state.mode, ReaderMode.ereader);

        engine.toggleEreaderMode();
        expect(engine.state.mode, ReaderMode.scroll);
      });
    });

    group('seek / skip / jumpToChapter', () {
      test('seekToWord moves to the correct (chapter, word)', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.seekToWord(4); // chapter 1, local word 1

        expect(engine.state.currentChapterIndex, 1);
        expect(engine.state.currentWordIndex, 1);
        expect(engine.state.globalWordIndex, 4);
        expect(engine.state.currentWord?.text, 'epsilon');
      });

      test('seekToWord clamps below 0 and above totalWords-1', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.seekToWord(-5);
        expect(engine.state.globalWordIndex, 0);

        engine.seekToWord(9999);
        expect(engine.state.globalWordIndex, 5);
        expect(engine.state.currentChapterIndex, 1);
        expect(engine.state.currentWordIndex, 2);
      });

      test('skipForward and skipBackward advance by the requested step',
          () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.skipForward(2);
        expect(engine.state.globalWordIndex, 2);

        engine.skipBackward(1);
        expect(engine.state.globalWordIndex, 1);
      });

      test('jumpToChapter goes to word 0 of that chapter', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.jumpToChapter(1);
        expect(engine.state.currentChapterIndex, 1);
        expect(engine.state.currentWordIndex, 0);
        expect(engine.state.globalWordIndex, 3);
      });

      test('jumpToChapter ignores out-of-range indices', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        final before = engine.state.globalWordIndex;

        engine.jumpToChapter(-1);
        engine.jumpToChapter(99);

        expect(engine.state.globalWordIndex, before);
      });
    });

    group('WPM controls', () {
      test('setWpm clamps to [minWpm, maxWpm] and mirrors into displaySettings',
          () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.setWpm(AppConstants.maxWpm + 200);
        expect(engine.state.wpm, AppConstants.maxWpm);
        expect(engine.state.displaySettings.wpm, AppConstants.maxWpm);

        engine.setWpm(AppConstants.minWpm - 50);
        expect(engine.state.wpm, AppConstants.minWpm);
        expect(engine.state.displaySettings.wpm, AppConstants.minWpm);

        engine.setWpm(350);
        expect(engine.state.wpm, 350);
      });

      test('increaseWpm / decreaseWpm step by wpmStep', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        final start = engine.state.wpm;

        engine.increaseWpm();
        expect(engine.state.wpm, start + AppConstants.wpmStep);

        engine.decreaseWpm();
        engine.decreaseWpm();
        expect(engine.state.wpm, start - AppConstants.wpmStep);
      });
    });

    group('persistence', () {
      test('pause() persists current progress', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.play();
        engine.seekToWord(2);
        engine.pause();

        // pause() awaits _saveProgress internally → wait one microtask to flush.
        await Future<void>.value();

        verify(() => mocks.progress.upsertProgress(any()))
            .called(greaterThanOrEqualTo(1));
        verify(() => mocks.books.updateLastReadAt('book-1'))
            .called(greaterThanOrEqualTo(1));
      });

      test('seek while paused schedules a debounced progress save', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.seekToWord(3);

        // _scheduleSaveProgress uses a 300ms Timer. We need real-time-ish
        // passage to let it fire.
        await Future<void>.delayed(const Duration(milliseconds: 350));

        verify(() => mocks.progress.upsertProgress(
              any(
                that: isA<ReadingProgressTableCompanion>().having(
                  (c) => c.chapterIndex,
                  'chapterIndex',
                  const Value(1),
                ),
              ),
            )).called(greaterThanOrEqualTo(1));
      });
    });

    group('inline images', () {
      test('play() on an image token stays paused and switches to rsvp mode',
          () async {
        final mocks = _wireMocks(chapterRows: _chapterWithImageRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        engine.seekToWord(1); // land on the image token
        expect(engine.state.currentWord?.isImage, isTrue);
        expect(engine.state.mode, ReaderMode.scroll);

        engine.play();

        expect(engine.state.mode, ReaderMode.rsvp);
        expect(engine.state.isPlaying, isFalse);
        // The cursor stays parked on the image — we don't advance through
        // it on play. The user has to dismiss it explicitly.
        expect(engine.state.globalWordIndex, 1);
        expect(engine.state.currentWord?.isImage, isTrue);
      });

      test('dismissImage advances past the figure and resumes playback',
          () async {
        final mocks = _wireMocks(chapterRows: _chapterWithImageRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        engine.seekToWord(1);
        engine.play(); // primes mode=rsvp, isPlaying=false (image)

        engine.dismissImage();

        // Cursor moved one slot ahead and engine resumed playback.
        expect(engine.state.globalWordIndex, 2);
        expect(engine.state.currentWord?.isImage, isFalse);
        expect(engine.state.currentWord?.text, 'after');
        expect(engine.state.isPlaying, isTrue);
        expect(engine.state.mode, ReaderMode.rsvp);
      });

      test('dismissImage is a no-op when not on an image', () async {
        final mocks = _wireMocks(chapterRows: _chapterWithImageRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        // Cursor sits on the leading text token, not an image.
        expect(engine.state.currentWord?.isImage, isFalse);
        final before = engine.state.globalWordIndex;

        engine.dismissImage();

        expect(engine.state.globalWordIndex, before);
        expect(engine.state.isPlaying, isFalse);
      });

      test('dismissImage on the last token does not advance off the end',
          () async {
        final mocks = _wireMocks(
          chapterRows: [
            CachedTokensTableData(
              id: 1,
              bookId: 'book-1',
              chapterIndex: 0,
              chapterTitle: 'Chapter 0',
              tokensJson: jsonEncode([
                _token(
                  text: 'first',
                  globalIndex: 0,
                  chapterIndex: 0,
                  isChapterStart: true,
                ).toJson(),
                _imageToken(globalIndex: 1, chapterIndex: 0, paragraphIndex: 1)
                    .toJson(),
              ]),
              wordCount: 2,
              paragraphCount: 2,
            ),
          ],
        );
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());
        engine.seekToWord(1);
        expect(engine.state.currentWord?.isImage, isTrue);

        engine.dismissImage();

        // Image was the last token — cursor doesn't move, playback stays
        // paused (no text word left to roll into).
        expect(engine.state.globalWordIndex, 1);
        expect(engine.state.isPlaying, isFalse);
      });
    });

    group('updateDisplaySettings', () {
      test('replaces the displaySettings via the supplied updater', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);

        final engine = await _bootEngine(container, _FakeTickerProvider());

        const expected = DisplaySettings(wpm: 555, fontSize: 32);
        engine.updateDisplaySettings((_) => expected);

        expect(engine.state.displaySettings, same(expected));
      });
    });

    group('TTS mode', () {
      test('enterTtsMode transitions to tts and initialises the backend',
          () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        // applySettings is fired without await; pump microtasks so the
        // language assignment lands before we check.
        await _pumpMicrotasks();

        expect(engine.state.mode, ReaderMode.tts);
        expect(engine.state.isPlaying, isFalse);
        expect(tts.initCalled, isTrue);
        // Settings should have been applied up front.
        expect(tts.language, 'en-US');
      });

      test('enterTtsMode while playing flushes the existing session',
          () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.play(); // start RSVP
        expect(engine.state.isPlaying, isTrue);

        await engine.enterTtsMode();

        expect(engine.state.mode, ReaderMode.tts);
        expect(engine.state.isPlaying, isFalse);
      });

      test('pause in tts mode keeps mode == tts (does not flip to scroll)',
          () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        engine.play();
        expect(engine.state.mode, ReaderMode.tts);
        expect(engine.state.isPlaying, isTrue);

        engine.pause();
        expect(engine.state.mode, ReaderMode.tts);
        expect(engine.state.isPlaying, isFalse);
        expect(tts.stopCalled, isTrue);
      });

      test(
          'progress callback advances globalWordIndex while in tts + playing',
          () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        engine.play();
        // The player applies settings then enqueues the lookahead pipeline;
        // pump microtasks until both speaks have been issued.
        await _pumpMicrotasks();
        expect(tts.speakCalls, isNotEmpty);

        // The two-chapter fixture has no terminal punctuation, so segment 0
        // captures all 3 tokens of chapter 0 in one chunk. tokenCharOffsets
        // for ['alpha', 'beta', 'gamma'] joined with spaces: alpha=0,
        // beta=6, gamma=11. Simulate a progress callback at the start of
        // "beta" (global index 1).
        tts.emitProgress(6, 10, 'beta');

        expect(engine.state.globalWordIndex, 1);
      });

      test('play() pre-queues a lookahead segment in add-mode', () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        engine.play();
        await _pumpMicrotasks();

        // Two segments queued: chapter 0 (flush) + chapter 1 (add).
        expect(tts.speakCalls.length, 2);
        expect(tts.speakModes, [TtsQueueMode.flush, TtsQueueMode.add]);
      });

      test('completion advances past the spoken segment', () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        engine.play();
        await _pumpMicrotasks();

        // First chapter has 3 tokens; completion of segment 0 advances the
        // cursor to index 3 (the start of chapter 1, the segment cap).
        // No new speak fires because segment 1 was already pre-queued.
        tts.emitCompletion();
        await _pumpMicrotasks();

        expect(engine.state.globalWordIndex, 3);
      });

      test('completion at end-of-book bumps finishTicket exactly once',
          () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        // Seek to the last word so the next segment ends the book.
        engine.seekToWord(5);
        engine.play();
        await _pumpMicrotasks();

        final beforeTicket = engine.state.finishTicket;
        tts.emitCompletion();
        await _pumpMicrotasks();

        expect(engine.state.finishTicket, beforeTicket + 1);
        expect(engine.state.isPlaying, isFalse);
      });

      test('exitTtsMode returns to scroll and clears playback', () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        engine.play();
        await _pumpMicrotasks();

        engine.exitTtsMode();

        expect(engine.state.mode, ReaderMode.scroll);
        expect(engine.state.isPlaying, isFalse);
      });

      test('seekToWord while tts playing restarts speak from the new index',
          () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        engine.play();
        await _pumpMicrotasks();
        final firstSpeak = tts.speakCalls.length;
        tts.stopCalled = false;

        engine.seekToWord(4);
        await _pumpMicrotasks();

        expect(tts.stopCalled, isTrue);
        // The player flushes its queue then re-fills from the new index;
        // at least one new speak was issued (in flush mode this time).
        expect(tts.speakCalls.length, greaterThan(firstSpeak));
        expect(engine.state.globalWordIndex, 4);
        expect(tts.speakModes.last, TtsQueueMode.flush);
      });
    });

    group('persisted reader mode', () {
      test('enterEreaderMode upserts readerMode="ereader"', () async {
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _container(mocks);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        engine.enterEreaderMode();
        await _pumpMicrotasks();

        verify(() => mocks.progress.upsertProgress(
              any(
                that: isA<ReadingProgressTableCompanion>().having(
                  (c) => c.readerMode,
                  'readerMode',
                  const Value('ereader'),
                ),
              ),
            )).called(1);
      });

      test('exitEreaderMode upserts readerMode="rsvp"', () async {
        final mocks = _wireMocks(
          chapterRows: _twoChapterRows(),
          savedProgress: ReadingProgressTableData(
            bookId: 'book-1',
            chapterIndex: 0,
            wordIndex: 0,
            wpm: 300,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            readerMode: 'ereader',
          ),
        );
        final container = _container(mocks);
        final engine = await _bootEngine(container, _FakeTickerProvider());
        expect(engine.state.mode, ReaderMode.ereader);

        // Restore should not have triggered any persistence call.
        verifyNever(() => mocks.progress.upsertProgress(any()));

        engine.exitEreaderMode();
        await _pumpMicrotasks();

        verify(() => mocks.progress.upsertProgress(
              any(
                that: isA<ReadingProgressTableCompanion>().having(
                  (c) => c.readerMode,
                  'readerMode',
                  const Value('rsvp'),
                ),
              ),
            )).called(1);
      });

      test('enterTtsMode upserts readerMode="tts"', () async {
        final tts = _StubTtsBackend();
        final mocks = _wireMocks(chapterRows: _twoChapterRows());
        final container = _ttsContainer(mocks, tts);
        final engine = await _bootEngine(container, _FakeTickerProvider());

        await engine.enterTtsMode();
        await _pumpMicrotasks();

        verify(() => mocks.progress.upsertProgress(
              any(
                that: isA<ReadingProgressTableCompanion>().having(
                  (c) => c.readerMode,
                  'readerMode',
                  const Value('tts'),
                ),
              ),
            )).called(1);
      });

      test('auto-restore does NOT trigger a save (dedup honours existing mode)',
          () async {
        final mocks = _wireMocks(
          chapterRows: _twoChapterRows(),
          savedProgress: ReadingProgressTableData(
            bookId: 'book-1',
            chapterIndex: 0,
            wordIndex: 0,
            wpm: 300,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            readerMode: 'ereader',
          ),
        );
        final container = _container(mocks);
        await _bootEngine(container, _FakeTickerProvider());
        await _pumpMicrotasks();

        verifyNever(() => mocks.progress.upsertProgress(any()));
      });
    });
  });
}

/// Stub backend used by the TTS-mode group. Records every interaction and
/// exposes hooks so individual tests can fire `_onProgress` /
/// `_onCompletion` / `_onError` synchronously — none of these tests pump
/// real audio.
class _StubTtsBackend implements TtsBackend {
  bool initCalled = false;
  final List<String> speakCalls = [];
  final List<TtsQueueMode> speakModes = [];
  bool stopCalled = false;
  String? language;
  TtsVoice? voice;
  double? rate;
  double? pitch;
  String? engineId;

  @override
  bool get canPipeline => true;

  TtsProgressHandler? _onProgress;
  VoidCallback? _onCompletion;
  void Function(String)? _onError;
  // _onStart is set by the engine but the stubbed backend never fires it;
  // we accept the setter to keep the interface honest.

  void emitProgress(int offset, int end, String word) =>
      _onProgress?.call(offset, end, word);
  void emitCompletion() => _onCompletion?.call();
  void emitError(String e) => _onError?.call(e);

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<List<TtsVoice>> getVoices() async => const [];

  @override
  Future<List<String>> getLanguages() async => const [];

  @override
  Future<List<TtsEngine>> getEngines() async => const [];

  @override
  Future<void> setEngine(String id) async {
    engineId = id;
  }

  @override
  Future<void> setVoice(TtsVoice? v) async {
    voice = v;
  }

  @override
  Future<void> setLanguage(String iso) async {
    language = iso;
  }

  @override
  Future<void> setRate(double r) async {
    rate = r;
  }

  @override
  Future<void> setPitch(double p) async {
    pitch = p;
  }

  @override
  Future<void> speak(
    String text, {
    TtsQueueMode mode = TtsQueueMode.flush,
  }) async {
    speakCalls.add(text);
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

  @override
  set onError(void Function(String error)? cb) => _onError = cb;

  @override
  set onStart(VoidCallback? cb) {
    // Not used in these tests; the stub never fires the start hook.
  }
}

/// Yields enough microtasks so chained awaits inside the engine + player
/// (apply-settings, enqueue, speak, …) have time to resolve before
/// assertions run. 30 is comfortably above the deepest chain we have.
Future<void> _pumpMicrotasks([int count = 30]) async {
  for (var i = 0; i < count; i++) {
    await Future<void>.value();
  }
}

/// Like [_container] but with the TTS backend provider overridden to a stub.
ProviderContainer _ttsContainer(_Mocks mocks, _StubTtsBackend backend) {
  final container = ProviderContainer(
    overrides: [
      cachedTokensDaoProvider.overrideWithValue(mocks.tokens),
      readingProgressDaoProvider.overrideWithValue(mocks.progress),
      readingSessionDaoProvider.overrideWithValue(mocks.sessions),
      booksDaoProvider.overrideWithValue(mocks.books),
      librarySyncProvider.overrideWith((ref) => _StubLibrarySyncNotifier(ref)),
      ttsBackendProvider.overrideWithValue(backend),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
  });
  return container;
}
