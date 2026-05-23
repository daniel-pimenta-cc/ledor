/// One contiguous run of tokens the TTS engine speaks in a single call.
///
/// Built by `extractSentenceFrom`. Ranges by `globalWordIndex` (book-level
/// indexing the engine already uses); the spoken text is exactly what the
/// backend will synthesise. Image tokens are part of the range (they advance
/// the highlight) but never enter the spoken string — listeners can't hear
/// pictures.
class SentenceSegment {
  /// First book-level word index this segment covers, inclusive.
  final int startGlobalIndex;

  /// One past the last book-level word index this segment covers. For a
  /// segment containing only token N, this is N + 1.
  final int endGlobalIndexExcl;

  /// String passed directly to the TTS engine. Tokens are joined with a
  /// single space; image tokens are skipped. May be empty if the range was
  /// all images (caller decides what to do).
  final String spokenText;

  /// Character offsets of each speakable token's first character within
  /// [spokenText]. `tokenCharOffsets[i]` corresponds to the i-th speakable
  /// token; image tokens within the range do not get an entry. Always
  /// monotonically increasing. Used in the TTS progress callback to map a
  /// charOffset reported by the engine back to a globalWordIndex.
  final List<int> tokenCharOffsets;

  /// Book-level word index of each speakable token, paired one-to-one with
  /// [tokenCharOffsets]. Lets the callback translate a charOffset hit back
  /// to the right `globalWordIndex` even when image tokens punched holes in
  /// the sequence.
  final List<int> tokenGlobalIndices;

  const SentenceSegment({
    required this.startGlobalIndex,
    required this.endGlobalIndexExcl,
    required this.spokenText,
    required this.tokenCharOffsets,
    required this.tokenGlobalIndices,
  });

  bool get isEmpty => spokenText.isEmpty;

  /// Total number of words (including image-only tokens) in the range. The
  /// engine uses this to advance globalWordIndex past the segment when the
  /// TTS engine reports completion.
  int get length => endGlobalIndexExcl - startGlobalIndex;
}
