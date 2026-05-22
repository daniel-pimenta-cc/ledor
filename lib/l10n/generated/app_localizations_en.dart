// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RSVP Reader';

  @override
  String get library => 'Library';

  @override
  String get settings => 'Settings';

  @override
  String get importBook => 'Import Book';

  @override
  String get emptyLibrary => 'Your library is empty';

  @override
  String get emptyLibrarySubtitle => 'Import an EPUB to get started';

  @override
  String get deleteBook => 'Delete Book';

  @override
  String deleteBookConfirm(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get viewCompletion => 'View completion';

  @override
  String get finishBook => 'Finish book';

  @override
  String get finishBookConfirmTitle => 'Finish this book?';

  @override
  String get finishBookConfirmBody =>
      'We\'ll jump your progress to the end and open the completion screen so you can rate it.';

  @override
  String get finishBookConfirmCta => 'Finish';

  @override
  String markedAsRead(String title) {
    return 'Marked \"$title\" as read';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get reading => 'Reading';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String wordsPerMinute(int wpm) {
    return '$wpm WPM';
  }

  @override
  String chapterOf(int current, int total) {
    return 'Chapter $current of $total';
  }

  @override
  String progressPercent(int percent) {
    return '$percent%';
  }

  @override
  String minutesRemaining(int minutes) {
    return '~$minutes min';
  }

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsFontSize => 'Font Size';

  @override
  String get settingsFontSizeRsvp => 'RSVP Font Size';

  @override
  String get settingsFontSizeContext => 'Reader Font Size';

  @override
  String get settingsWordColor => 'Word Color';

  @override
  String get settingsOrpColor => 'Focus Letter Color';

  @override
  String get settingsBackgroundColor => 'Background Color';

  @override
  String get settingsHighlightColor => 'Highlight Color';

  @override
  String get settingsVerticalPosition => 'Vertical Position';

  @override
  String get settingsHorizontalPosition => 'Horizontal Position';

  @override
  String get settingsFont => 'Font';

  @override
  String get settingsReading => 'Reading';

  @override
  String get settingsDefaultSpeed => 'Default Speed';

  @override
  String get settingsSmartTiming => 'Smart Timing';

  @override
  String get settingsSmartTimingDesc =>
      'Adjust word duration based on punctuation and length';

  @override
  String get settingsOrpHighlight => 'Focus Letter';

  @override
  String get settingsOrpHighlightDesc =>
      'Highlight the optimal recognition point in each word';

  @override
  String get settingsRampUp => 'Speed Ramp-Up';

  @override
  String get settingsRampUpDesc =>
      'Gradually accelerate to target speed when starting playback';

  @override
  String get settingsSentencePause => 'Sentence pause';

  @override
  String get settingsSentencePauseDesc =>
      'Extra pause at the end of each sentence';

  @override
  String get settingsChapterPause => 'Chapter pause';

  @override
  String get settingsChapterPauseDesc =>
      'Extra pause before each new chapter begins';

  @override
  String multiplierValue(String value) {
    return '${value}x';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get readerPlaceholderTitle => 'Pick a book to begin';

  @override
  String get readerPlaceholderSubtitle =>
      'Select from your library on the left and it\'ll open right here.';

  @override
  String get importArticleClipboardHint => 'Pasted from your clipboard';

  @override
  String get importing => 'Importing...';

  @override
  String get importError => 'Failed to import book';

  @override
  String get importArticle => 'Import article';

  @override
  String get importArticleUrlLabel => 'Article URL';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importArticleCta => 'Import';

  @override
  String get importArticleError => 'Failed to import article';

  @override
  String get importArticleFetching => 'Fetching article…';

  @override
  String get libraryTabBooks => 'Books';

  @override
  String get libraryTabArticles => 'Articles';

  @override
  String get emptyArticles => 'No articles yet';

  @override
  String get emptyArticlesSubtitle =>
      'Paste a URL to read any web article in RSVP';

  @override
  String get bookFinished => 'You finished the book!';

  @override
  String get tapToPause => 'Tap to pause';

  @override
  String get tapToResume => 'Tap to resume';

  @override
  String get readerModeMenuTooltip => 'Reading mode';

  @override
  String get readerModeRsvp => 'RSVP';

  @override
  String get readerModeEreader => 'E-reader';

  @override
  String get readerModeTts => 'Text-to-speech';

  @override
  String get lockHighlight => 'Lock focused word';

  @override
  String get unlockHighlight => 'Unlock focused word';

  @override
  String get recenterHighlight => 'Back to focused word';

  @override
  String get hideLibraryPanel => 'Hide library';

  @override
  String get showLibraryPanel => 'Show library';

  @override
  String get settingsProgressSlider => 'Progress slider';

  @override
  String get settingsProgressSliderDesc =>
      'Show the seek bar with chapter markers above the playback controls';

  @override
  String get settingsTimeRemaining => 'Time remaining';

  @override
  String get settingsTimeRemainingDesc =>
      'How to display the time remaining next to the chapter title';

  @override
  String get timeRemainingTotal => 'Whole book';

  @override
  String get timeRemainingChapter => 'Current chapter';

  @override
  String get timeRemainingOff => 'Off';

  @override
  String get settingsFocusLine => 'Focus line';

  @override
  String get settingsFocusLineDesc =>
      'Show a thin line below the word to anchor your gaze';

  @override
  String get settingsFocusLineProgress => 'Progress on focus line';

  @override
  String get settingsFocusLineProgressDesc =>
      'Use the focus line to also display reading progress';

  @override
  String get settingsOrpIndicator => 'Focus letter marker';

  @override
  String get settingsOrpIndicatorDesc =>
      'Choose how the focus letter is pointed at';

  @override
  String get orpIndicatorNotch => 'Notch';

  @override
  String get orpIndicatorLineAbove => 'Line above';

  @override
  String get orpIndicatorLinesAround => 'Lines around';

  @override
  String get orpIndicatorOff => 'Off';

  @override
  String get librarySectionInProgress => 'In progress';

  @override
  String get librarySectionNotStarted => 'Not started';

  @override
  String get librarySectionRead => 'Read';

  @override
  String get settingsSync => 'Library sync';

  @override
  String get syncConnectDrive => 'Connect Google Drive';

  @override
  String get syncConnectingDrive => 'Connecting…';

  @override
  String syncConnectedAs(String email) {
    return 'Connected as $email';
  }

  @override
  String get syncEpubFiles => 'Sync EPUB files';

  @override
  String get syncEpubFilesDesc =>
      'Copy EPUB files to Drive so they appear on other devices. Turn off to save cloud space.';

  @override
  String get syncAutoSync => 'Auto sync';

  @override
  String get syncAutoSyncDesc =>
      'Sync automatically when you open the app and when progress changes.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncInProgress => 'Syncing…';

  @override
  String syncLastSyncedAt(String when) {
    return 'Last synced: $when';
  }

  @override
  String get syncNever => 'Never';

  @override
  String syncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get syncDisconnect => 'Disconnect';

  @override
  String syncFailedImportsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files failed to import',
      one: '1 file failed to import',
    );
    return '$_temp0';
  }

  @override
  String get syncFailedImportsHelp =>
      'These files are being skipped. Delete or replace them in the sync folder, then tap Retry.';

  @override
  String get syncRetry => 'Retry';

  @override
  String syncImportingProgress(int current, int total, String fileName) {
    return 'Importing $current of $total: $fileName';
  }

  @override
  String get syncHelp =>
      'Your library metadata, reading progress and settings sync through a folder the app creates in your Google Drive (\"RSVP Reader\"). Sign in to connect an account; signing out on this device keeps the Drive files intact.';

  @override
  String get statsTitle => 'Reading stats';

  @override
  String get statsTabWeekly => 'Last 7 days';

  @override
  String get statsTabMonthly => 'Last 30 days';

  @override
  String get statsSummaryWordsRead => 'Words read';

  @override
  String get statsSummaryTimeSpent => 'Time';

  @override
  String get statsSummaryAvgWpm => 'Avg WPM';

  @override
  String get statsSummaryBooksTouched => 'Books';

  @override
  String get statsChartWordsPerDay => 'Words per day';

  @override
  String get statsChartTimePerDay => 'Time per day';

  @override
  String get statsChartWpmTrend => 'WPM trend';

  @override
  String get statsBookBreakdownTitle => 'By book';

  @override
  String statsBookBreakdownEntry(int minutes, int sessions) {
    String _temp0 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions sessions',
      one: '1 session',
    );
    return '$minutes min • $_temp0';
  }

  @override
  String get statsEmptyTitle => 'No reading yet';

  @override
  String get statsEmptySubtitle =>
      'Start an RSVP session to see your stats here.';

  @override
  String statsDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String statsDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get statsOtherBooks => 'Other';

  @override
  String get recapTitle => 'Monthly recap';

  @override
  String get recapGenerateCta => 'Share this month\'s recap';

  @override
  String get recapShareCta => 'Share';

  @override
  String get recapEmptyMonth =>
      'No reading this month yet — come back after an RSVP session.';

  @override
  String get recapFinished => 'Finished';

  @override
  String get recapReading => 'Reading';

  @override
  String recapStatsFooter(String words, int hours, int minutes) {
    return '$words words read • ${hours}h ${minutes}m';
  }

  @override
  String get recapWordmark => 'RSVP Reader';

  @override
  String recapMonthHeadline(String month, int year) {
    return '$month $year';
  }

  @override
  String recapShareText(String month) {
    return 'My $month reading recap from RSVP Reader.';
  }

  @override
  String recapBookProgress(int percent) {
    return '$percent% read';
  }

  @override
  String get completionHeadline => 'You finished';

  @override
  String get completionShareCta => 'Share';

  @override
  String get completionRatingLabel => 'Your rating';

  @override
  String get completionRatingHint => 'Tap a star to rate this book';

  @override
  String get completionStatTime => 'Reading time';

  @override
  String get completionStatWords => 'Words read';

  @override
  String get completionStatSessions => 'Sessions';

  @override
  String get completionStatAvgWpm => 'Average WPM';

  @override
  String completionStatSpan(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Finished over $_temp0';
  }

  @override
  String get completionCardHeadline => 'Finished!';

  @override
  String completionCardFooter(int hours, int minutes, int sessions) {
    String _temp0 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions sessions',
      one: '1 session',
    );
    return '${hours}h ${minutes}m • $_temp0';
  }

  @override
  String completionShareText(String title) {
    return 'I just finished \"$title\" on RSVP Reader.';
  }

  @override
  String get completionIncludeStats => 'Include stats in image';

  @override
  String completionFinishedOn(String date) {
    return 'Finished $date';
  }

  @override
  String get imageContinue => 'Continue';

  @override
  String get imageClose => 'Close';

  @override
  String get imageMissing => 'Image unavailable';

  @override
  String get settingsTtsSection => 'Text-to-speech';

  @override
  String get settingsTtsVoice => 'Voice';

  @override
  String get settingsTtsVoiceDesc =>
      'Pick the synthesis voice used in TTS mode';

  @override
  String get settingsTtsLanguage => 'Language';

  @override
  String get settingsTtsLanguageDesc => 'Locale the TTS engine speaks';

  @override
  String get settingsTtsPitch => 'Pitch';

  @override
  String get settingsTtsPitchDesc =>
      'Voice pitch — lower sounds deeper, higher sounds brighter';

  @override
  String get ttsVoicePickerTitle => 'Choose a voice';

  @override
  String get ttsVoicePreviewSample =>
      'The quick brown fox jumps over the lazy dog.';

  @override
  String get ttsVoicePreviewTooltip => 'Preview this voice';

  @override
  String get ttsVoiceCurrent => 'Selected';

  @override
  String get ttsNoVoicesAvailable => 'No voices available on this device';

  @override
  String get ttsLinuxRequiresSpeechDispatcher =>
      'Install speech-dispatcher to enable TTS on Linux (e.g. `sudo apt install speech-dispatcher`)';

  @override
  String get ttsFirstUseHint => 'Tap play to start narration';

  @override
  String ttsErrorPrefix(String error) {
    return 'TTS error: $error';
  }

  @override
  String ttsVoiceFallbackLabel(String locale) {
    return 'Default for $locale';
  }

  @override
  String get settingsTtsEngine => 'Engine';

  @override
  String get settingsTtsEngineDesc => 'TTS engine used to synthesise speech';

  @override
  String get ttsEnginePickerTitle => 'Choose an engine';

  @override
  String get ttsEnginePickerSubtitle =>
      'Different engines produce different voices and sound quality';

  @override
  String get ttsEnginePickerEmpty => 'No alternative engines installed';

  @override
  String get ttsEnginePickerSystemDefault => 'System default';
}
