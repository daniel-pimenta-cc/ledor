import 'package:collection/collection.dart';

import '../../../epub_import/domain/entities/chapter.dart';
import '../entities/sentence_segment.dart';

/// Default chunk cap handed to the TTS engine in one go.
///
/// `TtsPlayer` pipelines two of these via the backend's queue, so the
/// platform engine stitches them together with no audible gap. We still
/// cap the individual chunk so a single `stop()` (pause/seek) is fast and
/// the queue stays manageable on slow devices.
///
/// 200 tokens at ~6 chars/token ≈ 1200 chars per `speak()`, well below
/// the platform limits (Android: 4000, iOS: no hard limit).
const int kSentenceMaxTokens = 200;

/// Extracts the next chunk of speakable tokens starting at [startGlobalIndex].
///
/// Stops on:
///
/// - The next token would start a new chapter (the chapter title lands at
///   the start of the next call, giving the chapter pause a natural seam).
/// - [maxTokens] tokens have been accumulated (safety cap).
///
/// Sentence terminators and paragraph boundaries are deliberately ignored:
/// the TTS engine produces natural prosody between sentences on its own,
/// and chunking at those points would re-introduce the per-`speak()`
/// latency the larger chunks are meant to avoid.
///
/// Image tokens are part of the range (`endGlobalIndexExcl` includes them)
/// but never enter [SentenceSegment.spokenText] — they're silent.
///
/// Returns `null` when [startGlobalIndex] is past the end of the book or
/// the (chapterIndex, wordIndex) resolution lands on nothing speakable AND
/// no further tokens exist.
///
/// The name still says "sentence" for historical reasons (the engine was
/// originally one-speak-per-sentence); the unit is now a chapter chunk.
SentenceSegment? extractSentenceFrom(
  List<Chapter> chapters,
  int startGlobalIndex, {
  int maxTokens = kSentenceMaxTokens,
}) {
  if (chapters.isEmpty) return null;
  final start = _globalToLocal(chapters, startGlobalIndex);
  if (start == null) return null;

  int chapterIdx = start.$1;
  int wordIdx = start.$2;
  int globalIdx = startGlobalIndex;

  final buffer = StringBuffer();
  final tokenCharOffsets = <int>[];
  final tokenGlobalIndices = <int>[];

  int collected = 0;

  while (chapterIdx < chapters.length) {
    final tokens = chapters[chapterIdx].tokens;

    // Stop at chapter seam (the seam belongs to the NEXT segment so the
    // chapter title reads first after the pause).
    final isFirstTokenOfChapter = wordIdx == 0;
    if (isFirstTokenOfChapter && collected > 0) break;

    if (wordIdx >= tokens.length) {
      chapterIdx++;
      wordIdx = 0;
      continue;
    }

    final token = tokens[wordIdx];

    if (token.isImage) {
      // Image: included in the range, skipped in spokenText.
      collected++;
      globalIdx++;
      wordIdx++;
      continue;
    }

    // Speakable token. Add a leading space if not the first speakable token.
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    tokenCharOffsets.add(buffer.length);
    tokenGlobalIndices.add(globalIdx);
    buffer.write(token.text);

    collected++;
    globalIdx++;
    wordIdx++;

    if (collected >= maxTokens) break;
  }

  if (collected == 0) return null;

  return SentenceSegment(
    startGlobalIndex: startGlobalIndex,
    endGlobalIndexExcl: globalIdx,
    spokenText: buffer.toString(),
    tokenCharOffsets: List.unmodifiable(tokenCharOffsets),
    tokenGlobalIndices: List.unmodifiable(tokenGlobalIndices),
  );
}

/// Converts a book-level [globalIndex] into `(chapterIndex, wordIndex)`.
/// Returns `null` when the index is at or past the end of the book.
(int, int)? _globalToLocal(List<Chapter> chapters, int globalIndex) {
  if (globalIndex < 0) return null;
  int remaining = globalIndex;
  for (int c = 0; c < chapters.length; c++) {
    final len = chapters[c].tokens.length;
    if (remaining < len) {
      return (c, remaining);
    }
    remaining -= len;
  }
  return null;
}

/// Lower bound for [target] in a sorted [offsets] list.
///
/// Returns the index `i` such that `offsets[i] <= target < offsets[i+1]`
/// (or `offsets.length - 1` when [target] is past the last entry, or `-1`
/// when [target] is below the first entry).
///
/// Used by the TTS progress callback to map a charOffset reported by the
/// engine to the matching speakable-token index inside a [SentenceSegment].
int charOffsetToTokenIndex(List<int> offsets, int target) =>
    lowerBound(offsets, target + 1) - 1;
