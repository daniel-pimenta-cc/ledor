import 'package:flutter/material.dart';

import '../../../../../core/theme/app_motion.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import 'settings_category.dart';
import 'settings_category_icons.dart';

/// Header rendered above every section of the settings panel: leading icon,
/// uppercase label, and a [_ScopeChip] indicating which reading modes the
/// section affects.
///
/// When [isActive] is true (the section maps to the currently active reading
/// mode), the chip switches from outlined to filled and the label uses the
/// accent colour — a quiet "this is what affects what you see right now"
/// cue. When `null` is passed for the active mode (full-screen Settings
/// page), every header renders in its neutral style.
class SettingsSectionHeader extends StatelessWidget {
  final SettingsCategory category;
  final String label;
  final Color wordColor;
  final Color orpColor;
  final bool isActive;

  const SettingsSectionHeader({
    required this.category,
    required this.label,
    required this.wordColor,
    required this.orpColor,
    this.isActive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labelColor = isActive ? orpColor : wordColor.withAlpha(180);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppCurves.standard,
            child: Icon(
              iconForSettingsCategory(category),
              size: 16,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              curve: AppCurves.standard,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              child: Text(label.toUpperCase()),
            ),
          ),
          const SizedBox(width: 8),
          _ScopeChip(
            scope: category.scope,
            wordColor: wordColor,
            orpColor: orpColor,
            filled: isActive,
            label: _scopeLabel(l10n, category.scope),
            tooltip: _scopeTooltip(l10n, category.scope),
          ),
        ],
      ),
    );
  }

  String _scopeLabel(AppLocalizations l10n, SettingsScope scope) {
    switch (scope) {
      case SettingsScope.rsvpOnly:
        return l10n.settingsScopeRsvp;
      case SettingsScope.audioOnly:
        return l10n.settingsScopeAudio;
      case SettingsScope.readerModes:
        return l10n.settingsScopeReader;
      case SettingsScope.allModes:
        return l10n.settingsScopeAllModes;
    }
  }

  String _scopeTooltip(AppLocalizations l10n, SettingsScope scope) {
    switch (scope) {
      case SettingsScope.rsvpOnly:
        return l10n.settingsScopeRsvpTooltip;
      case SettingsScope.audioOnly:
        return l10n.settingsScopeAudioTooltip;
      case SettingsScope.readerModes:
        return l10n.settingsScopeReaderTooltip;
      case SettingsScope.allModes:
        return l10n.settingsScopeAllModesTooltip;
    }
  }
}

class _ScopeChip extends StatelessWidget {
  final SettingsScope scope;
  final Color wordColor;
  final Color orpColor;
  final bool filled;
  final String label;
  final String tooltip;

  const _ScopeChip({
    required this.scope,
    required this.wordColor,
    required this.orpColor,
    required this.filled,
    required this.label,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final background = filled ? orpColor : Colors.transparent;
    final foreground = filled ? Colors.white : wordColor.withAlpha(160);
    final border = filled ? orpColor : wordColor.withAlpha(60);

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          style: TextStyle(
            color: foreground,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
