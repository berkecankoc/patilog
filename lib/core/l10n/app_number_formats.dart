import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:patilog/core/utils/weight_utils.dart';

String _decimalSeparator(Locale locale) =>
    NumberFormat.decimalPattern(locale.toLanguageTag()).symbols.DECIMAL_SEP;

String localizedWeight(double weight, Locale locale) =>
    formatWeight(weight).replaceFirst('.', _decimalSeparator(locale));

/// Formats stored kilograms in [unit] without the unit symbol.
String localizedWeightIn(double kilograms, WeightUnit unit, Locale locale) =>
    localizedWeight(fromKilograms(kilograms, unit), locale);

String localizedWeightWithUnit(
  double kilograms,
  WeightUnit unit,
  Locale locale,
) => '${localizedWeightIn(kilograms, unit, locale)} ${unit.symbol}';

// Keep integer minor units exact, including amounts beyond double precision.
String localizedAmount(int minorUnits, Locale locale) =>
    '${minorUnits ~/ 100}${_decimalSeparator(locale)}${(minorUnits % 100).toString().padLeft(2, '0')}';
