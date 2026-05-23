import '../../../domain/entities/rsvp_state.dart';

/// Logical groupings used to lay out the settings panel. Each category gets
/// its own section in the panel, with a header + a [SettingsScope] chip.
///
/// The enum order defines the **pedagogical fallback order** used in the
/// full-screen Settings page (no book / no active mode known). When a mode
/// is active (reader sheet / side panel), [orderedCategoriesFor] reshuffles
/// so the most-relevant category sits first.
///
/// This is a UI-only enum — never persisted. Reordering values here is safe.
enum SettingsCategory {
  /// `wpm`, `smartTiming`, `rampUp`, `sentencePauseMultiplier`,
  /// `chapterPauseMultiplier`.
  speedTiming,

  /// `showOrpHighlight`, `orpIndicator`, `showFocusLine`,
  /// `focusLineShowsProgress`, `fontSize`, `verticalPosition`,
  /// `horizontalPosition`, `wordColor`, `orpColor`.
  rsvpDisplay,

  /// `ttsEngineId`, `ttsVoiceName`, `ttsPitch`.
  audio,

  /// `contextFontSize`, `highlightColor`.
  readerView,

  /// `fontFamily`, `backgroundColor`.
  typography,

  /// `showProgressSlider`, `timeRemainingMode`.
  chrome,
}

/// Which reading modes a [SettingsCategory] applies to. Drives the badge
/// next to each section header so the user can tell at a glance whether
/// editing a setting will have any visible effect in their current mode.
enum SettingsScope {
  /// RSVP and (its paused half) scroll. The rest of the categories are
  /// dead-letter for the user when the reader is in another mode.
  rsvpOnly,

  /// TTS-only.
  audioOnly,

  /// scroll / ereader / TTS — the three "flowing text" modes. The font
  /// size + highlight color of the context view live here.
  readerModes,

  /// Affects everything (RSVP word and the flowing-text modes).
  allModes,

  /// Modes that host the [RsvpControls] transport dock — RSVP, scroll, and
  /// TTS. E-reader intentionally hides the dock (a "naked" reading mode),
  /// so the settings that only live inside the dock (progress slider,
  /// time-remaining badge) are inert there even though they're technically
  /// available to edit.
  controlsModes,
}

extension SettingsCategoryScope on SettingsCategory {
  SettingsScope get scope {
    switch (this) {
      case SettingsCategory.speedTiming:
      case SettingsCategory.rsvpDisplay:
        return SettingsScope.rsvpOnly;
      case SettingsCategory.audio:
        return SettingsScope.audioOnly;
      case SettingsCategory.readerView:
        return SettingsScope.readerModes;
      case SettingsCategory.typography:
        return SettingsScope.allModes;
      case SettingsCategory.chrome:
        return SettingsScope.controlsModes;
    }
  }
}

/// Returns the categories in the order the panel should render them for a
/// given [mode]. The category that "owns" the active mode floats to the top;
/// the rest follows in [SettingsCategory] enum order.
///
/// When [mode] is `null` (full-screen Settings page, no book open), returns
/// the pedagogical default order — Typography → RSVP → Reader → Audio →
/// Chrome — which mirrors a top-down "appearance first, behaviour second"
/// reading order.
List<SettingsCategory> orderedCategoriesFor(ReaderMode? mode) {
  if (mode == null) {
    return const [
      SettingsCategory.typography,
      SettingsCategory.speedTiming,
      SettingsCategory.rsvpDisplay,
      SettingsCategory.readerView,
      SettingsCategory.audio,
      SettingsCategory.chrome,
    ];
  }

  switch (mode) {
    case ReaderMode.rsvp:
    case ReaderMode.scroll:
      return const [
        SettingsCategory.speedTiming,
        SettingsCategory.rsvpDisplay,
        SettingsCategory.readerView,
        SettingsCategory.typography,
        SettingsCategory.chrome,
        SettingsCategory.audio,
      ];
    case ReaderMode.ereader:
      return const [
        SettingsCategory.readerView,
        SettingsCategory.typography,
        SettingsCategory.chrome,
        SettingsCategory.speedTiming,
        SettingsCategory.rsvpDisplay,
        SettingsCategory.audio,
      ];
    case ReaderMode.tts:
      return const [
        SettingsCategory.audio,
        SettingsCategory.readerView,
        SettingsCategory.typography,
        SettingsCategory.chrome,
        SettingsCategory.speedTiming,
        SettingsCategory.rsvpDisplay,
      ];
  }
}

/// `true` when the category has visible effect in [mode] — i.e. when its
/// [SettingsScope] covers that mode. Used by the panel to render the
/// "active" chip style on the relevant section header.
///
/// When [mode] is null (full-screen page) every category renders in its
/// neutral style — there is no "active mode" to highlight.
bool isCategoryActiveFor(SettingsCategory category, ReaderMode? mode) {
  if (mode == null) return false;
  // RSVP and scroll are the same user-facing mode (scroll == "RSVP paused"),
  // so collapse them before checking scope membership. Without this, pausing
  // RSVP playback would un-highlight `rsvpDisplay`'s chip — a misleading
  // signal to the user.
  final effective = mode == ReaderMode.scroll ? ReaderMode.rsvp : mode;
  switch (category.scope) {
    case SettingsScope.rsvpOnly:
      return effective == ReaderMode.rsvp;
    case SettingsScope.audioOnly:
      return effective == ReaderMode.tts;
    case SettingsScope.readerModes:
      // contextFontSize + highlightColor render in the context-scroll view,
      // which the RSVP mode also surfaces when paused — so include RSVP.
      return effective == ReaderMode.rsvp ||
          effective == ReaderMode.ereader ||
          effective == ReaderMode.tts;
    case SettingsScope.allModes:
      return true;
    case SettingsScope.controlsModes:
      // E-reader hides the controls dock entirely, so chrome settings have
      // no visible effect there even though they're set in the panel.
      return effective != ReaderMode.ereader;
  }
}
