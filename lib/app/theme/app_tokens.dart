import 'package:flutter/material.dart';

abstract final class AppTokens {
  static const Color pageBackground = Color(0xFF091312);
  static const Color panelBackground = Color(0xFF0E1B1A);
  static const Color surfaceBase = Color(0xFF132423);
  static const Color surfaceRaised = Color(0xFF19302E);
  static const Color borderSubtle = Color(0xFF264543);
  static const Color brandAccent = Color(0xFF5FFFD2);
  static const Color brandAccentSoft = Color(0xFF163E39);
  static const Color textPrimary = Color(0xFFF3FFFC);
  static const Color textMuted = Color(0xFF9FC4BD);
  static const Color success = Color(0xFF7BFFB4);
  static const Color warning = Color(0xFFFFC86F);
  static const Color danger = Color(0xFFFF7D8F);

  static const double radiusSmall = 12;
  static const double radiusMedium = 20;
  static const double radiusLarge = 28;

  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 260);
}
