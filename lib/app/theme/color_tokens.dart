import 'package:flutter/material.dart';

/// "Vivid Indigo" light palette — refresh of the earlier "Quiet Precision"
/// muted-navy theme with a warmer neutral base and a more saturated violet
/// accent.
class LightColors {
  const LightColors._();

  static const background = Color(0xFFFAF9FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF1EEFB);
  static const textPrimary = Color(0xFF1C1B29);
  static const textSecondary = Color(0xFF6E6B85);
  static const textTertiary = Color(0xFFA6A3BC);
  static const divider = Color(0xFFE9E6F5);
  static const accent = Color(0xFF6C5CE7);
  static const accentSoft = Color(0xFFEDE9FE);
}

/// "Vivid Indigo" dark palette. [accentText] is a lightened derivative of
/// [accent] used anywhere the accent appears as text/icon color on a dark
/// surface, so it clears the ~4.5:1 AA contrast threshold for body text.
/// [accent] itself is kept for large fills (buttons, selected-state
/// backgrounds) where that contrast isn't the limiting factor.
class DarkColors {
  const DarkColors._();

  static const background = Color(0xFF15131F);
  static const surface = Color(0xFF1E1B2E);
  static const elevatedSurface = Color(0xFF272440);
  static const textPrimary = Color(0xFFF6F5FA);
  static const textSecondary = Color(0xFFACA9C4);
  static const textTertiary = Color(0xFF716E8C);
  static const divider = Color(0xFF322E4A);
  static const accent = Color(0xFF8B7CF6);
  static const accentText = Color(0xFFB2A6FA);
  static const accentSoft = Color(0xFF2C2750);
}
