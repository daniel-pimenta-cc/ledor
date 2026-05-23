import '../../features/epub_import/domain/entities/word_token.dart';

/// Builds a short, human-readable snippet around the bookmarked word.
///
/// Example output for `[WORD]` at index 50 with [contextWords] = 4:
///
///     "…brown fox jumps over [the] lazy dog and…"
///
/// The leading "…" appears when content existed before the captured window
/// that we couldn't include; the trailing one appears symmetrically. Image
/// and empty-text tokens are skipped while walking out — they aren't useful
/// as preview anchors and would render as blank cells.
///
/// Returns `null` when the target word is empty or out of range.
String? buildBookmarkSnippet({
  required List<WordToken> tokens,
  required int targetLocalIndex,
  int contextWords = 4,
}) {
  if (tokens.isEmpty) return null;
  if (targetLocalIndex < 0 || targetLocalIndex >= tokens.length) return null;
  final target = tokens[targetLocalIndex];
  final targetText = target.text.trim();
  if (targetText.isEmpty || target.isImage) return null;

  final before = <String>[];
  int i = targetLocalIndex - 1;
  for (; i >= 0 && before.length < contextWords; i--) {
    final t = tokens[i];
    if (t.isImage) continue;
    final txt = t.text.trim();
    if (txt.isEmpty) continue;
    before.insert(0, txt);
  }

  final after = <String>[];
  int j = targetLocalIndex + 1;
  for (; j < tokens.length && after.length < contextWords; j++) {
    final t = tokens[j];
    if (t.isImage) continue;
    final txt = t.text.trim();
    if (txt.isEmpty) continue;
    after.add(txt);
  }

  // `i` is one past the last index we considered going backwards (-1 when
  // the walk reached the start of the paragraph). `_hasMoreContent` from
  // there asks "is there still useful content we DIDN'T include?", which is
  // the right signal for whether to add the leading ellipsis. Same on the
  // trailing side with `j`.
  final hasMoreBefore = i >= 0 && _hasMoreContent(tokens, i, -1);
  final hasMoreAfter = j < tokens.length && _hasMoreContent(tokens, j, 1);

  final parts = <String>[];
  if (hasMoreBefore) parts.add('…');
  if (before.isNotEmpty) parts.add(before.join(' '));
  parts.add('[$targetText]');
  if (after.isNotEmpty) parts.add(after.join(' '));
  if (hasMoreAfter) parts.add('…');

  return parts.join(' ');
}

bool _hasMoreContent(List<WordToken> tokens, int startIdx, int step) {
  int i = startIdx;
  while (i >= 0 && i < tokens.length) {
    final t = tokens[i];
    if (!t.isImage && t.text.trim().isNotEmpty) return true;
    i += step;
  }
  return false;
}
