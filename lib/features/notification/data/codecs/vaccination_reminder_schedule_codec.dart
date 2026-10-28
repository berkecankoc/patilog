import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';

abstract final class VaccinationReminderScheduleCodec {
  static Map<String, Object> toJson(VaccinationReminderSchedule schedule) {
    _validate(schedule.daysBefore, schedule.minuteOfDay);
    return {
      'days_before': schedule.daysBefore,
      'minute_of_day': schedule.minuteOfDay,
    };
  }

  static VaccinationReminderSchedule fromJson(Object? json) {
    if (json case {
      'days_before': List<Object?> days,
      'minute_of_day': int minute,
    } when days.every((day) => day is int)) {
      final offsets = days.cast<int>();
      _validate(offsets, minute);
      return VaccinationReminderSchedule(
        daysBefore: offsets,
        minuteOfDay: minute,
      );
    }
    throw const FormatException('Invalid vaccination reminder schedule');
  }

  static void _validate(List<int> days, int minute) {
    if (days.isEmpty ||
        days.length > VaccinationReminderSchedule.maxReminderDays ||
        days.any(
          (day) =>
              !VaccinationReminderSchedule.availableDaysBefore.contains(day),
        ) ||
        days.toSet().length != days.length ||
        minute < 0 ||
        minute >= 24 * 60) {
      throw const FormatException('Invalid vaccination reminder schedule');
    }
  }
}
