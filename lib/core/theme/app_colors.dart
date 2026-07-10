import 'package:flutter/material.dart';

/// Editorial warm palette. Dark = "ink on aged paper"; light = "paper".
/// Primary accent (warm orange) is preserved across modes.
class AppPalette {
  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color error;
  final Color highlight;

  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.highlight,
  });

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFFE55324),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF472014),
    onPrimaryContainer: Color(0xFFFFD9C8),
    background: Color(0xFF15120F),
    surface: Color(0xFF1C1815),
    surfaceContainer: Color(0xFF241E19),
    surfaceContainerHigh: Color(0xFF2E271F),
    onSurface: Color(0xFFEDE6DB),
    onSurfaceVariant: Color(0xFFA69B8A),
    outline: Color(0xFF3A322A),
    outlineVariant: Color(0xFF2A241E),
    error: Color(0xFFE05C5C),
    highlight: Color(0x40FFAB00),
  );

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFFE55324),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE5D6),
    onPrimaryContainer: Color(0xFF3B1607),
    background: Color(0xFFF8F3EA),
    surface: Color(0xFFFFFCF5),
    surfaceContainer: Color(0xFFF1EADD),
    surfaceContainerHigh: Color(0xFFE8DFCF),
    onSurface: Color(0xFF2B2520),
    onSurfaceVariant: Color(0xFF6B5F52),
    outline: Color(0xFFD9CFBF),
    outlineVariant: Color(0xFFE6DDCC),
    error: Color(0xFFB3261E),
    highlight: Color(0x40FFAB00),
  );

  ColorScheme toColorScheme() {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: primary,
      onSecondary: onPrimary,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      outline: outline,
      outlineVariant: outlineVariant,
    );
  }
}
