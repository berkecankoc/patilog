import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

String feedingAmount(BuildContext context, double grams) => NumberFormat(
  '0.#',
  Localizations.localeOf(context).toLanguageTag(),
).format(grams);

double? parseFeedingAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

String feedingTime(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

int? parseFeedingTime(String text) {
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text.trim())) return null;
  final values = text.trim().split(':').map(int.parse).toList();
  return values[0] * 60 + values[1];
}

String? validateFeedingAmount(BuildContext context, String? value) {
  final strings = AppLocalizations.of(context);
  final amount = parseFeedingAmount(value ?? '');
  if (amount == null || !amount.isFinite || amount <= 0) {
    return strings.feedingAmountInvalid;
  }
  if (!RegExp(r'^(?:\d+(?:[.,]\d)?|[.,]\d)$').hasMatch(value!.trim())) {
    return strings.feedingPrecision;
  }
  return null;
}
