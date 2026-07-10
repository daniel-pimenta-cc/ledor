import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build({required Brightness brightness}) {
    final palette =
        brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    final scheme = palette.toColorScheme();
    final textTheme = AppTypography.build(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          color: palette.onSurface,
        ),
        iconTheme: IconThemeData(color: palette.onSurface),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.outline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.onSurface,
        ),
      ),

      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: palette.primary,
        inactiveTrackColor: palette.outline,
        thumbColor: palette.primary,
        overlayColor: palette.primary.withAlpha(30),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surfaceContainer,
        modalBarrierColor: Colors.black.withAlpha(
            brightness == Brightness.dark ? 140 : 90),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderTopXl,
        ),
        showDragHandle: true,
        dragHandleColor: palette.onSurfaceVariant.withAlpha(120),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceContainerHigh,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: palette.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: palette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.onSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        elevation: 2,
      ),

      dividerTheme: DividerThemeData(
        color: palette.outline,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: palette.onSurface,
        textColor: palette.onSurface,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 2,
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: palette.onPrimary,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: palette.onSurface,
        unselectedLabelColor: palette.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: palette.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: palette.outlineVariant,
        dividerHeight: 1,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
