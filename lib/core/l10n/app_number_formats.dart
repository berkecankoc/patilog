import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:petlytics/core/utils/weight_utils.dart';

String _decimalSeparator(Locale locale) =>
    NumberFormat.decimalPattern(locale.toLanguageTag()).symbols.DECIMAL_SEP;

String localizedWeight(double weight, Locale locale) =>
    formatWeight(weight).replaceFirst('.', _decimalSeparator(locale));

// Keep integer minor units exact, including amounts beyond double precision.
String localizedAmount(int minorUnits, Locale locale) =>
    '${minorUnits ~/ 100}${_decimalSeparator(locale)}${(minorUnits % 100).toString().padLeft(2, '0')}';
