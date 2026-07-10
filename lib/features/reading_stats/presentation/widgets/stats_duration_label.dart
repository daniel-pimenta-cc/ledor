import '../../../../l10n/generated/app_localizations.dart';

/// Localized "Xh Ym" (or just "Ym" under an hour) label for a duration in
/// milliseconds. Shared by the stats summary, book completion card, and
/// book completion screen.
String formatDuration(AppLocalizations l10n, int ms) {
  final totalMinutes = (ms / 60000).round();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0
      ? l10n.statsDurationHoursMinutes(hours, minutes)
      : l10n.statsDurationMinutes(totalMinutes);
}
