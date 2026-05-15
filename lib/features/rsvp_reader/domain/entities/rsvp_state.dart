import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import 'display_settings.dart';

enum ReaderMode { rsvp, scroll, ereader }

class RsvpState {
  final String bookId;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final int currentWordIndex;
  final int globalWordIndex;
  final int totalWords;
  final WordToken? currentWord;
  final int wpm;
  final bool isPlaying;
  final bool isLoading;
  final ReaderMode mode;
  final DisplaySettings displaySettings;

  /// Increments by 1 each time playback reaches end-of-book organically
  /// (via `_advanceWord`, not via seek). UI listeners compare the value
  /// across state changes to trigger the completion screen exactly once
  /// per finish — a flag would risk re-firing on replay.
  final int finishTicket;

  const RsvpState({
    required this.bookId,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.currentWordIndex = 0,
    this.globalWordIndex = 0,
    this.totalWords = 0,
    this.currentWord,
    this.wpm = 300,
    this.isPlaying = false,
    this.isLoading = true,
    this.mode = ReaderMode.scroll,
    this.displaySettings = const DisplaySettings(),
    this.finishTicket = 0,
  });

  double get progress => totalWords > 0 ? globalWordIndex / totalWords : 0;

  String? get currentChapterTitle =>
      chapters.isNotEmpty && currentChapterIndex < chapters.length
          ? chapters[currentChapterIndex].title
          : null;

  int get estimatedMinutesRemaining {
    if (wpm <= 0) return 0;
    final remaining = totalWords - globalWordIndex;
    return (remaining / wpm).ceil();
  }

  /// Estimated minutes left in the current chapter at [wpm]. Mirrors
  /// [estimatedMinutesRemaining] but scoped to `chapters[currentChapterIndex]`.
  int get chapterMinutesRemaining {
    if (wpm <= 0) return 0;
    if (chapters.isEmpty || currentChapterIndex >= chapters.length) return 0;
    final chapterWords = chapters[currentChapterIndex].tokens.length;
    final remaining = chapterWords - currentWordIndex;
    if (remaining <= 0) return 0;
    return (remaining / wpm).ceil();
  }

  RsvpState copyWith({
    String? bookId,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    int? currentWordIndex,
    int? globalWordIndex,
    int? totalWords,
    WordToken? currentWord,
    int? wpm,
    bool? isPlaying,
    bool? isLoading,
    ReaderMode? mode,
    DisplaySettings? displaySettings,
    int? finishTicket,
  }) {
    return RsvpState(
      bookId: bookId ?? this.bookId,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      globalWordIndex: globalWordIndex ?? this.globalWordIndex,
      totalWords: totalWords ?? this.totalWords,
      currentWord: currentWord ?? this.currentWord,
      wpm: wpm ?? this.wpm,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      mode: mode ?? this.mode,
      displaySettings: displaySettings ?? this.displaySettings,
      finishTicket: finishTicket ?? this.finishTicket,
    );
  }
}
