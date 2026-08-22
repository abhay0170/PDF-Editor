import 'package:flutter/material.dart';

/// Exact "Quiet Precision" light palette.
class LightColors {
  const LightColors._();

  static const background = Color(0xFFF7F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF1F1EF);
  static const textPrimary = Color(0xFF18181A);
  static const textSecondary = Color(0xFF6F6F73);
  static const textTertiary = Color(0xFFA2A2A7);
  static const divider = Color(0xFFE6E6E4);
  static const accent = Color(0xFF303A63);
  static const accentSoft = Color(0xFFE9EBF4);
}

/// Exact "Quiet Precision" dark palette. [accentText] is a lightened
/// derivative of [accent] (HSL lightness raised from ~26% to ~58%) used
/// anywhere the accent appears as text/icon color on a dark surface — raw
/// #303A63 measures ~2.1:1 contrast against #121214, below the ~4.5:1 AA
/// threshold for body text. [accent] itself is kept for large fills
/// (buttons, selected-state backgrounds) where that contrast isn't the
/// limiting factor.
class DarkColors {
  const DarkColors._();

  static const background = Color(0xFF121214);
  static const surface = Color(0xFF1A1A1C);
  static const elevatedSurface = Color(0xFF222225);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFA1A1A6);
  static const textTertiary = Color(0xFF6C6C70);
  static const divider = Color(0xFF2D2D30);
  static const accent = Color(0xFF303A63);
  static const accentText = Color(0xFF8B93C4);
  static const accentSoft = Color(0xFF23273A);
}
