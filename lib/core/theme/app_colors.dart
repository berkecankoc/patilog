import 'package:flutter/material.dart';

/// Theme-aware color tokens. Access via `context.colors.xxx` rather than
/// referencing this class's fields as static constants.
/// The actual color values depend on the active brightness.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  static const brandPrimary = Color(0xFFFF4500);

  final Color primary;
  final Color onPrimary;
  final Color actionForeground;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color background;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;

  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.actionForeground,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.background,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
  });

  static const light = AppColors(
    primary: brandPrimary,
    onPrimary: Color(0xFF1D0502),
    actionForeground: Color(0xFFC03304),
    background: Color(0xFFFEFBFA),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF262322),
    textSecondary: Color(0xFF5B5452),
    border: Color(0xFF786F6D),
    success: Color(0xFF10642D),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFFF59E0B),
    onWarning: Color(0xFF462A02),
    danger: Color(0xFFB43332),
    onDanger: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    primary: brandPrimary,
    onPrimary: Color(0xFF1D0502),
    actionForeground: Color(0xFFFFAC96),
    background: Color(0xFF141110),
    surface: Color(0xFF262322),
    textPrimary: Color(0xFFFAF8F7),
    textSecondary: Color(0xFFB7B1B0),
    border: Color(0xFF978F8E),
    success: Color(0xFF96E4A6),
    onSuccess: Color(0xFF073817),
    warning: Color(0xFFFFCB8F),
    onWarning: Color(0xFF462A02),
    danger: Color(0xFFFFA59C),
    onDanger: Color(0xFF4A1312),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? actionForeground,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? background,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      actionForeground: actionForeground ?? this.actionForeground,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      background: background ?? this.background,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      actionForeground: Color.lerp(
        actionForeground,
        other.actionForeground,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      background: Color.lerp(background, other.background, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
