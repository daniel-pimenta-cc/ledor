import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../library_sync/presentation/widgets/sync_settings_section.dart';
import '../../../rsvp_reader/presentation/providers/display_settings_provider.dart';
import '../../../rsvp_reader/presentation/widgets/display_settings_panel.dart';
import '../providers/theme_mode_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(displaySettingsProvider);

    return Scaffold(
      backgroundColor: settings.backgroundColor,
      appBar: AppBar(
        backgroundColor: settings.backgroundColor,
        foregroundColor: settings.wordColor,
        elevation: 0,
        title: Text(l10n.settings,
            style: TextStyle(color: settings.wordColor)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Appearance is the only section that uses Theme.of (not
            // DisplaySettings) — it's the meta-control of the theme itself.
            _AppearanceSection(wordColor: settings.wordColor),
            const SizedBox(height: AppSpacing.lg),
            Divider(color: settings.wordColor.withAlpha(40), height: 1),
            const SizedBox(height: AppSpacing.base),
            const DisplaySettingsPanel(),
            const SizedBox(height: AppSpacing.lg),
            Divider(color: settings.wordColor.withAlpha(40), height: 1),
            const SizedBox(height: AppSpacing.base),
            if (PlatformCapabilities.supportsDriveSync) ...[
              const SyncSettingsSection(),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: settings.wordColor.withAlpha(40), height: 1),
              const SizedBox(height: AppSpacing.base),
            ],
            Text(
              l10n.settingsAbout.toUpperCase(),
              style: TextStyle(
                color: settings.wordColor.withAlpha(140),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Ledor',
                  style: TextStyle(color: settings.wordColor)),
              // ponytail: manual, bump junto com o pubspec a cada release;
              // package_info_plus se cansar de esquecer
              subtitle: Text('v0.2.0',
                  style:
                      TextStyle(color: settings.wordColor.withAlpha(160))),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  final Color wordColor;
  const _AppearanceSection({required this.wordColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsAppearance.toUpperCase(),
          style: TextStyle(
            color: wordColor.withAlpha(140),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.settingsThemeMode,
                style: TextStyle(color: wordColor),
              ),
            ),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeModeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeModeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeModeDark),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selected) {
                ref.read(themeModeProvider.notifier).set(selected.first);
              },
            ),
          ],
        ),
      ],
    );
  }
}
