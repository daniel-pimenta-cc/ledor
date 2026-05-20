/// Returns `true` when [text] ends a sentence — terminal punctuation that
/// the RSVP engine treats as a structural pause point. Shared by:
///   - `rsvp_engine_provider.computeWordIntervalMultiplier` (sentencePause)
///   - `sentence_extractor.extractSentenceFrom` (TTS sentence chunking)
///   - `context_scroll_view` (velocity-based sentence-skip on scroll)
bool wordEndsSentence(String text) {
  if (text.endsWith('…') || text.endsWith('...')) return true;
  return text.endsWith('.') || text.endsWith('!') || text.endsWith('?');
}
