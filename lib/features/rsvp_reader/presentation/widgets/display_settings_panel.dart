import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/display_settings_provider.dart';
import '../providers/rsvp_engine_provider.dart';
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
/// Used by [ReaderSettingsSheet] (bottom sheet), [ReaderSidePanel] (tablet
/// landscape) and [SettingsScreen] (full screen). When [bookId] is provided,
/// edits also propagate to the running engine for live preview; otherwise
/// only persisted settings update.
///
/// When [bookId] is set, the section that owns the active reader mode floats
/// to the top and its header chip lights up — a quick visual answer to "what
/// in here actually affects what I'm seeing right now?". Full-screen Settings
/// uses a fixed pedagogical order instead, since there is no active mode.
///
/// The TTS section is suppressed entirely on platforms that don't expose any
/// TTS backend.
class DisplaySettingsPanel extends ConsumerWidget {
  final String? bookId;

  const DisplaySettingsPanel({this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);
    final activeMode =
        bookId != null ? ref.watch(readerModeProvider(bookId!)) : null;

    final categories = orderedCategoriesFor(activeMode).where(
      (c) => c != SettingsCategory.audio || PlatformCapabilities.supportsTts,
    );

    final children = <Widget>[];
    for (final category in categories) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.lg));
      }
      children.add(_buildSection(
        category,
        settings: settings,
        activeMode: activeMode,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildSection(
    SettingsCategory category, {
    required DisplaySettings settings,
    required ReaderMode? activeMode,
  }) {
    final isActive = isCategoryActiveFor(category, activeMode);
    // ValueKey(category) makes Flutter element-match sections by identity
    // instead of position. When the active mode changes and the sections
    // reorder, each section's State (including the AudioSection's
    // ttsEnginesProvider subscription and the header's animation state)
    // moves with it instead of being torn down and rebuilt at a new index.
    final key = ValueKey(category);
    switch (category) {
      case SettingsCategory.speedTiming:
        return SpeedTimingSection(
            key: key, bookId: bookId, settings: settings, isActive: isActive);
      case SettingsCategory.rsvpDisplay:
        return RsvpDisplaySection(
            key: key, bookId: bookId, settings: settings, isActive: isActive);
      case SettingsCategory.audio:
        return AudioSection(
            key: key, bookId: bookId, settings: settings, isActive: isActive);
      case SettingsCategory.readerView:
        return ReaderViewSection(
            key: key, bookId: bookId, settings: settings, isActive: isActive);
      case SettingsCategory.typography:
        return TypographySection(
            key: key, bookId: bookId, settings: settings, isActive: isActive);
      case SettingsCategory.chrome:
        return ChromeSection(
            key: key, bookId: bookId, settings: settings, isActive: isActive);
    }
  }
}
