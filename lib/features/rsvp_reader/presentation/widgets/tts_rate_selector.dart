import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/display_settings.dart';

/// Audiobook-style speech-rate selector for the TTS transport row.
///
/// Mirrors `WpmCapsule` / `WpmPresetRow` shape so the muscle memory is
/// identical to the RSVP speed picker, but talks in "1.0x / 1.25x / 1.5x"
/// rates instead of WPM. The engine drives playback off
/// `DisplaySettings.ttsRate` directly — no WPM → rate mapping involved.
class TtsRateCapsule extends StatelessWidget {
  final DisplaySettings settings;
  final double rate;
  final bool isOpen;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onLabelTap;

  const TtsRateCapsule({
    required this.settings,
    required this.rate,
    required this.isOpen,
    required this.onDown,
    required this.onUp,
    required this.onLabelTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final border = isOpen
        ? settings.orpColor.withAlpha(180)
        : settings.wordColor.withAlpha(50);
    final body = isOpen
        ? settings.orpColor.withAlpha(28)
        : settings.wordColor.withAlpha(14);
    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      decoration: BoxDecoration(
        color: body,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepIcon(
            icon: Icons.remove,
            color: settings.wordColor,
            onTap: onDown,
          ),
          InkWell(
            onTap: onLabelTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 72,
              height: 32,
              child: Center(
                child: Text(
                  formatTtsRate(rate),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: settings.wordColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          _StepIcon(
            icon: Icons.add,
            color: settings.wordColor,
            onTap: onUp,
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StepIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 18, color: color.withAlpha(200)),
      ),
    );
  }
}

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
          return _PresetChip(
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

class _PresetChip extends StatelessWidget {
  final DisplaySettings settings;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    super.key,
    required this.settings,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : settings.wordColor;
    final bg =
        selected ? settings.orpColor : settings.wordColor.withAlpha(14);
    final border =
        selected ? settings.orpColor : settings.wordColor.withAlpha(55);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderMd,
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderMd,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          constraints: const BoxConstraints(minWidth: 72),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
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

/// Clamps an arbitrary rate to the engine-accepted range. Exposed so the
/// engine doesn't duplicate the bounds when re-applying a synced value.
double clampTtsRate(double rate) =>
    rate.clamp(AppConstants.minTtsRate, AppConstants.maxTtsRate);
