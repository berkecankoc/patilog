import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/medication/domain/utils/medication_calendar.dart';

final class CalculateMedicationDoses {
  const CalculateMedicationDoses();

  List<MedicationDose> call({
    required List<Medication> medications,
    required List<MedicationDoseLog> logs,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final results = {
      for (final log in logs)
        (
          log.periodId,
          calendarDayNumber(log.scheduledDate),
          log.scheduledMinute,
        ): log,
    };
    final doses = <MedicationDose>[];
    final last = DateTime.utc(toDate.year, toDate.month, toDate.day);
    // Iterate only the requested calendar range, even for open-ended periods.
    for (
      var day = DateTime.utc(fromDate.year, fromDate.month, fromDate.day);
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      final date = DateTime(day.year, day.month, day.day);
      for (final medication in medications) {
        final period = medication.periodOn(date);
        if (period == null) continue;
        for (final minute in period.doseTimes) {
          if (!period.isScheduledDose(date, minute)) continue;
          doses.add(
            MedicationDose(
              medication: medication,
              period: period,
              scheduledDate: date,
              scheduledMinute: minute,
              log: results[(period.id, calendarDayNumber(date), minute)],
            ),
          );
        }
      }
    }
    doses.sort((a, b) {
      final day = calendarDayNumber(
        a.scheduledDate,
      ).compareTo(calendarDayNumber(b.scheduledDate));
      if (day != 0) return day;
      final minute = a.scheduledMinute.compareTo(b.scheduledMinute);
      if (minute != 0) return minute;
      final name = a.medication.name.toLowerCase().compareTo(
        b.medication.name.toLowerCase(),
      );
      if (name != 0) return name;
      return a.medication.id.compareTo(b.medication.id);
    });
    return List.unmodifiable(doses);
  }
}
