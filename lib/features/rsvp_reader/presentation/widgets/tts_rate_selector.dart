import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/display_settings.dart';
import 'wpm_selector.dart';

/// Audiobook-style speech-rate selector for the TTS transport row.
///
/// The capsule itself is a plain [WpmCapsule] fed `formatTtsRate(rate)` as its
/// label — same muscle memory as the RSVP speed picker. Only the preset drawer
/// differs (fixed rate ladder + nearest-match snapping), so it lives here. The
/// engine drives playback off `DisplaySettings.ttsRate` directly.

/// Horizontal scrollable row of preset rate chips. The current chip
/// auto-centers on open so the user lands on their selection.
class TtsRatePresetRow extends StatefulWidget {
  final DisplaySettings settings;
  final double currentRate;
  final ValueChanged<double> onSelect;

  const TtsRatePresetRow({
    required this.settings,
    required this.currentRate,
    required this.onSelect,
    super.key,
  });

  /// Canonical audiobook-player rate ladder. Fixed list (not generated
  /// around the current value) because users expect "0.75 / 1.0 / 1.25 …"
  /// to be discoverable in a glance.
  static const List<double> _presets = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.5,
    3.0,
  ];

  @override
  State<TtsRatePresetRow> createState() => _TtsRatePresetRowState();
}

class _TtsRatePresetRowState extends State<TtsRatePresetRow> {
  final GlobalKey _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Snap the current rate to the nearest preset so the highlight always
    // appears somewhere, even if the user nudged the capsule by +/-0.25
    // off the canonical ladder.
    final selectedIndex = _nearestPresetIndex(widget.currentRate);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: TtsRatePresetRow._presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final value = TtsRatePresetRow._presets[i];
          final selected = i == selectedIndex;
          return PresetChip(
            key: selected ? _selectedKey : null,
            settings: widget.settings,
            label: formatTtsRate(value),
            selected: selected,
            onTap: () => widget.onSelect(value),
          );
        },
      ),
    );
  }

  int _nearestPresetIndex(double rate) {
    int best = 0;
    double bestDist = (TtsRatePresetRow._presets[0] - rate).abs();
    for (var i = 1; i < TtsRatePresetRow._presets.length; i++) {
      final d = (TtsRatePresetRow._presets[i] - rate).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }
}

/// "1x", "1.25x", "0.75x". Drops the trailing zero on .0 values so the
/// label stays a single glyph at the canonical 1.0x.
String formatTtsRate(double rate) {
  if ((rate * 100).round() % 100 == 0) {
    return '${rate.toStringAsFixed(0)}x';
  }
  final s = rate.toStringAsFixed(2);
  // Trim trailing zero on quarters like 1.25 → keep, 1.50 → 1.5
  if (s.endsWith('0')) {
    return '${s.substring(0, s.length - 1)}x';
  }
  return '${s}x';
}
