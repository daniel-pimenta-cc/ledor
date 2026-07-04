import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledor'**
  String get appTitle;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @importBook.
  ///
  /// In en, this message translates to:
  /// **'Import Book'**
  String get importBook;

  /// No description provided for @emptyLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get emptyLibrary;

  /// No description provided for @emptyLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import an EPUB to get started'**
  String get emptyLibrarySubtitle;

  /// No description provided for @deleteBook.
  ///
  /// In en, this message translates to:
  /// **'Delete Book'**
  String get deleteBook;

  /// No description provided for @deleteBookConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String deleteBookConfirm(String title);

  /// No description provided for @markAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get markAsRead;

  /// No description provided for @viewCompletion.
  ///
  /// In en, this message translates to:
  /// **'View completion'**
  String get viewCompletion;

  /// No description provided for @finishBook.
  ///
  /// In en, this message translates to:
  /// **'Finish book'**
  String get finishBook;

  /// No description provided for @finishBookConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish this book?'**
  String get finishBookConfirmTitle;

  /// No description provided for @finishBookConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll jump your progress to the end and open the completion screen so you can rate it.'**
  String get finishBookConfirmBody;

  /// No description provided for @finishBookConfirmCta.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishBookConfirmCta;

  /// No description provided for @markedAsRead.
  ///
  /// In en, this message translates to:
  /// **'Marked \"{title}\" as read'**
  String markedAsRead(String title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @wordsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'{wpm} WPM'**
  String wordsPerMinute(int wpm);

  /// No description provided for @chapterOf.
  ///
  /// In en, this message translates to:
  /// **'Chapter {current} of {total}'**
  String chapterOf(int current, int total);

  /// No description provided for @progressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String progressPercent(int percent);

  /// No description provided for @minutesRemaining.
  ///
  /// In en, this message translates to:
  /// **'~{minutes} min'**
  String minutesRemaining(int minutes);

  /// No description provided for @settingsFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get settingsFontSize;

  /// No description provided for @settingsFontSizeRsvp.
  ///
  /// In en, this message translates to:
  /// **'RSVP Font Size'**
  String get settingsFontSizeRsvp;

  /// No description provided for @settingsFontSizeContext.
  ///
  /// In en, this message translates to:
  /// **'Reader Font Size'**
  String get settingsFontSizeContext;

  /// No description provided for @settingsWordColor.
  ///
  /// In en, this message translates to:
  /// **'Word Color'**
  String get settingsWordColor;

  /// No description provided for @settingsOrpColor.
  ///
  /// In en, this message translates to:
  /// **'Focus Letter Color'**
  String get settingsOrpColor;

  /// No description provided for @settingsBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background Color'**
  String get settingsBackgroundColor;

  /// No description provided for @settingsHighlightColor.
  ///
  /// In en, this message translates to:
  /// **'Highlight Color'**
  String get settingsHighlightColor;

  /// No description provided for @settingsVerticalPosition.
  ///
  /// In en, this message translates to:
  /// **'Vertical Position'**
  String get settingsVerticalPosition;

  /// No description provided for @settingsHorizontalPosition.
  ///
  /// In en, this message translates to:
  /// **'Horizontal Position'**
  String get settingsHorizontalPosition;

  /// No description provided for @settingsFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get settingsFont;

  /// No description provided for @settingsDefaultSpeed.
  ///
  /// In en, this message translates to:
  /// **'Default Speed'**
  String get settingsDefaultSpeed;

  /// No description provided for @settingsSmartTiming.
  ///
  /// In en, this message translates to:
  /// **'Smart Timing'**
  String get settingsSmartTiming;

  /// No description provided for @settingsSmartTimingDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust word duration based on punctuation and length'**
  String get settingsSmartTimingDesc;

  /// No description provided for @settingsOrpHighlight.
  ///
  /// In en, this message translates to:
  /// **'Focus Letter'**
  String get settingsOrpHighlight;

  /// No description provided for @settingsOrpHighlightDesc.
  ///
  /// In en, this message translates to:
  /// **'Highlight the optimal recognition point in each word'**
  String get settingsOrpHighlightDesc;

  /// No description provided for @settingsRampUp.
  ///
  /// In en, this message translates to:
  /// **'Speed Ramp-Up'**
  String get settingsRampUp;

  /// No description provided for @settingsRampUpDesc.
  ///
  /// In en, this message translates to:
  /// **'Gradually accelerate to target speed when starting playback'**
  String get settingsRampUpDesc;

  /// No description provided for @settingsSentencePause.
  ///
  /// In en, this message translates to:
  /// **'Sentence pause'**
  String get settingsSentencePause;

  /// No description provided for @settingsSentencePauseDesc.
  ///
  /// In en, this message translates to:
  /// **'Extra pause at the end of each sentence'**
  String get settingsSentencePauseDesc;

  /// No description provided for @settingsChapterPause.
  ///
  /// In en, this message translates to:
  /// **'Chapter pause'**
  String get settingsChapterPause;

  /// No description provided for @settingsChapterPauseDesc.
  ///
  /// In en, this message translates to:
  /// **'Extra pause before each new chapter begins'**
  String get settingsChapterPauseDesc;

  /// No description provided for @multiplierValue.
  ///
  /// In en, this message translates to:
  /// **'{value}x'**
  String multiplierValue(String value);

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @readerPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a book to begin'**
  String get readerPlaceholderTitle;

  /// No description provided for @readerPlaceholderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select from your library on the left and it\'ll open right here.'**
  String get readerPlaceholderSubtitle;

  /// No description provided for @importArticleClipboardHint.
  ///
  /// In en, this message translates to:
  /// **'Pasted from your clipboard'**
  String get importArticleClipboardHint;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get importing;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Failed to import book'**
  String get importError;

  /// No description provided for @importArticle.
  ///
  /// In en, this message translates to:
  /// **'Import article'**
  String get importArticle;

  /// No description provided for @importArticleUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Article URL'**
  String get importArticleUrlLabel;

  /// No description provided for @importArticleUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/article'**
  String get importArticleUrlHint;

  /// No description provided for @importArticleCta.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importArticleCta;

  /// No description provided for @importArticleError.
  ///
  /// In en, this message translates to:
  /// **'Failed to import article'**
  String get importArticleError;

  /// No description provided for @importArticleFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching article…'**
  String get importArticleFetching;

  /// No description provided for @libraryTabBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get libraryTabBooks;

  /// No description provided for @libraryTabArticles.
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get libraryTabArticles;

  /// No description provided for @emptyArticles.
  ///
  /// In en, this message translates to:
  /// **'No articles yet'**
  String get emptyArticles;

  /// No description provided for @emptyArticlesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a URL to read any web article in RSVP'**
  String get emptyArticlesSubtitle;

  /// No description provided for @bookFinished.
  ///
  /// In en, this message translates to:
  /// **'You finished the book!'**
  String get bookFinished;

  /// No description provided for @tapToPause.
  ///
  /// In en, this message translates to:
  /// **'Tap to pause'**
  String get tapToPause;

  /// No description provided for @tapToResume.
  ///
  /// In en, this message translates to:
  /// **'Tap to resume'**
  String get tapToResume;

  /// No description provided for @readerModeMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readerModeMenuTooltip;

  /// No description provided for @readerModeRsvp.
  ///
  /// In en, this message translates to:
  /// **'RSVP'**
  String get readerModeRsvp;

  /// No description provided for @readerModeEreader.
  ///
  /// In en, this message translates to:
  /// **'E-reader'**
  String get readerModeEreader;

  /// No description provided for @readerModeTts.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech'**
  String get readerModeTts;

  /// No description provided for @lockHighlight.
  ///
  /// In en, this message translates to:
  /// **'Lock focused word'**
  String get lockHighlight;

  /// No description provided for @unlockHighlight.
  ///
  /// In en, this message translates to:
  /// **'Unlock focused word'**
  String get unlockHighlight;

  /// No description provided for @recenterHighlight.
  ///
  /// In en, this message translates to:
  /// **'Back to focused word'**
  String get recenterHighlight;

  /// No description provided for @hideLibraryPanel.
  ///
  /// In en, this message translates to:
  /// **'Hide library'**
  String get hideLibraryPanel;

  /// No description provided for @showLibraryPanel.
  ///
  /// In en, this message translates to:
  /// **'Show library'**
  String get showLibraryPanel;

  /// No description provided for @settingsProgressSlider.
  ///
  /// In en, this message translates to:
  /// **'Progress slider'**
  String get settingsProgressSlider;

  /// No description provided for @settingsProgressSliderDesc.
  ///
  /// In en, this message translates to:
  /// **'Show the seek bar with chapter markers above the playback controls'**
  String get settingsProgressSliderDesc;

  /// No description provided for @settingsTimeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Time remaining'**
  String get settingsTimeRemaining;

  /// No description provided for @settingsTimeRemainingDesc.
  ///
  /// In en, this message translates to:
  /// **'How to display the time remaining next to the chapter title'**
  String get settingsTimeRemainingDesc;

  /// No description provided for @timeRemainingTotal.
  ///
  /// In en, this message translates to:
  /// **'Whole book'**
  String get timeRemainingTotal;

  /// No description provided for @timeRemainingChapter.
  ///
  /// In en, this message translates to:
  /// **'Current chapter'**
  String get timeRemainingChapter;

  /// No description provided for @timeRemainingOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get timeRemainingOff;

  /// No description provided for @settingsFocusLine.
  ///
  /// In en, this message translates to:
  /// **'Focus line'**
  String get settingsFocusLine;

  /// No description provided for @settingsFocusLineDesc.
  ///
  /// In en, this message translates to:
  /// **'Show a thin line below the word to anchor your gaze'**
  String get settingsFocusLineDesc;

  /// No description provided for @settingsFocusLineProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress on focus line'**
  String get settingsFocusLineProgress;

  /// No description provided for @settingsFocusLineProgressDesc.
  ///
  /// In en, this message translates to:
  /// **'Use the focus line to also display reading progress'**
  String get settingsFocusLineProgressDesc;

  /// No description provided for @settingsOrpIndicator.
  ///
  /// In en, this message translates to:
  /// **'Focus letter marker'**
  String get settingsOrpIndicator;

  /// No description provided for @settingsOrpIndicatorDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose how the focus letter is pointed at'**
  String get settingsOrpIndicatorDesc;

  /// No description provided for @orpIndicatorNotch.
  ///
  /// In en, this message translates to:
  /// **'Notch'**
  String get orpIndicatorNotch;

  /// No description provided for @orpIndicatorLineAbove.
  ///
  /// In en, this message translates to:
  /// **'Line above'**
  String get orpIndicatorLineAbove;

  /// No description provided for @orpIndicatorLinesAround.
  ///
  /// In en, this message translates to:
  /// **'Lines around'**
  String get orpIndicatorLinesAround;

  /// No description provided for @orpIndicatorOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get orpIndicatorOff;

  /// No description provided for @librarySectionInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get librarySectionInProgress;

  /// No description provided for @librarySectionNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get librarySectionNotStarted;

  /// No description provided for @librarySectionRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get librarySectionRead;

  /// No description provided for @settingsSync.
  ///
  /// In en, this message translates to:
  /// **'Library sync'**
  String get settingsSync;

  /// No description provided for @syncConnectDrive.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive'**
  String get syncConnectDrive;

  /// No description provided for @syncConnectingDrive.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get syncConnectingDrive;

  /// No description provided for @syncConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as {email}'**
  String syncConnectedAs(String email);

  /// No description provided for @syncEpubFiles.
  ///
  /// In en, this message translates to:
  /// **'Sync EPUB files'**
  String get syncEpubFiles;

  /// No description provided for @syncEpubFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Copy EPUB files to Drive so they appear on other devices. Turn off to save cloud space.'**
  String get syncEpubFilesDesc;

  /// No description provided for @syncAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto sync'**
  String get syncAutoSync;

  /// No description provided for @syncAutoSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync automatically when you open the app and when progress changes.'**
  String get syncAutoSyncDesc;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncInProgress;

  /// No description provided for @syncLastSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {when}'**
  String syncLastSyncedAt(String when);

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get syncNever;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailed(String error);

  /// No description provided for @syncDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get syncDisconnect;

  /// No description provided for @syncFailedImportsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 file failed to import} other{{count} files failed to import}}'**
  String syncFailedImportsTitle(int count);

  /// No description provided for @syncFailedImportsHelp.
  ///
  /// In en, this message translates to:
  /// **'These files are being skipped. Delete or replace them in the sync folder, then tap Retry.'**
  String get syncFailedImportsHelp;

  /// No description provided for @syncRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get syncRetry;

  /// No description provided for @syncImportingProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing {current} of {total}: {fileName}'**
  String syncImportingProgress(int current, int total, String fileName);

  /// No description provided for @syncHelp.
  ///
  /// In en, this message translates to:
  /// **'Your library metadata, reading progress and settings sync through a folder the app creates in your Google Drive (\"RSVP Reader\"). Sign in to connect an account; signing out on this device keeps the Drive files intact.'**
  String get syncHelp;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading stats'**
  String get statsTitle;

  /// No description provided for @statsTabWeekly.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get statsTabWeekly;

  /// No description provided for @statsTabMonthly.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get statsTabMonthly;

  /// No description provided for @statsSummaryWordsRead.
  ///
  /// In en, this message translates to:
  /// **'Words read'**
  String get statsSummaryWordsRead;

  /// No description provided for @statsSummaryTimeSpent.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get statsSummaryTimeSpent;

  /// No description provided for @statsSummaryAvgWpm.
  ///
  /// In en, this message translates to:
  /// **'Avg WPM'**
  String get statsSummaryAvgWpm;

  /// No description provided for @statsSummaryBooksTouched.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get statsSummaryBooksTouched;

  /// No description provided for @statsChartWordsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Words per day'**
  String get statsChartWordsPerDay;

  /// No description provided for @statsChartTimePerDay.
  ///
  /// In en, this message translates to:
  /// **'Time per day'**
  String get statsChartTimePerDay;

  /// No description provided for @statsChartWpmTrend.
  ///
  /// In en, this message translates to:
  /// **'WPM trend'**
  String get statsChartWpmTrend;

  /// No description provided for @statsBookBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'By book'**
  String get statsBookBreakdownTitle;

  /// No description provided for @statsBookBreakdownEntry.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min • {sessions, plural, one{1 session} other{{sessions} sessions}}'**
  String statsBookBreakdownEntry(int minutes, int sessions);

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reading yet'**
  String get statsEmptyTitle;

  /// No description provided for @statsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start an RSVP session to see your stats here.'**
  String get statsEmptySubtitle;

  /// No description provided for @statsDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String statsDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @statsDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String statsDurationMinutes(int minutes);

  /// No description provided for @statsOtherBooks.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get statsOtherBooks;

  /// No description provided for @recapTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly recap'**
  String get recapTitle;

  /// No description provided for @recapGenerateCta.
  ///
  /// In en, this message translates to:
  /// **'Share this month\'s recap'**
  String get recapGenerateCta;

  /// No description provided for @recapShareCta.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get recapShareCta;

  /// No description provided for @recapEmptyMonth.
  ///
  /// In en, this message translates to:
  /// **'No reading this month yet — come back after an RSVP session.'**
  String get recapEmptyMonth;

  /// No description provided for @recapFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get recapFinished;

  /// No description provided for @recapReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get recapReading;

  /// No description provided for @recapStatsFooter.
  ///
  /// In en, this message translates to:
  /// **'{words} words read • {hours}h {minutes}m'**
  String recapStatsFooter(String words, int hours, int minutes);

  /// No description provided for @recapWordmark.
  ///
  /// In en, this message translates to:
  /// **'Ledor'**
  String get recapWordmark;

  /// No description provided for @recapMonthHeadline.
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String recapMonthHeadline(String month, int year);

  /// No description provided for @recapShareText.
  ///
  /// In en, this message translates to:
  /// **'My {month} reading recap from Ledor.'**
  String recapShareText(String month);

  /// No description provided for @recapBookProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent}% read'**
  String recapBookProgress(int percent);

  /// No description provided for @completionHeadline.
  ///
  /// In en, this message translates to:
  /// **'You finished'**
  String get completionHeadline;

  /// No description provided for @completionShareCta.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get completionShareCta;

  /// No description provided for @completionRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get completionRatingLabel;

  /// No description provided for @completionRatingHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate this book'**
  String get completionRatingHint;

  /// No description provided for @completionStatTime.
  ///
  /// In en, this message translates to:
  /// **'Reading time'**
  String get completionStatTime;

  /// No description provided for @completionStatWords.
  ///
  /// In en, this message translates to:
  /// **'Words read'**
  String get completionStatWords;

  /// No description provided for @completionStatSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get completionStatSessions;

  /// No description provided for @completionStatAvgWpm.
  ///
  /// In en, this message translates to:
  /// **'Average WPM'**
  String get completionStatAvgWpm;

  /// No description provided for @completionStatSpan.
  ///
  /// In en, this message translates to:
  /// **'Finished over {days, plural, one{1 day} other{{days} days}}'**
  String completionStatSpan(int days);

  /// No description provided for @completionCardHeadline.
  ///
  /// In en, this message translates to:
  /// **'Finished!'**
  String get completionCardHeadline;

  /// No description provided for @completionCardFooter.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m • {sessions, plural, one{1 session} other{{sessions} sessions}}'**
  String completionCardFooter(int hours, int minutes, int sessions);

  /// No description provided for @completionShareText.
  ///
  /// In en, this message translates to:
  /// **'I just finished \"{title}\" on Ledor.'**
  String completionShareText(String title);

  /// No description provided for @completionIncludeStats.
  ///
  /// In en, this message translates to:
  /// **'Include stats in image'**
  String get completionIncludeStats;

  /// No description provided for @completionFinishedOn.
  ///
  /// In en, this message translates to:
  /// **'Finished {date}'**
  String completionFinishedOn(String date);

  /// No description provided for @imageContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get imageContinue;

  /// No description provided for @imageClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get imageClose;

  /// No description provided for @imageMissing.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get imageMissing;

  /// No description provided for @settingsTtsVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get settingsTtsVoice;

  /// No description provided for @settingsTtsVoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick the synthesis voice used in TTS mode'**
  String get settingsTtsVoiceDesc;

  /// No description provided for @settingsTtsPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get settingsTtsPitch;

  /// No description provided for @settingsTtsPitchDesc.
  ///
  /// In en, this message translates to:
  /// **'Voice pitch — lower sounds deeper, higher sounds brighter'**
  String get settingsTtsPitchDesc;

  /// No description provided for @ttsVoicePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a voice'**
  String get ttsVoicePickerTitle;

  /// No description provided for @ttsVoicePreviewSample.
  ///
  /// In en, this message translates to:
  /// **'The quick brown fox jumps over the lazy dog.'**
  String get ttsVoicePreviewSample;

  /// No description provided for @ttsVoicePreviewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preview this voice'**
  String get ttsVoicePreviewTooltip;

  /// No description provided for @ttsVoiceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get ttsVoiceCurrent;

  /// No description provided for @ttsNoVoicesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No voices available on this device'**
  String get ttsNoVoicesAvailable;

  /// No description provided for @ttsLinuxRequiresSpeechDispatcher.
  ///
  /// In en, this message translates to:
  /// **'Install speech-dispatcher to enable TTS on Linux (e.g. `sudo apt install speech-dispatcher`)'**
  String get ttsLinuxRequiresSpeechDispatcher;

  /// No description provided for @ttsFirstUseHint.
  ///
  /// In en, this message translates to:
  /// **'Tap play to start narration'**
  String get ttsFirstUseHint;

  /// No description provided for @ttsErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'TTS error: {error}'**
  String ttsErrorPrefix(String error);

  /// No description provided for @ttsVoiceFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Default for {locale}'**
  String ttsVoiceFallbackLabel(String locale);

  /// No description provided for @settingsTtsEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get settingsTtsEngine;

  /// No description provided for @settingsTtsEngineDesc.
  ///
  /// In en, this message translates to:
  /// **'TTS engine used to synthesise speech'**
  String get settingsTtsEngineDesc;

  /// No description provided for @ttsEnginePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an engine'**
  String get ttsEnginePickerTitle;

  /// No description provided for @ttsEnginePickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Different engines produce different voices and sound quality'**
  String get ttsEnginePickerSubtitle;

  /// No description provided for @ttsEnginePickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alternative engines installed'**
  String get ttsEnginePickerEmpty;

  /// No description provided for @ttsEnginePickerSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get ttsEnginePickerSystemDefault;

  /// No description provided for @ttsVoicePickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search voices, languages, regions...'**
  String get ttsVoicePickerSearchHint;

  /// No description provided for @ttsVoicePickerScopeCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current language'**
  String get ttsVoicePickerScopeCurrent;

  /// No description provided for @ttsVoicePickerScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get ttsVoicePickerScopeAll;

  /// No description provided for @ttsVoicePickerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No voices match your search'**
  String get ttsVoicePickerNoMatches;

  /// No description provided for @ttsVoicePickerNoCurrentVoices.
  ///
  /// In en, this message translates to:
  /// **'No voices for {language} on this device. Switch to All languages to browse what\'s installed.'**
  String ttsVoicePickerNoCurrentVoices(String language);

  /// No description provided for @settingsSectionSpeedTiming.
  ///
  /// In en, this message translates to:
  /// **'Speed & Timing'**
  String get settingsSectionSpeedTiming;

  /// No description provided for @settingsSectionRsvpDisplay.
  ///
  /// In en, this message translates to:
  /// **'RSVP Display'**
  String get settingsSectionRsvpDisplay;

  /// No description provided for @settingsSectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsSectionAudio;

  /// No description provided for @settingsSectionReaderView.
  ///
  /// In en, this message translates to:
  /// **'Reader View'**
  String get settingsSectionReaderView;

  /// No description provided for @settingsSectionTypography.
  ///
  /// In en, this message translates to:
  /// **'Typography & Background'**
  String get settingsSectionTypography;

  /// No description provided for @settingsSectionChrome.
  ///
  /// In en, this message translates to:
  /// **'Reader Chrome'**
  String get settingsSectionChrome;

  /// No description provided for @settingsScopeRsvp.
  ///
  /// In en, this message translates to:
  /// **'RSVP'**
  String get settingsScopeRsvp;

  /// No description provided for @settingsScopeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsScopeAudio;

  /// No description provided for @settingsScopeReader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get settingsScopeReader;

  /// No description provided for @settingsScopeAllModes.
  ///
  /// In en, this message translates to:
  /// **'All modes'**
  String get settingsScopeAllModes;

  /// No description provided for @settingsScopeControls.
  ///
  /// In en, this message translates to:
  /// **'RSVP & Audio'**
  String get settingsScopeControls;

  /// No description provided for @settingsScopeRsvpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Applies to RSVP mode only'**
  String get settingsScopeRsvpTooltip;

  /// No description provided for @settingsScopeAudioTooltip.
  ///
  /// In en, this message translates to:
  /// **'Applies to audio playback (TTS)'**
  String get settingsScopeAudioTooltip;

  /// No description provided for @settingsScopeReaderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Applies to RSVP, e-reader, and audio modes'**
  String get settingsScopeReaderTooltip;

  /// No description provided for @settingsScopeAllModesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Applies to all reading modes'**
  String get settingsScopeAllModesTooltip;

  /// No description provided for @settingsScopeControlsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Applies wherever the playback controls are visible (not e-reader)'**
  String get settingsScopeControlsTooltip;

  /// No description provided for @bookmarksTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarksTitle;

  /// No description provided for @bookmarksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarksTooltip;

  /// No description provided for @bookmarkCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Save bookmark'**
  String get bookmarkCreateTitle;

  /// No description provided for @bookmarkEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit bookmark'**
  String get bookmarkEditTitle;

  /// No description provided for @bookmarkLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get bookmarkLabelHint;

  /// No description provided for @bookmarkSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bookmarkSave;

  /// No description provided for @bookmarkEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get bookmarkEmptyTitle;

  /// No description provided for @bookmarkEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long-press a word in any reading mode to save your spot.'**
  String get bookmarkEmptySubtitle;

  /// No description provided for @bookmarkLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Ch. {chapter} · {percent}%'**
  String bookmarkLocationLabel(int chapter, int percent);

  /// No description provided for @bookmarkActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get bookmarkActionEdit;

  /// No description provided for @bookmarkActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bookmarkActionDelete;

  /// No description provided for @bookmarkDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark?'**
  String get bookmarkDeleteConfirmTitle;

  /// No description provided for @bookmarkDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This bookmark will be removed.'**
  String get bookmarkDeleteConfirmBody;

  /// No description provided for @bookmarkCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Bookmark saved'**
  String get bookmarkCreatedToast;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
