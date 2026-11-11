import 'package:equatable/equatable.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/domain/utils/medication_calendar.dart';

enum MedicationStatus { active, upcoming, completed }

final class Medication extends Equatable {
  final String id;
  final String petId;
  final String name;

  /// All periods, ordered by start date, including when reading by linked visit.
  final List<MedicationPeriod> periods;

  Medication({
    required this.id,
    required this.petId,
    required this.name,
    required List<MedicationPeriod> periods,
  }) : periods = List.unmodifiable(
         List<MedicationPeriod>.of(periods)..sort(
           (a, b) => calendarDayNumber(
             a.startDate,
           ).compareTo(calendarDayNumber(b.startDate)),
         ),
       );

  MedicationPeriod? periodOn(DateTime date) {
    for (var index = periods.length - 1; index >= 0; index--) {
      final period = periods[index];
      if (period.isActiveOn(
        date,
        nextPeriodStart: index + 1 < periods.length
            ? periods[index + 1].startDate
            : null,
      )) {
        return period;
      }
    }
    return null;
  }

  MedicationStatus statusOn(DateTime date) {
    if (periodOn(date) != null) return MedicationStatus.active;
    if (periods.any(
      (period) => calendarDayNumber(period.startDate) > calendarDayNumber(date),
    )) {
      return MedicationStatus.upcoming;
    }
    return MedicationStatus.completed;
  }

  @override
  List<Object?> get props => [id, petId, name, periods];
}
