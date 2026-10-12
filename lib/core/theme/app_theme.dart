import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light =>
      _build(brightness: Brightness.light, colors: AppColors.light);

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, colors: AppColors.dark);

  static ThemeData _build({
    required Brightness brightness,
    required AppColors colors,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      error: colors.danger,
      onError: colors.onDanger,
      surface: colors.surface,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: brightness == Brightness.light
          ? const Color(0xFFFAF8F7)
          : const Color(0xFF2B2726),
      surfaceContainerHigh: brightness == Brightness.light
          ? const Color(0xFFF3EEEB)
          : const Color(0xFF302B29),
      surfaceContainerHighest: brightness == Brightness.light
          ? const Color(0xFFECE5E1)
          : const Color(0xFF3F3A39),
      outlineVariant: brightness == Brightness.light
          ? const Color(0xFFD8D4D3)
          : const Color(0xFF4B4543),
      primaryContainer: brightness == Brightness.light
          ? const Color(0xFFFFD2C6)
          : const Color(0xFF4E1304),
      onPrimaryContainer: brightness == Brightness.light
          ? const Color(0xFF852305)
          : const Color(0xFFFFD2C6),
    );

    const defaultRadius = BorderRadius.all(Radius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],

      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      buttonTheme: const ButtonThemeData(alignedDropdown: true),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: defaultRadius),
          elevation: 0,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.actionForeground),
      ),

      textSelectionTheme: TextSelectionThemeData(cursorColor: colors.primary),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.actionForeground,
          side: BorderSide(color: colors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: defaultRadius),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? colorScheme.surfaceContainer
            : colorScheme.surfaceContainerHigh,
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? colors.danger
                : states.contains(WidgetState.focused)
                ? colors.primary
                : colors.textSecondary,
          ),
        ),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: defaultRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: defaultRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: defaultRadius,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: defaultRadius,
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: defaultRadius,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: defaultRadius),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
