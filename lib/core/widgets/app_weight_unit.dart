import 'package:flutter/widgets.dart';
import 'package:patilog/core/utils/weight_utils.dart';

/// Provides the display unit for weights stored in kilograms.
class AppWeightUnit extends InheritedWidget {
  final WeightUnit unit;

  const AppWeightUnit({super.key, required this.unit, required super.child});

  /// Without an app-level scope, weights stay in kilograms.
  static WeightUnit of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppWeightUnit>()?.unit ??
      WeightUnit.kilogram;

  @override
  bool updateShouldNotify(AppWeightUnit oldWidget) => unit != oldWidget.unit;
}
