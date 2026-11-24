import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';
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

  test(
    'answering an offer records it and enables only the accepted category',
    () {
      final schedule = VaccinationReminderSchedule(minuteOfDay: 600);
      final initial = NotificationPreferences(
        vaccinationRemindersEnabled: true,
        vaccinationSchedule: schedule,
        offeredCategories: {ReminderCategory.vaccination},
      );
      final accepted = initial.answerOffer(
        ReminderCategory.feeding,
        accepted: true,
      );
      expect(accepted.feedingRemindersEnabled, isTrue);
      expect(accepted.medicationRemindersEnabled, isFalse);
      expect(accepted.vaccinationRemindersEnabled, isTrue);
      expect(accepted.vaccinationSchedule, schedule);
      expect(accepted.offeredCategories, {
        ReminderCategory.vaccination,
        ReminderCategory.feeding,
      });
      final declined = initial.answerOffer(
        ReminderCategory.medication,
        accepted: false,
      );
      expect(declined.isEnabled(ReminderCategory.medication), isFalse);
      expect(declined.isEnabled(ReminderCategory.vaccination), isTrue);
      expect(declined.offeredCategories, contains(ReminderCategory.medication));
    },
  );

  test('offered categories compare independently of insertion order', () {
    expect(
      NotificationPreferences(
        offeredCategories: {
          ReminderCategory.feeding,
          ReminderCategory.medication,
        },
      ),
      NotificationPreferences(
        offeredCategories: {
          ReminderCategory.medication,
          ReminderCategory.feeding,
        },
      ),
    );
    expect(
      NotificationPreferences(),
      isNot(
        NotificationPreferences(offeredCategories: {ReminderCategory.feeding}),
      ),
    );
  });
}
