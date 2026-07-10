import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Editorial empty state — icon nested in a soft circle, serif title,
/// muted subtitle.
class LibraryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const LibraryEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainer,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(
                icon,
                size: 40,
                color: scheme.primary.withAlpha(180),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
