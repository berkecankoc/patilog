import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';

abstract final class VaccinationReminderCodec {
  static Map<String, Object> scheduleToJson(
    VaccinationReminderSchedule schedule,
  ) {
    _validate(schedule.daysBefore, schedule.minuteOfDay);
    return {
      'days_before': schedule.daysBefore,
      'minute_of_day': schedule.minuteOfDay,
    };
  }

  static VaccinationReminderSchedule scheduleFromJson(Object? json) {
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

  static Map<String, Object> settingsToJson(
    VaccinationReminderSettings settings,
  ) => switch (settings.schedule) {
    null => {'mode': 'off'},
    final schedule => {'mode': 'custom', 'schedule': scheduleToJson(schedule)},
  };

  static VaccinationReminderSettings settingsFromJson(Object? json) =>
      switch (json) {
        {'mode': 'off'} => const VaccinationReminderSettings.off(),
        {'mode': 'custom', 'schedule': final schedule} =>
          VaccinationReminderSettings.custom(scheduleFromJson(schedule)),
        _ => throw const FormatException(
          'Invalid vaccination reminder settings',
        ),
      };

  static void _validate(List<int> days, int minute) {
    if (days.isEmpty ||
        days.any((day) => day < 0) ||
        days.toSet().length != days.length ||
        minute < 0 ||
        minute >= 24 * 60) {
      throw const FormatException('Invalid vaccination reminder schedule');
    }
  }
}
