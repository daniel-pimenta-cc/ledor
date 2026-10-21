import 'dart:math';

/// Calculates display-time multipliers for RSVP word timing.
///
/// Base display time = 60000ms / WPM.
/// The multiplier adjusts this per word based on length, punctuation, etc.
class WordTiming {
  const WordTiming._();

  /// A merged dialogue unit starts with a dash followed by a space
  /// ("— word"). Lone dashes (no trailing space) keep the old behavior.
  static final _leadingDash = RegExp(r'^[—–-] ');

  /// Calculate the timing multiplier for [word].
  ///
  /// Returns a value typically between 0.5 and 5.0 where 1.0 = normal speed.
  static double calculateMultiplier(
    String word, {
    bool isParagraphStart = false,
    bool isChapterStart = false,
  }) {
    double multiplier = 1.0;

    // Strip punctuation to get core word length
    final coreLength = word.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').length;

    // Short words are faster to process
    if (coreLength <= 3) {
      multiplier = 0.9;
    }
    // Long words need more time: +10% per char over 6, capped at 2.0x
    else if (coreLength > 6) {
      multiplier = 1.0 + min((coreLength - 6) * 0.1, 1.0);
    }

    // Punctuation-based pauses
    if (word.endsWith('...') || word.endsWith('\u2026')) {
      multiplier *= 2.5;
    } else if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
      multiplier *= 2.0;
    } else if (word.endsWith(':')) {
      multiplier *= 1.8;
    } else if (word.endsWith(',') || word.endsWith(';')) {
      multiplier *= 1.5;
    } else if (word.endsWith('"') ||
        word.endsWith("'") ||
        word.endsWith(')') ||
        word.endsWith('\u201D') ||
        word.endsWith('\u2019')) {
      multiplier *= 1.3;
    }

    // Leading dialogue dash ("— word" merged unit): a brief beat on top of
    // the word, like a comma.
    if (_leadingDash.hasMatch(word)) {
      multiplier *= 1.5;
    }

    // Structural pauses
    if (isChapterStart) {
      multiplier *= 3.0;
    } else if (isParagraphStart) {
      multiplier *= 1.5;
    }

    return multiplier.clamp(0.5, 5.0);
  }
}
