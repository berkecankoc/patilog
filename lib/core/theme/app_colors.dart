import 'package:flutter/material.dart';

/// Theme-aware color tokens. Access via `context.colors.xxx` rather than
/// referencing this class's fields as static constants.
/// The actual color values depend on the active brightness.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color background;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;

  const AppColors({
    required this.primary,
    required this.background,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
  });

  static const light = AppColors(
    primary: Color(0xFFFF4500), // H16  S100 B100
    background: Color(0xFFFCF7F5), // H16  S3   B99
    success: Color(0xFF00FF5E), // H142 S100 B100
    onSuccess: Color(0xFF082610), // H142 S80  B15
    warning: Color(0xFFFFBF00), // H45  S100 B100
    onWarning: Color(0xFF261F08), // H45  S80  B15
    danger: Color(0xFFFF1100), // H4   S100 B100
    onDanger: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    primary: Color(0xFFFF4500),
    background: Color(0xFF171414), // H16  S15  B9
    success: Color(0xFF00FF5E),
    onSuccess: Color(0xFF082610),
    warning: Color(0xFFFFBF00),
    onWarning: Color(0xFF261F08),
    danger: Color(0xFFFF1100),
    onDanger: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    Color? primary,
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
