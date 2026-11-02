import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/notification/data/data_sources/notification_preferences_local_data_source.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPreferences extends Mock implements SharedPreferencesAsync {}

void main() {
  const key = 'notification.preferences';
  late MockPreferences preferences;
  late NotificationPreferencesLocalDataSourceImpl source;
  late Map<String, Object?> values;
  final custom = NotificationPreferences(
    medicationRemindersEnabled: true,
    vaccinationRemindersEnabled: true,
    feedingRemindersEnabled: true,
    vaccinationSchedule: VaccinationReminderSchedule(
      daysBefore: [7, 3, 0],
      minuteOfDay: 18 * 60 + 30,
    ),
  );

  setUp(() {
    preferences = MockPreferences();
    source = NotificationPreferencesLocalDataSourceImpl(preferences);
    values = {'settings.theme_preference': 'dark'};
    when(
      () => preferences.getAll(allowList: {key}),
    ).thenAnswer((_) async => {if (values.containsKey(key)) key: values[key]});
    when(() => preferences.setString(key, any())).thenAnswer((call) async {
      values[key] = call.positionalArguments[1] as String;
    });
  });

  test('missing settings use disabled defaults without writing', () async {
    expect(await source.getPreferences(), NotificationPreferences());
    expect(values, {'settings.theme_preference': 'dark'});
    verify(() => preferences.getAll(allowList: {key})).called(1);
    verifyNoMoreInteractions(preferences);
  });

  test(
    'existing preferences retain their timing and default feeding to off',
    () async {
      values[key] = jsonEncode({
        'medication_reminders_enabled': true,
        'vaccination_reminders_enabled': true,
        'vaccination_schedule': {
          'days_before': [3, 1, 0],
          'minute_of_day': 540,
        },
      });
      final loaded = await source.getPreferences();
      expect(loaded.feedingRemindersEnabled, isFalse);
      expect(loaded.medicationRemindersEnabled, isTrue);
      expect(loaded.vaccinationSchedule.minuteOfDay, 540);
      verifyNever(() => preferences.setString(any(), any()));
    },
  );

  test(
    'round-trips defaults and custom settings in one isolated value',
    () async {
      for (final value in [NotificationPreferences(), custom]) {
        await source.savePreferences(value);
        expect(
          values.keys,
          unorderedEquals(['settings.theme_preference', key]),
        );
        expect(values['settings.theme_preference'], 'dark');
        expect(
          await NotificationPreferencesLocalDataSourceImpl(
            preferences,
          ).getPreferences(),
          value,
        );
      }
      verify(() => preferences.setString(key, any())).called(2);
    },
  );

  test(
    'retains independent category choices and timing while disabled',
    () async {
      final disabled = NotificationPreferences(
        medicationRemindersEnabled: true,
        vaccinationSchedule: custom.vaccinationSchedule,
      );
      await source.savePreferences(disabled);
      expect(await source.getPreferences(), disabled);
      final vaccinationOnly = NotificationPreferences(
        vaccinationRemindersEnabled: true,
        vaccinationSchedule: custom.vaccinationSchedule,
      );
      await source.savePreferences(vaccinationOnly);
      expect(await source.getPreferences(), vaccinationOnly);
    },
  );

  for (final (index, corrupt) in <Object>[
    42,
    true,
    '',
    '{',
    'null',
    '[]',
    '{}',
    jsonEncode({
      'medication_reminders_enabled': 'true',
      'vaccination_reminders_enabled': true,
      'vaccination_schedule': {
        'days_before': [0],
        'minute_of_day': 540,
      },
    }),
    jsonEncode({
      'medication_reminders_enabled': true,
      'vaccination_reminders_enabled': 1,
      'vaccination_schedule': {
        'days_before': [0],
        'minute_of_day': 540,
      },
    }),
    jsonEncode({
      'medication_reminders_enabled': true,
      'vaccination_reminders_enabled': true,
      'vaccination_schedule': null,
    }),
    jsonEncode({
      'medication_reminders_enabled': true,
      'vaccination_reminders_enabled': true,
      'vaccination_schedule': {
        'days_before': [0, 0],
        'minute_of_day': 540,
      },
    }),
  ].indexed) {
    test(
      'reports corrupt stored preferences $index without replacing them',
      () async {
        values[key] = corrupt;
        await expectLater(
          source.getPreferences(),
          throwsA(isA<PreferencesStorageException>()),
        );
        expect(values[key], corrupt);
        verifyNever(() => preferences.setString(any(), any()));
      },
    );
  }

  test('reports platform read failure rather than disabled defaults', () async {
    when(() => preferences.getAll(allowList: {key})).thenThrow(
      PlatformException(code: 'read_failed', message: 'Native details'),
    );
    await expectLater(
      source.getPreferences(),
      throwsA(isA<PreferencesStorageException>()),
    );
  });

  test('a failed write leaves the preceding saved settings intact', () async {
    await source.savePreferences(custom);
    when(
      () => preferences.setString(key, any()),
    ).thenThrow(PlatformException(code: 'write_failed'));
    await expectLater(
      source.savePreferences(NotificationPreferences()),
      throwsA(isA<PreferencesStorageException>()),
    );
    expect(await source.getPreferences(), custom);
  });

  test('invalid schedules fail before writing any settings', () async {
    await source.savePreferences(custom);
    clearInteractions(preferences);
    for (final schedule in [
      VaccinationReminderSchedule(daysBefore: []),
      VaccinationReminderSchedule(daysBefore: [-1]),
      VaccinationReminderSchedule(daysBefore: [1, 1]),
      VaccinationReminderSchedule(daysBefore: [0, 1, 3, 7]),
      VaccinationReminderSchedule(daysBefore: [2]),
      VaccinationReminderSchedule(minuteOfDay: 1440),
    ]) {
      await expectLater(
        source.savePreferences(
          NotificationPreferences(vaccinationSchedule: schedule),
        ),
        throwsA(isA<PreferencesStorageException>()),
      );
    }
    verifyZeroInteractions(preferences);
    expect(await source.getPreferences(), custom);
  });

  test('awaits the completed platform write', () async {
    final write = Completer<void>();
    when(
      () => preferences.setString(key, any()),
    ).thenAnswer((_) => write.future);
    var completed = false;
    final saved = source.savePreferences(custom).then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    write.complete();
    await saved;
    expect(completed, isTrue);
  });
}
