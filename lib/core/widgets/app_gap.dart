import 'package:flutter/widgets.dart';
import 'package:petlytics/core/theme/app_spacing.dart';

abstract final class HorizontalGap {
  static const xs = SizedBox(width: AppSpacing.xs);
  static const sm = SizedBox(width: AppSpacing.sm);
  static const md = SizedBox(width: AppSpacing.md);
  static const lg = SizedBox(width: AppSpacing.lg);
  static const xl = SizedBox(width: AppSpacing.xl);
  static const xxl = SizedBox(width: AppSpacing.xxl);
}

abstract final class VerticalGap {
  static const xs = SizedBox(height: AppSpacing.xs);
  static const sm = SizedBox(height: AppSpacing.sm);
  static const md = SizedBox(height: AppSpacing.md);
  static const lg = SizedBox(height: AppSpacing.lg);
  static const xl = SizedBox(height: AppSpacing.xl);
  static const xxl = SizedBox(height: AppSpacing.xxl);
}
