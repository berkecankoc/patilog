import 'package:equatable/equatable.dart';

final class VaccinationReminderSchedule extends Equatable {
  static const availableDaysBefore = [0, 1, 3, 7];
  static const maxReminderDays = 3;

  /// Calendar days before vaccination, descending; zero means the same day.
  /// Writes require 1–3 unique offsets from [availableDaysBefore].
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
