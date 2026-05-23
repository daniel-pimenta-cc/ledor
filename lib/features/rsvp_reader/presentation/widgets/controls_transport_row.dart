import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';

class ControlsTransportRow extends StatelessWidget {
  final RsvpState state;
  final AppLocalizations l10n;

  /// Capsule rendered on the right (or below, on narrow widths). Owned by
  /// the parent so RSVP/scroll/ereader can pass a [WpmCapsule] while TTS
  /// passes a [TtsRateCapsule] — both speak the same role from this
  /// widget's point of view: "the speed control".
  final Widget speedControl;

  final VoidCallback onPlayPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;

  const ControlsTransportRow({
    required this.state,
    required this.l10n,
    required this.speedControl,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
    super.key,
  });

  static const double _inlineBreakpoint = 520;

  @override
  Widget build(BuildContext context) {
    final settings = state.displaySettings;
    final transport = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SkipButton(
          settings: settings,
          icon: Icons.replay_10_rounded,
          onTap: onSkipBack,
        ),
        const SizedBox(width: AppSpacing.lg),
        _PlayButton(
          settings: settings,
          isPlaying: state.isPlaying,
          onTap: onPlayPause,
        ),
        const SizedBox(width: AppSpacing.lg),
        _SkipButton(
          settings: settings,
          icon: Icons.forward_10_rounded,
          onTap: onSkipForward,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _inlineBreakpoint) {
          return SizedBox(
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                transport,
                Align(alignment: Alignment.centerRight, child: speedControl),
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            transport,
            const SizedBox(height: AppSpacing.md),
            speedControl,
          ],
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final DisplaySettings settings;
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayButton({
    required this.settings,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: settings.orpColor,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppDurations.fast,
              switchInCurve: AppCurves.standard,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(isPlaying),
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final DisplaySettings settings;
  final IconData icon;
  final VoidCallback onTap;

  const _SkipButton({
    required this.settings,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: settings.wordColor.withAlpha(14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: settings.wordColor.withAlpha(230),
            size: 26,
          ),
        ),
      ),
    );
  }
}
