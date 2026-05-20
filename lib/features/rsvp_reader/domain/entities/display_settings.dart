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

  /// Extra pause applied at the end of a sentence (`.`, `!`, `?`, `…`).
  /// Multiplied on top of [WordToken.timingMultiplier]. Default `1.0` keeps
  /// the existing baked-in behaviour; values above add a structural beat.
  ///
  /// RSVP-only. The TTS engine has its own natural prosody.
  final double sentencePauseMultiplier;

  /// Extra pause applied to the word right before a new chapter starts so
  /// the gap lands at the seam, not after the chapter title shows up.
  /// Multiplied on top of [WordToken.timingMultiplier]. Default `1.0`.
  ///
  /// RSVP-only.
  final double chapterPauseMultiplier;

  /// BCP-47 / ISO language code used by the TTS backend (`en-US`, `pt-BR`,
  /// …). Determines which voices the picker can pre-filter and which engine
  /// locale `flutter_tts` / `spd-say` will request.
  final String ttsLanguage;

  /// Name of the synthesis voice selected by the user. `null` means "use the
  /// first voice the backend reports for [ttsLanguage]". On sync this may
  /// arrive set to a voice that doesn't exist on the local device — the
  /// engine falls back gracefully but the value is preserved so a round-trip
  /// to the original device restores the original selection.
  final String? ttsVoiceName;

  /// Voice pitch passed to the TTS engine. Range `[0.5, 2.0]`, default `1.0`.
  /// `flutter_tts` accepts this range directly; the Linux backend maps it to
  /// `spd-say -p <-100..+100>`.
  final double ttsPitch;

  /// Speech rate multiplier for the TTS engine, expressed as the natural
  /// "1.0x / 1.25x / 1.5x …" scale users expect from audiobook players.
  /// Backends translate this to their native units (`flutter_tts.setSpeechRate`
  /// takes it as-is; the Linux backend maps it to `spd-say -r`).
  /// Range `[0.5, 3.0]`, default `1.0`.
  final double ttsRate;

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
    this.sentencePauseMultiplier = 1.0,
    this.chapterPauseMultiplier = 1.0,
    this.ttsLanguage = 'en-US',
    this.ttsVoiceName,
    this.ttsPitch = 1.0,
    this.ttsRate = AppConstants.defaultTtsRate,
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
    double? sentencePauseMultiplier,
    double? chapterPauseMultiplier,
    String? ttsLanguage,
    Object? ttsVoiceName = _unset,
    double? ttsPitch,
    double? ttsRate,
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
      sentencePauseMultiplier:
          sentencePauseMultiplier ?? this.sentencePauseMultiplier,
      chapterPauseMultiplier:
          chapterPauseMultiplier ?? this.chapterPauseMultiplier,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      ttsVoiceName: identical(ttsVoiceName, _unset)
          ? this.ttsVoiceName
          : ttsVoiceName as String?,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsRate: ttsRate ?? this.ttsRate,
    );
  }
}

/// Sentinel used by [DisplaySettings.copyWith] to distinguish "argument not
/// supplied" from "explicitly set to null" for [DisplaySettings.ttsVoiceName].
/// Required because clearing the voice (reverting to "first voice of locale")
/// is a meaningful state.
const Object _unset = Object();
