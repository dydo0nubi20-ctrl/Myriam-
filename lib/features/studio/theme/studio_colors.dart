library;

import 'package:flutter/material.dart';

class StudioColors {
  StudioColors._();

  static const Color canvas = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0B);
  static const Color surfaceRaised = Color(0xFF17171A);
  static const Color separator = Color(0xFF2A2A2E);

  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFB0B0B5);
  static const Color textTertiary = Color(0xFF6E6E73);

  static const Color accent = Color(0xFFFF2D55);
  static const Color accentSecondary = Color(0xFFA855F7);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF453A);

  static const Color trackVideo = Color(0xFF0A84FF);
  static const Color trackAudio = Color(0xFF30D158);
  static const Color trackText = Color(0xFFFFD60A);
  static const Color trackSticker = Color(0xFFBF5AF2);

  static const List<Color> accentGradient = [
    Color(0xFFFF2D55),
    Color(0xFFA855F7),
  ];
}

class StudioSpacing {
  StudioSpacing._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48;
}

class StudioRadius {
  StudioRadius._();
  static const double sm = 8, md = 12, lg = 16, xl = 24, pill = 999;
}
