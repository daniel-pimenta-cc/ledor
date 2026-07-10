import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/display_settings.dart';

/// Number of [presetStep]-sized chips on each side of the current value in
/// the preset drawer. 6 gives 13 chips total — enough range to jump to any
/// reasonable target in a single glance.
const int _defaultPresetRadius = 6;

/// WPM step between adjacent chips in the preset drawer.
const int _presetStep = 50;

/// Build the inline preset row dynamically around [currentWpm]. The current
/// value itself is always at the centre of the row; chips on either side step
/// by [step] WPM relative to it, so the user can shift from any starting
/// point — including off-multiples like 325 — without losing the highlight.
List<int> buildWpmPresets(
  int currentWpm, {
  int step = 50,
  int radius = _defaultPresetRadius,
  int min = AppConstants.minWpm,
  int max = AppConstants.maxWpm,
}) {
  final values = <int>[];
  for (int k = -radius; k <= radius; k++) {
    final v = currentWpm + k * step;
    if (v >= min && v <= max) values.add(v);
  }
  return values;
}

/// All-in-one WPM selector: capsule (minus / value / plus) on top, and an
/// inline horizontally-scrollable preset drawer underneath that animates open
/// when the user taps the value.
///
/// The drawer's current value is centred on open. Colours come from
/// [settings] so the selector matches the live-preview reader palette when
/// used inside the reader itself.
class WpmSelector extends StatefulWidget {
  final DisplaySettings settings;
  final int currentWpm;
  final ValueChanged<int> onChanged;
  final String Function(int) labelFormatter;

  const WpmSelector({
    required this.settings,
    required this.currentWpm,
    required this.onChanged,
    required this.labelFormatter,
    super.key,
  });

  @override
  State<WpmSelector> createState() => _WpmSelectorState();
}

class _WpmSelectorState extends State<WpmSelector> {
  bool _open = false;

  void _step(int delta) {
    final next = (widget.currentWpm + delta)
        .clamp(AppConstants.minWpm, AppConstants.maxWpm);
    if (next != widget.currentWpm) {
      HapticFeedback.selectionClick();
      widget.onChanged(next);
    }
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        WpmCapsule(
          settings: widget.settings,
          label: widget.labelFormatter(widget.currentWpm),
          isOpen: _open,
          onDown: () => _step(-AppConstants.wpmStep),
          onUp: () => _step(AppConstants.wpmStep),
          onLabelTap: _toggle,
        ),
        AnimatedSize(
          duration: AppDurations.base,
          curve: AppCurves.emphasized,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: WpmPresetRow(
                    settings: widget.settings,
                    currentWpm: widget.currentWpm,
                    presets: buildWpmPresets(
                      widget.currentWpm,
                      step: _presetStep,
                      radius: _defaultPresetRadius,
                    ),
                    formatLabel: widget.labelFormatter,
                    onSelect: (value) {
                      HapticFeedback.selectionClick();
                      widget.onChanged(value);
                      setState(() => _open = false);
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Pill-shaped capsule with minus / value / plus. The value area itself is
/// tappable — used by [WpmSelector] (and the reader's transport row) to
/// toggle the preset drawer open.
class WpmCapsule extends StatelessWidget {
  final DisplaySettings settings;
  final String label;
  final bool isOpen;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onLabelTap;

  const WpmCapsule({
    required this.settings,
    required this.label,
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
                  label,
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

/// Horizontal scrollable row of preset chips. On first layout the currently
/// selected chip is scrolled to the centre of the viewport (instantly — the
/// drawer itself is animating in, so a secondary scroll animation on top of
/// that reads as jittery).
class WpmPresetRow extends StatefulWidget {
  final DisplaySettings settings;
  final int currentWpm;
  final List<int> presets;
  final String Function(int) formatLabel;
  final ValueChanged<int> onSelect;

  const WpmPresetRow({
    required this.settings,
    required this.currentWpm,
    required this.presets,
    required this.formatLabel,
    required this.onSelect,
    super.key,
  });

  @override
  State<WpmPresetRow> createState() => _WpmPresetRowState();
}

class _WpmPresetRowState extends State<WpmPresetRow> {
  final GlobalKey _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: Duration.zero,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // The current WPM is always included in presets (see `buildWpmPresets`),
    // so its index is guaranteed.
    final targetIndex = widget.presets.indexOf(widget.currentWpm);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: widget.presets.length,
        separatorBuilder: (_, i) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final value = widget.presets[i];
          final selected = value == widget.currentWpm;
          return PresetChip(
            key: i == targetIndex ? _selectedKey : null,
            settings: widget.settings,
            label: widget.formatLabel(value),
            selected: selected,
            onTap: () => widget.onSelect(value),
          );
        },
      ),
    );
  }
}

/// Rounded pill for a single speed preset. Shared by [WpmPresetRow] and the
/// TTS rate drawer. Colours come from [settings] for live-preview parity.
class PresetChip extends StatelessWidget {
  final DisplaySettings settings;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PresetChip({
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
