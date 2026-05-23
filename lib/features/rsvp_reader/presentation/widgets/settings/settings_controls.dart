import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/entities/display_settings.dart';
import '../../providers/display_settings_provider.dart';
import '../../providers/rsvp_engine_provider.dart';

/// Pushes [updater] into both the persisted [displaySettingsProvider] and,
/// when a [bookId] is supplied, the running [RsvpEngineNotifier]. The same
/// [updater] hits both sides so the engine state only sees the field the
/// user touched.
///
/// An earlier version snapshotted the provider state and replaced the
/// engine's `displaySettings` wholesale — that worked until a user adjusted
/// `ttsRate` (or `wpm`) from a capsule, because those handlers only mutate
/// the engine state. The next time the user moved a slider, the snapshot
/// from the provider (still at the old rate) wiped out the engine's value
/// and re-issued `setSpeechRate` to the backend mid-utterance — which
/// silently broke flutter_tts on Android.
void updateDisplaySetting(
  WidgetRef ref,
  String? bookId,
  DisplaySettings Function(DisplaySettings) updater,
) {
  ref.read(displaySettingsProvider.notifier).update(updater);
  if (bookId != null) {
    ref
        .read(rsvpEngineProvider(bookId).notifier)
        .updateDisplaySettings(updater);
  }
}

/// Formats a multiplier value for the slider readout. Shows one decimal for
/// whole and half steps (`1.0`, `1.5`) and two for quarters (`1.25`) so the
/// label never grows when the user nudges between divisions.
String formatMultiplier(double v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

/// Catalogue of fonts the reader can switch between. [value] is what we
/// persist; [googleFont] is the family name google_fonts knows; [label] is
/// shown in the picker rendered in its own typeface.
const fontOptions = <({String value, String googleFont, String label})>[
  (value: 'RobotoMono', googleFont: 'Roboto Mono', label: 'Roboto Mono'),
  (value: 'JetBrainsMono', googleFont: 'JetBrains Mono', label: 'JetBrains Mono'),
  (value: 'FiraCode', googleFont: 'Fira Code', label: 'Fira Code'),
  (value: 'SourceCodePro', googleFont: 'Source Code Pro', label: 'Source Code Pro'),
  (value: 'Lora', googleFont: 'Lora', label: 'Lora (serif)'),
  (value: 'SourceSerif4', googleFont: 'Source Serif 4', label: 'Source Serif (serif)'),
];

const fontPreviewSample = 'The quick brown fox jumps 0123';

/// Row with a label on the left and an arbitrary [child] (typically a
/// control like a slider or stepper) on the right.
class SettingRow extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Widget child;

  const SettingRow({
    required this.label,
    required this.labelColor,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: labelColor, fontSize: 14)),
        ),
        child,
      ],
    );
  }
}

class SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Color labelColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchRow({
    required this.label,
    this.subtitle,
    required this.labelColor,
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: labelColor, fontSize: 14)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                      color: labelColor.withAlpha(140), fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class PlusMinusControl extends StatelessWidget {
  final int value;
  final Color color;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const PlusMinusControl({
    required this.value,
    required this.color,
    required this.onDecrease,
    required this.onIncrease,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
            icon: Icons.text_decrease, color: color, onTap: onDecrease),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$value',
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        _CircleButton(
            icon: Icons.text_increase, color: color, onTap: onIncrease),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class ColorRow extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Color color;
  final ValueChanged<Color> onChanged;

  const ColorRow({
    required this.label,
    required this.labelColor,
    required this.color,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: labelColor, fontSize: 14)),
        ),
        GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(40), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 300,
          child: ColorPicker(
            color: color,
            onColorChanged: onChanged,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
              ColorPickerType.wheel: true,
            },
            enableShadesSelection: true,
            enableOpacity: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Continuous slider for one of the structural-pause multipliers (sentence
/// or chapter). Shows the label, an optional subtitle, the current value
/// formatted as "1.5x", and a discrete-step slider tinted with [orpColor].
class MultiplierSliderRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Color labelColor;
  final Color orpColor;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) labelFor;
  final ValueChanged<double> onChanged;

  const MultiplierSliderRow({
    required this.label,
    this.subtitle,
    required this.labelColor,
    required this.orpColor,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.labelFor,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: labelColor, fontSize: 14),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: labelColor.withAlpha(140),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              labelFor(value),
              style: TextStyle(
                color: orpColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: orpColor,
            thumbColor: orpColor,
            inactiveTrackColor: labelColor.withAlpha(40),
            overlayColor: orpColor.withAlpha(40),
            valueIndicatorColor: orpColor,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Segmented picker for [DisplaySettings.timeRemainingMode]. Three text-only
/// options sit next to the meta row in the reader, so a SegmentedButton with
/// text labels is sufficient (no preview tile needed).
class TimeRemainingRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color labelColor;
  final Color orpColor;
  final TimeRemainingMode value;
  final String Function(TimeRemainingMode) labelFor;
  final ValueChanged<TimeRemainingMode> onChanged;

  const TimeRemainingRow({
    required this.label,
    required this.subtitle,
    required this.labelColor,
    required this.orpColor,
    required this.value,
    required this.labelFor,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: labelColor.withAlpha(140), fontSize: 11),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TimeRemainingMode>(
            segments: [
              for (final m in TimeRemainingMode.values)
                ButtonSegment(value: m, label: Text(labelFor(m))),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onChanged(s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? orpColor.withAlpha(40)
                    : Colors.transparent,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? orpColor
                    : labelColor.withAlpha(190),
              ),
              overlayColor: WidgetStateProperty.all(
                orpColor.withAlpha(30),
              ),
              side: WidgetStateProperty.all(
                BorderSide(color: labelColor.withAlpha(50)),
              ),
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Picker for the ORP indicator visual style. Renders each option as a small
/// preview tile (matching the four indicator styles) above a row of labels.
class OrpIndicatorRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color labelColor;
  final Color orpColor;
  final Color backgroundColor;
  final OrpIndicatorStyle value;
  final String Function(OrpIndicatorStyle) labelFor;
  final ValueChanged<OrpIndicatorStyle> onChanged;

  const OrpIndicatorRow({
    required this.label,
    required this.subtitle,
    required this.labelColor,
    required this.orpColor,
    required this.backgroundColor,
    required this.value,
    required this.labelFor,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: labelColor.withAlpha(140), fontSize: 11),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < OrpIndicatorStyle.values.length; i++) ...[
              Expanded(
                child: _OrpIndicatorTile(
                  style: OrpIndicatorStyle.values[i],
                  selected: OrpIndicatorStyle.values[i] == value,
                  label: labelFor(OrpIndicatorStyle.values[i]),
                  labelColor: labelColor,
                  orpColor: orpColor,
                  backgroundColor: backgroundColor,
                  onTap: () => onChanged(OrpIndicatorStyle.values[i]),
                ),
              ),
              // Index-based separator instead of `style != values.last`,
              // so reordering the enum (e.g. moving `off` mid-list) keeps
              // the row spacing correct.
              if (i < OrpIndicatorStyle.values.length - 1)
                const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _OrpIndicatorTile extends StatelessWidget {
  final OrpIndicatorStyle style;
  final bool selected;
  final String label;
  final Color labelColor;
  final Color orpColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _OrpIndicatorTile({
    required this.style,
    required this.selected,
    required this.label,
    required this.labelColor,
    required this.orpColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? orpColor : labelColor.withAlpha(40);
    final fillColor = selected
        ? Color.lerp(backgroundColor, orpColor, 0.08) ?? backgroundColor
        : Color.lerp(backgroundColor, Colors.white, 0.05) ?? backgroundColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              child: CustomPaint(
                size: const Size(double.infinity, 40),
                painter: _OrpIndicatorPreviewPainter(
                  style: style,
                  orpColor: orpColor,
                  wordColor: labelColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini-preview painter that draws a stylized word with the chosen indicator,
/// so users can pick from a visual catalog instead of guessing what the
/// labels mean.
class _OrpIndicatorPreviewPainter extends CustomPainter {
  final OrpIndicatorStyle style;
  final Color orpColor;
  final Color wordColor;

  _OrpIndicatorPreviewPainter({
    required this.style,
    required this.orpColor,
    required this.wordColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final wordCenterY = size.height / 2;

    final dim = Paint()..color = wordColor.withAlpha(170);
    final accent = Paint()..color = orpColor;
    const barH = 8.0;
    const barW = 6.0;
    const gap = 4.0;
    final wordWidth = barW * 3 + gap * 2;
    final wordLeft = centerX - wordWidth / 2;
    final wordTop = wordCenterY - barH / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(wordLeft, wordTop, barW, barH),
          const Radius.circular(1.5)),
      dim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(wordLeft + barW + gap, wordTop, barW, barH),
          const Radius.circular(1.5)),
      accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(wordLeft + 2 * (barW + gap), wordTop, barW, barH),
          const Radius.circular(1.5)),
      dim,
    );

    final anchorX = wordLeft + barW + gap + barW / 2;
    final indicator = Paint()..color = orpColor;

    switch (style) {
      case OrpIndicatorStyle.notch:
        final path = Path()
          ..moveTo(anchorX - 3, wordTop - 5)
          ..lineTo(anchorX + 3, wordTop - 5)
          ..lineTo(anchorX, wordTop - 1)
          ..close();
        canvas.drawPath(path, indicator);
      case OrpIndicatorStyle.lineAbove:
        canvas.drawRect(
          Rect.fromLTWH(anchorX - 6, wordTop - 3, 12, 1.2),
          indicator,
        );
      case OrpIndicatorStyle.linesAround:
        final orpCx = wordLeft + barW + gap + barW / 2;
        canvas.drawRect(
          Rect.fromLTWH(orpCx - 0.6, wordTop - 5, 1.2, 4),
          indicator,
        );
        canvas.drawRect(
          Rect.fromLTWH(orpCx - 0.6, wordTop + barH + 1, 1.2, 4),
          indicator,
        );
      case OrpIndicatorStyle.off:
        break;
    }
  }

  @override
  bool shouldRepaint(_OrpIndicatorPreviewPainter old) =>
      old.style != style ||
      old.orpColor != orpColor ||
      old.wordColor != wordColor;
}

/// Tap-target row that surfaces the currently selected TTS voice and opens
/// the voice picker sheet.
class TtsVoiceRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color labelColor;
  final Color orpColor;
  final String? currentVoiceName;
  final String currentLocale;
  final String Function(String locale) fallbackLabelFor;
  final VoidCallback onTap;

  const TtsVoiceRow({
    required this.label,
    required this.subtitle,
    required this.labelColor,
    required this.orpColor,
    required this.currentVoiceName,
    required this.currentLocale,
    required this.fallbackLabelFor,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasVoice =
        currentVoiceName != null && currentVoiceName!.isNotEmpty;
    final displayName =
        hasVoice ? currentVoiceName! : fallbackLabelFor(currentLocale);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: labelColor.withAlpha(140),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                displayName,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: orpColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: labelColor.withAlpha(140), size: 20),
          ],
        ),
      ),
    );
  }
}

/// Tap-target row that surfaces the currently selected TTS engine and
/// opens the engine picker sheet.
class TtsEngineRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color labelColor;
  final Color orpColor;
  final String currentLabel;
  final VoidCallback onTap;

  const TtsEngineRow({
    required this.label,
    required this.subtitle,
    required this.labelColor,
    required this.orpColor,
    required this.currentLabel,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: labelColor.withAlpha(140),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                currentLabel,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: orpColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: labelColor.withAlpha(140), size: 20),
          ],
        ),
      ),
    );
  }
}

