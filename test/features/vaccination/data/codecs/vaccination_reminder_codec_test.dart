import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/vaccination/data/codecs/vaccination_reminder_codec.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';

void main() {
  test('round-trips Custom and Off without conflating them', () {
    for (final settings in [
      const VaccinationReminderSettings.off(),
      VaccinationReminderSettings.custom(VaccinationReminderSchedule()),
      VaccinationReminderSettings.custom(
        VaccinationReminderSchedule(daysBefore: [0], minuteOfDay: 0),
      ),
      VaccinationReminderSettings.custom(
        VaccinationReminderSchedule(daysBefore: [10, 1], minuteOfDay: 1439),
      ),
    ]) {
      expect(
        VaccinationReminderCodec.settingsFromJson(
          VaccinationReminderCodec.settingsToJson(settings),
        ),
        settings,
      );
    }
  });

  test('normalizes order without changing input or accepting duplicates', () {
    final days = [0, 7, 1];
    final decoded = VaccinationReminderCodec.scheduleFromJson({
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
        () => VaccinationReminderCodec.scheduleFromJson(invalid),
        throwsFormatException,
      );
      expect(
        () => VaccinationReminderCodec.settingsFromJson({
          'mode': 'custom',
          'schedule': invalid,
        }),
        throwsFormatException,
      );
    });
  }

  test('rejects missing or unknown modes', () {
    for (final invalid in [
      null,
      [],
      {},
      {'mode': 'default'},
      {'mode': 'custom'},
    ]) {
      expect(
        () => VaccinationReminderCodec.settingsFromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test('rejects invalid domain schedules before encoding', () {
    for (final schedule in [
      VaccinationReminderSchedule(daysBefore: []),
      VaccinationReminderSchedule(daysBefore: [-1]),
      VaccinationReminderSchedule(daysBefore: [1, 1]),
      VaccinationReminderSchedule(minuteOfDay: -1),
      VaccinationReminderSchedule(minuteOfDay: 1440),
    ]) {
      expect(
        () => VaccinationReminderCodec.scheduleToJson(schedule),
        throwsFormatException,
      );
      expect(
        () => VaccinationReminderCodec.settingsToJson(
          VaccinationReminderSettings.custom(schedule),
        ),
        throwsFormatException,
      );
    }
  });
}
