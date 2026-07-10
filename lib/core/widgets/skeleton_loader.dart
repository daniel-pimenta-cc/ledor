import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Minimal shimmer-style placeholder. One [AnimationController] drives every
/// `SkeletonBox` beneath a single `SkeletonHost` to keep the per-frame cost
/// flat even with many items on screen.
class SkeletonHost extends StatefulWidget {
  final Widget child;

  const SkeletonHost({required this.child, super.key});

  @override
  State<SkeletonHost> createState() => _SkeletonHostState();
}

class _SkeletonHostState extends State<SkeletonHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScope(controller: _controller, child: widget.child);
  }
}

class _SkeletonScope extends InheritedWidget {
  final AnimationController controller;

  const _SkeletonScope({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) => false;

  static AnimationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SkeletonScope>();
    assert(scope != null, 'SkeletonBox must be used within a SkeletonHost');
    return scope!.controller;
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    this.width,
    this.height,
    this.borderRadius = AppRadius.borderMd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _SkeletonScope.of(context);
    final base = scheme.surfaceContainerHigh;
    final highlight = scheme.outlineVariant;

    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        final t = controller.value;
        return SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                colors: [base, highlight, base],
                stops: [
                  (t - 0.3).clamp(0.0, 1.0),
                  t.clamp(0.0, 1.0),
                  (t + 0.3).clamp(0.0, 1.0),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class SkeletonBookCard extends StatelessWidget {
  const SkeletonBookCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: SkeletonBox(borderRadius: AppRadius.borderMd),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(height: 12, width: 130),
                  const SizedBox(height: AppSpacing.sm),
                  const SkeletonBox(height: 10, width: 80),
                  const Spacer(),
                  SkeletonBox(
                    height: 2,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