/// Font picker that renders each option in its own typeface and shows
/// a sample line below using the currently selected font.
class FontSelector extends StatelessWidget {
  final String label;
  final String currentValue;
  final Color labelColor;
  final Color backgroundColor;
  final ValueChanged<String> onChanged;

  const FontSelector({
    required this.label,
    required this.currentValue,
    required this.labelColor,
    required this.backgroundColor,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final current = fontOptions.firstWhere(
      (o) => o.value == currentValue,
      orElse: () => fontOptions.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
            DropdownButton<String>(
              value: currentValue,
              dropdownColor:
                  Color.lerp(backgroundColor, Colors.white, 0.12),
              underline: const SizedBox.shrink(),
              selectedItemBuilder: (context) => fontOptions
                  .map((opt) => Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          opt.label,
                          style: GoogleFonts.getFont(
                            opt.googleFont,
                            color: labelColor,
                            fontSize: 14,
                          ),
                        ),
                      ))
                  .toList(),
              items: fontOptions
                  .map((opt) => DropdownMenuItem(
                        value: opt.value,
                        child: Text(
                          opt.label,
                          style: GoogleFonts.getFont(
                            opt.googleFont,
                            color: labelColor,
                            fontSize: 15,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Color.lerp(backgroundColor, Colors.white, 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: labelColor.withAlpha(30)),
          ),
          child: Text(
            fontPreviewSample,
            style: GoogleFonts.getFont(
              current.googleFont,
              color: labelColor,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
