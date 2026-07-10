// Helpers for the Linux TTS backend ([SpeechdSocketBackend] over the SSIP
// socket): the output-module → display-name mapping and the word-boundary
// tokeniser. Kept in their own file so the backend stays focused on the
// SSIP wire protocol.

import 'tts_backend.dart';

/// Word-boundary char offsets used by the Linux backend to emit approximate
/// progress callbacks at a wall-clock cadence (a bare SSIP `SPEAK` doesn't
/// expose real per-word callbacks without SSML index marks, which most
/// output modules don't implement).
///
/// Returns the starting char offset of each whitespace-delimited word
/// in [text]. Multiple-space runs collapse into a single boundary;
/// leading whitespace doesn't emit an offset.
List<int> wordCharOffsets(String text) {
  final offsets = <int>[];
  bool inWord = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    final isSpace = ch == ' ' || ch == '\n' || ch == '\t';
    if (!isSpace && !inWord) {
      offsets.add(i);
      inWord = true;
    } else if (isSpace) {
      inWord = false;
    }
  }
  return offsets;
}

/// Turns a `speech-dispatcher` output module id into a friendlier display
/// label for the engine picker. Falls through to the raw id for modules
/// not in the table.
String humaniseSpeechdModuleId(String id) {
  switch (id.toLowerCase()) {
    case 'espeak-ng':
    case 'espeak':
      return 'eSpeak NG';
    case 'festival':
      return 'Festival';
    case 'flite':
      return 'Flite';
    case 'rhvoice':
      return 'RHVoice';
    case 'pico':
      return 'Pico';
    case 'piper':
      return 'Piper TTS';
    default:
      return id;
  }
}

/// Wraps a module id as a [TtsEngine]. Convenience for the parsers below.
TtsEngine speechdModuleAsEngine(String id) =>
    TtsEngine(id: id, displayName: humaniseSpeechdModuleId(id));
