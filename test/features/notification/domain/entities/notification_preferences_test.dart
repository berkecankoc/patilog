import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/vaccination_reminder_schedule.dart';

void main() {
  test(
    'both categories start disabled with the agreed vaccination defaults',
    () {
      final preferences = NotificationPreferences();
      expect(preferences.medicationRemindersEnabled, isFalse);
      expect(preferences.vaccinationRemindersEnabled, isFalse);
      expect(preferences.vaccinationSchedule, VaccinationReminderSchedule());
    },
  );

  test('category choices and vaccination timing are separate preferences', () {
    final initial = NotificationPreferences();
    final medication = NotificationPreferences(
      medicationRemindersEnabled: true,
    );
    final vaccination = NotificationPreferences(
      vaccinationRemindersEnabled: true,
    );
    final timing = NotificationPreferences(
      vaccinationSchedule: VaccinationReminderSchedule(minuteOfDay: 600),
    );
    expect({initial, medication, vaccination, timing}, hasLength(4));
    expect(initial, NotificationPreferences());
  });
}
