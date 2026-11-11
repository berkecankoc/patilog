import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';
import 'package:flutter/material.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/domain/utils/medication_calendar.dart';

String formatDoseTime(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

int? parseDoseTime(String text) {
  final value = text.trim();
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) return null;
  return int.parse(value.substring(0, 2)) * 60 + int.parse(value.substring(3));
}

String medicationFrequency(AppLocalizations strings, MedicationPeriod period) =>
    period.intervalDays == 1
    ? strings.daily
    : strings.medicationEveryDays(period.intervalDays);

String medicationSchedule(AppLocalizations strings, MedicationPeriod period) =>
    strings.medicationScheduleSummary(
      medicationFrequency(strings, period),
      period.doseTimes.map(formatDoseTime).join(', '),
    );

String medicationActionError(
  AppLocalizations strings,
  MedicationAction? action,
) => switch (action) {
  DeleteMedicationAction() => strings.medicationDeleteFailed,
  DeleteMedicationPeriodAction() => strings.scheduleDeleteFailed,
  ClearMedicationDoseAction() => strings.doseClearFailed,
  SaveMedicationDoseAction() => strings.doseSaveFailed,
  null => strings.medicationsLoadFailed,
};

extension MedicationDisplay on Medication {
  MedicationPeriod? pendingPeriod(DateTime now) => periods
      .where(
        (period) =>
            calendarDayNumber(period.startDate) > calendarDayNumber(now),
      )
      .firstOrNull;

  MedicationPeriod periodToEdit(DateTime now) =>
      pendingPeriod(now) ?? periodOn(now) ?? periods.last;

  DateTime? effectiveEnd(MedicationPeriod period) {
    final index = periods.indexWhere((item) => item.id == period.id);
    final next = index >= 0 && index + 1 < periods.length
        ? periods[index + 1].startDate
        : null;
    if (next == null) return period.endDate;
    final boundary = DateTime(next.year, next.month, next.day - 1);
    return period.endDate == null ||
            calendarDayNumber(boundary) < calendarDayNumber(period.endDate!)
        ? boundary
        : period.endDate;
  }
}

String medicationDateRange(
  BuildContext context,
  Medication medication,
  MedicationPeriod period,
) {
  final dates = MaterialLocalizations.of(context);
  final end = medication.effectiveEnd(period);
  if (end != null && DateUtils.isSameDay(period.startDate, end)) {
    return dates.formatShortDate(period.startDate);
  }
  return AppLocalizations.of(context).dateRange(
    dates.formatShortDate(period.startDate),
    end == null
        ? AppLocalizations.of(context).noEndDate
        : dates.formatShortDate(end),
  );
}
