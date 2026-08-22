import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'radii.dart';
import 'typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(
    brightness: Brightness.light,
    background: LightColors.background,
    surface: LightColors.surface,
    surfaceSecondary: LightColors.surfaceSecondary,
    textPrimary: LightColors.textPrimary,
    textSecondary: LightColors.textSecondary,
    divider: LightColors.divider,
    accent: LightColors.accent,
    accentOnSurface: LightColors.accent,
    accentSoft: LightColors.accentSoft,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    background: DarkColors.background,
    surface: DarkColors.surface,
    surfaceSecondary: DarkColors.elevatedSurface,
    textPrimary: DarkColors.textPrimary,
    textSecondary: DarkColors.textSecondary,
    divider: DarkColors.divider,
    accent: DarkColors.accent,
    accentOnSurface: DarkColors.accentText,
    accentSoft: DarkColors.accentSoft,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceSecondary,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
    required Color accent,
    required Color accentOnSurface,
    required Color accentSoft,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accentSoft,
      onSecondary: accentOnSurface,
      surface: surface,
      onSurface: textPrimary,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
    );

    final textTheme = TextTheme(
      headlineSmall: AppTypography.screenTitle.copyWith(color: textPrimary),
      titleLarge: AppTypography.sectionTitle.copyWith(color: textPrimary),
      titleMedium: AppTypography.documentTitle.copyWith(color: textPrimary),
      bodyLarge: AppTypography.body.copyWith(color: textPrimary),
      bodyMedium: AppTypography.secondary.copyWith(color: textSecondary),
      bodySmall: AppTypography.metadata.copyWith(color: textSecondary),
      labelSmall: AppTypography.tiny.copyWith(color: textSecondary),
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.sectionTitle.copyWith(color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      iconTheme: IconThemeData(color: textPrimary, size: 22),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: divider,
      listTileTheme: ListTileThemeData(iconColor: textSecondary, textColor: textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: Radii.mediumRadius,
          borderSide: BorderSide.none,
        ),
        hintStyle: AppTypography.body.copyWith(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: Radii.mediumRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentOnSurface,
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: Radii.largeRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.largeRadius,
          side: BorderSide(color: divider),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accentSoft,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.tiny.copyWith(color: textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accentOnSurface : textSecondary,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : divider,
        ),
      ),
    );
  }
}
