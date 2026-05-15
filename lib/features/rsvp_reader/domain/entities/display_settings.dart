import 'dart:ui';

import '../../../../core/constants/app_constants.dart';

/// Visual style used to point at the ORP letter above (and optionally below)
/// the word in the RSVP display.
enum OrpIndicatorStyle {
  /// Downward triangle above the ORP letter. Default — matches the original
  /// design.
  notch,

  /// Short horizontal line above the ORP letter.
  lineAbove,

  /// Short horizontal lines both above and below the ORP letter.
  linesAround,

  /// No indicator drawn.
  off,
}

/// What the reader shows next to the chapter title in the controls meta row.
enum TimeRemainingMode {
  /// Total minutes left in the whole book. Default — matches the original
  /// design.
  total,

  /// Minutes left in the current chapter only.
  chapter,

  /// Hide the time-remaining text entirely.
  off,
}

class DisplaySettings {
  final int wpm;
  final double fontSize;
  final double contextFontSize;
  final int wordColorValue;
  final int orpColorValue;
  final int backgroundColorValue;
  final int highlightColorValue;
  final double verticalPosition;
  final double horizontalPosition;
  final String fontFamily;
  final bool showOrpHighlight;
  final bool smartTiming;
  final bool rampUp;
  final bool showFocusLine;
  final bool focusLineShowsProgress;
  final OrpIndicatorStyle orpIndicator;
  final bool showProgressSlider;
  final TimeRemainingMode timeRemainingMode;

  const DisplaySettings({
    this.wpm = AppConstants.defaultWpm,
    this.fontSize = AppConstants.defaultFontSize,
    this.contextFontSize = AppConstants.defaultContextFontSize,
    this.wordColorValue = AppConstants.defaultWordColor,
    this.orpColorValue = AppConstants.defaultOrpColor,
    this.backgroundColorValue = AppConstants.defaultBackgroundColor,
    this.highlightColorValue = AppConstants.defaultHighlightColor,
    this.verticalPosition = AppConstants.defaultVerticalPosition,
    this.horizontalPosition = 0.5,
    this.fontFamily = AppConstants.defaultFontFamily,
    this.showOrpHighlight = true,
    this.smartTiming = true,
    this.rampUp = true,
    this.showFocusLine = true,
    this.focusLineShowsProgress = true,
    this.orpIndicator = OrpIndicatorStyle.notch,
    this.showProgressSlider = true,
    this.timeRemainingMode = TimeRemainingMode.total,
  });

  Color get wordColor => Color(wordColorValue);
  Color get orpColor => Color(orpColorValue);
  Color get backgroundColor => Color(backgroundColorValue);
  Color get highlightColor => Color(highlightColorValue);

  DisplaySettings copyWith({
    int? wpm,
    double? fontSize,
    double? contextFontSize,
    int? wordColorValue,
    int? orpColorValue,
    int? backgroundColorValue,
    int? highlightColorValue,
    double? verticalPosition,
    double? horizontalPosition,
    String? fontFamily,
    bool? showOrpHighlight,
    bool? smartTiming,
    bool? rampUp,
    bool? showFocusLine,
    bool? focusLineShowsProgress,
    OrpIndicatorStyle? orpIndicator,
    bool? showProgressSlider,
    TimeRemainingMode? timeRemainingMode,
  }) {
    return DisplaySettings(
      wpm: wpm ?? this.wpm,
      fontSize: fontSize ?? this.fontSize,
      contextFontSize: contextFontSize ?? this.contextFontSize,
      wordColorValue: wordColorValue ?? this.wordColorValue,
      orpColorValue: orpColorValue ?? this.orpColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      highlightColorValue: highlightColorValue ?? this.highlightColorValue,
      verticalPosition: verticalPosition ?? this.verticalPosition,
      horizontalPosition: horizontalPosition ?? this.horizontalPosition,
      fontFamily: fontFamily ?? this.fontFamily,
      showOrpHighlight: showOrpHighlight ?? this.showOrpHighlight,
      smartTiming: smartTiming ?? this.smartTiming,
      rampUp: rampUp ?? this.rampUp,
      showFocusLine: showFocusLine ?? this.showFocusLine,
      focusLineShowsProgress:
          focusLineShowsProgress ?? this.focusLineShowsProgress,
      orpIndicator: orpIndicator ?? this.orpIndicator,
      showProgressSlider: showProgressSlider ?? this.showProgressSlider,
      timeRemainingMode: timeRemainingMode ?? this.timeRemainingMode,
    );
  }
}
