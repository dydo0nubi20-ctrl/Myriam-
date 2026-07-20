library;

import 'package:flutter/material.dart';

import 'studio_colors.dart';

export 'studio_colors.dart';

class StudioTheme {
  StudioTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: StudioColors.accent,
      onPrimary: Colors.white,
      secondary: StudioColors.accentSecondary,
      onSecondary: Colors.white,
      error: StudioColors.error,
      onError: Colors.white,
      surface: StudioColors.surface,
      onSurface: StudioColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: StudioColors.canvas,
      canvasColor: StudioColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: StudioColors.surface,
        foregroundColor: StudioColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      dividerTheme: const DividerThemeData(color: StudioColors.separator, thickness: 0.5),
      sliderTheme: const SliderThemeData(
        activeTrackColor: StudioColors.accent,
        inactiveTrackColor: StudioColors.separator,
        thumbColor: Colors.white,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: StudioColors.surfaceRaised,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
