import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../domain/entities/display_settings.dart';
import '../providers/display_settings_provider.dart';
import 'settings/sections/audio_section.dart';
import 'settings/sections/chrome_section.dart';
import 'settings/sections/reader_view_section.dart';
import 'settings/sections/rsvp_display_section.dart';
import 'settings/sections/speed_timing_section.dart';
import 'settings/sections/typography_section.dart';
import 'settings/settings_category.dart';

/// All display + reading settings rendered as a single Column of categorised
/// sections.
///
/// Used by both [ReaderSettingsSheet] (bottom sheet), [ReaderSidePanel]
/// (tablet landscape) and [SettingsScreen] (full screen). When [bookId] is
/// provided, edits also propagate to the running engine for live preview;
/// otherwise only persisted settings update.
///
/// Section order is fixed (pedagogical) in this phase — Fase 3 introduces
/// the reorder-by-active-mode behaviour. The TTS section is suppressed
/// entirely on platforms that don't expose any TTS backend.
class DisplaySettingsPanel extends ConsumerWidget {
  final String? bookId;

  const DisplaySettingsPanel({this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);

    final categories = orderedCategoriesFor(null).where(
      (c) => c != SettingsCategory.audio || PlatformCapabilities.supportsTts,
    );

    final children = <Widget>[];
    for (final category in categories) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.lg));
      }
      children.add(_buildSection(category, settings: settings));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildSection(
    SettingsCategory category, {
    required DisplaySettings settings,
  }) {
    switch (category) {
      case SettingsCategory.speedTiming:
        return SpeedTimingSection(bookId: bookId, settings: settings);
      case SettingsCategory.rsvpDisplay:
        return RsvpDisplaySection(bookId: bookId, settings: settings);
      case SettingsCategory.audio:
        return AudioSection(bookId: bookId, settings: settings);
      case SettingsCategory.readerView:
        return ReaderViewSection(bookId: bookId, settings: settings);
      case SettingsCategory.typography:
        return TypographySection(bookId: bookId, settings: settings);
      case SettingsCategory.chrome:
        return ChromeSection(bookId: bookId, settings: settings);
    }
  }
}
