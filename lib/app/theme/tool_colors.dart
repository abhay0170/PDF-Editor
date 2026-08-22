import 'package:flutter/material.dart';

/// Per-tool accent colors for the home screen's tool grid — distinct from
/// the single global `accent` in [LightColors]/[DarkColors] (used
/// everywhere else in the UI), so each shortcut reads as its own tile
/// rather than a uniform list. Same values in light and dark mode; each
/// tile derives its badge background from these via a low-alpha tint.
class ToolColors {
  const ToolColors._();

  static const scan = Color(0xFF3B82F6);
  static const merge = Color(0xFFF97316);
  static const split = Color(0xFF22C55E);
  static const compress = Color(0xFF0EA5E9);
  static const extract = Color(0xFF8B5CF6);
  static const rotate = Color(0xFFEC4899);
  static const protect = Color(0xFF16A34A);
  static const convert = Color(0xFF2563EB);
  static const watermark = Color(0xFFF59E0B);
  static const sign = Color(0xFF14B8A6);
  static const ocr = Color(0xFFEF4444);
  static const more = Color(0xFF6B7280);
}
