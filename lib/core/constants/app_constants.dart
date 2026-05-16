abstract final class AppConstants {
  static const int defaultWpm = 300;
  static const int minWpm = 50;
  static const int maxWpm = 1000;
  static const int wpmStep = 25;
  static const int skipWordCount = 10;

  /// Ramp-up: number of words to reach target WPM after pressing play.
  static const int rampUpWords = 30;

  /// Ramp-up: starting speed as fraction of target WPM (0.5 = 50%).
  static const double rampUpStartFraction = 0.7;

  /// Time the first word stays on screen after pressing play before the
  /// engine advances. Covers the `AppDurations.slow` AnimatedSwitcher fade
  /// between scroll → rsvp plus a small buffer so the eyes have time to
  /// settle on the word before it moves.
  static const Duration playPreRollDelay = Duration(milliseconds: 500);

  static const double defaultFontSize = 48.0;
  static const double defaultContextFontSize = 18.0;
  static const double minFontSize = 20.0;
  static const double maxFontSize = 80.0;
  static const double minContextFontSize = 12.0;
  static const double maxContextFontSize = 32.0;

  static const int defaultWordColor = 0xFFE0E0E0;
  static const int defaultOrpColor = 0xFFE55324;
  static const int defaultBackgroundColor = 0xFF121212;
  static const int defaultHighlightColor = 0x40FFAB00;

  static const double defaultVerticalPosition = 0.5;

  /// Focus alignment (0 = top, 1 = bottom) for the highlighted word in
  /// the context/ereader viewport. Mirrors `ScrollablePositionedList`'s
  /// alignment convention.
  static const double contextFocusAlignment = 0.5;
  static const String defaultFontFamily = 'RobotoMono';

  static const String booksSubdir = 'books';

  /// Subdirectory under the app documents dir where inline EPUB images are
  /// kept. Each book gets its own folder `<docs>/book_images/<bookId>/` so
  /// deleting a book is a single recursive rmdir.
  static const String bookImagesSubdir = 'book_images';

  // ---- RSVP word display layout ----
  /// Horizontal margin reserved on each side of the word. The focus line
  /// ignores this and spans full width, so the parent widget must NOT add
  /// its own horizontal padding.
  static const double rsvpWordMargin = 32.0;

  /// Minimum font size when auto-scaling long words down.
  static const double rsvpMinFontSize = 16.0;

  /// Step used to shrink the font when the word does not fit.
  static const double rsvpFontShrinkStep = 2.0;

  /// Height of the notch triangle above the ORP anchor.
  static const double rsvpNotchHeight = 6.0;

  /// Vertical gap between the notch and the word.
  static const double rsvpNotchGap = 4.0;

  /// Width of the horizontal line drawn above the ORP letter when the
  /// indicator style is `lineAbove`. About the width of one or two glyphs
  /// so the line reads as a tick mark, not a bar.
  static const double rsvpOrpLineWidth = 18.0;

  /// Thickness of the horizontal ORP line. Kept thin (1.5px) so it reads
  /// as a line, not a block.
  static const double rsvpOrpLineHeight = 1.5;

  /// Length (vertical) of the short vertical tick marks above and below
  /// the ORP letter when the indicator style is `linesAround`.
  static const double rsvpOrpTickLength = 5.0;

  /// Thickness (horizontal) of the vertical tick marks.
  static const double rsvpOrpTickThickness = 1.5;

  /// Gap between the word and each vertical tick in `linesAround`.
  static const double rsvpOrpTickGap = 3.0;

  /// Vertical gap between the word and the focus line below it.
  static const double rsvpFocusLineGap = 10.0;

  /// Thickness of the focus line.
  static const double rsvpFocusLineHeight = 2.0;
}
