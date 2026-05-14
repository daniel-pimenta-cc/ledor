import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/display_settings.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/rsvp_state.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart';
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

    test('interpolates linearly across the ramp window', () {
      const target = 400.0;
      final start = target * AppConstants.rampUpStartFraction;
      final mid = computeEffectiveWpm(
        targetWpm: 400,
        wordsInSession: AppConstants.rampUpWords ~/ 2,
        rampUpEnabled: true,
      );
      // Halfway through the ramp the WPM is halfway between start and target.
      expect(mid, closeTo((start + target) / 2, 0.01));
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
  });
}
