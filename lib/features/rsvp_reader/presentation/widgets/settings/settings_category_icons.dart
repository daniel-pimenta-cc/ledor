import 'package:flutter/material.dart';

import 'settings_category.dart';

/// Icon shown next to each [SettingsCategory] header. Kept separate from
/// [SettingsCategory] so the enum stays Flutter-free and trivially testable.
IconData iconForSettingsCategory(SettingsCategory category) {
  switch (category) {
    case SettingsCategory.speedTiming:
      return Icons.bolt;
    case SettingsCategory.rsvpDisplay:
      return Icons.center_focus_strong_outlined;
    case SettingsCategory.audio:
      return Icons.volume_up_outlined;
    case SettingsCategory.readerView:
      return Icons.menu_book_outlined;
    case SettingsCategory.typography:
      return Icons.text_format;
    case SettingsCategory.chrome:
      return Icons.tune;
  }
}
