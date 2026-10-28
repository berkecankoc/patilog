import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/notification/data/codecs/vaccination_reminder_schedule_codec.dart';
import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';

void main() {
  test('round-trips the shared schedule', () {
    for (final schedule in [
      VaccinationReminderSchedule(),
      VaccinationReminderSchedule(daysBefore: [0], minuteOfDay: 0),
      VaccinationReminderSchedule(daysBefore: [7, 1], minuteOfDay: 1439),
    ]) {
      expect(
        VaccinationReminderScheduleCodec.fromJson(
          VaccinationReminderScheduleCodec.toJson(schedule),
        ),
        schedule,
      );
    }
  });

  test('rejects more than three days and days outside the preset choices', () {
    for (final days in [
      [0, 1, 3, 7],
      [2],
      [30],
    ]) {
      expect(
        () => VaccinationReminderScheduleCodec.toJson(
          VaccinationReminderSchedule(daysBefore: days),
        ),
        throwsFormatException,
      );
      expect(
        () => VaccinationReminderScheduleCodec.fromJson({
          'days_before': days,
          'minute_of_day': 540,
        }),
        throwsFormatException,
      );
    }
  });

  test('normalizes order without changing input or accepting duplicates', () {
    final days = [0, 7, 1];
    final decoded = VaccinationReminderScheduleCodec.fromJson({
      'days_before': days,
      'minute_of_day': 540,
    });
    expect(decoded.daysBefore, [7, 1, 0]);
    expect(days, [0, 7, 1]);
    days.add(10);
    expect(decoded.daysBefore, [7, 1, 0]);
    expect(() => decoded.daysBefore.add(10), throwsUnsupportedError);
  });

  final invalidSchedules = <Object?>[
    null,
    [],
    {},
    {
      'days_before': [1],
    },
    {'minute_of_day': 540},
    {'days_before': [], 'minute_of_day': 540},
    {
      'days_before': [-1],
      'minute_of_day': 540,
    },
    {
      'days_before': [1, 1],
      'minute_of_day': 540,
    },
    {
      'days_before': ['1'],
      'minute_of_day': 540,
    },
    {
      'days_before': [1.0],
      'minute_of_day': 540,
    },
    {
      'days_before': [null],
      'minute_of_day': 540,
    },
    {
      'days_before': [0],
      'minute_of_day': -1,
    },
    {
      'days_before': [0],
      'minute_of_day': 1440,
    },
    {
      'days_before': [0],
      'minute_of_day': 540.0,
    },
    {
      'days_before': [0],
      'minute_of_day': '540',
    },
  ];
  for (final (index, invalid) in invalidSchedules.indexed) {
    test('rejects malformed schedule $index rather than defaulting', () {
      expect(
        () => VaccinationReminderScheduleCodec.fromJson(invalid),
        throwsFormatException,
      );
    });
  }

  test('rejects invalid domain schedules before encoding', () {
    for (final schedule in [
      VaccinationReminderSchedule(daysBefore: []),
      VaccinationReminderSchedule(daysBefore: [-1]),
      VaccinationReminderSchedule(daysBefore: [1, 1]),
      VaccinationReminderSchedule(minuteOfDay: -1),
      VaccinationReminderSchedule(minuteOfDay: 1440),
    ]) {
      expect(
        () => VaccinationReminderScheduleCodec.toJson(schedule),
        throwsFormatException,
      );
    }
  });
}
