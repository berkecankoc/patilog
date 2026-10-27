import 'package:equatable/equatable.dart';

final class VaccinationReminderSchedule extends Equatable {
  /// Calendar days before vaccination, descending; zero means the same day.
  /// Writes require nonempty, unique, nonnegative offsets.
  final List<int> daysBefore;

  /// Local minutes since midnight, in 0–1439.
  final int minuteOfDay;

  VaccinationReminderSchedule({
    List<int> daysBefore = const [3, 1, 0],
    this.minuteOfDay = 9 * 60,
  }) : daysBefore = List.unmodifiable(
         List<int>.of(daysBefore)..sort((a, b) => b.compareTo(a)),
       );

  @override
  List<Object?> get props => [daysBefore, minuteOfDay];
}

final class VaccinationReminderSettings extends Equatable {
  final VaccinationReminderSchedule? schedule;

  const VaccinationReminderSettings.custom(
    VaccinationReminderSchedule this.schedule,
  );

  const VaccinationReminderSettings.off() : schedule = null;

  bool get isEnabled => schedule != null;

  @override
  List<Object?> get props => [schedule];
}
