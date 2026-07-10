/// Calculates the Optimal Recognition Point (ORP) for a word.
///
/// The ORP is the character where the eye naturally fixates for fastest
/// word recognition — typically at ~30% from the word start.
class OrpCalculator {
  const OrpCalculator._();

  // Same letter/digit pattern used by word_timing.dart, for consistency.
  static final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

  // Lookup table for words with 1-13 alphabetic characters.
  // Index 0 = length 1, index 12 = length 13.
  static const _lookup = [
    0, // 1
    0, // 2
    1, // 3
    1, // 4
    1, // 5
    2, // 6
    2, // 7
    2, // 8
    3, // 9
    3, // 10
    3, // 11
    4, // 12
    4, // 13
  ];

  /// Returns the 0-based index of the ORP character in [word].
  ///
  /// Skips leading punctuation (quotes, brackets) for the calculation
  /// but the returned index is into the full string.
  static int calculate(String word) {
    if (word.isEmpty) return 0;

    // Find the first letter/digit in the word
    int firstAlpha = -1;
    int alphaCount = 0;

    for (int i = 0; i < word.length; i++) {
      if (_letterOrDigit.hasMatch(word[i])) {
        if (firstAlpha == -1) firstAlpha = i;
        alphaCount++;
      }
    }

    if (firstAlpha == -1) return 0; // all punctuation

    // Determine ORP position within alphabetic characters
    final int orpInAlpha;
    if (alphaCount <= _lookup.length) {
      orpInAlpha = _lookup[alphaCount - 1];
    } else {
      orpInAlpha = (alphaCount * 0.35).floor();
    }

    // Map back to full-string index
    int count = 0;
    for (int i = 0; i < word.length; i++) {
      if (_letterOrDigit.hasMatch(word[i])) {
        if (count == orpInAlpha) return i;
        count++;
      }
    }

    return firstAlpha;
  }
}
