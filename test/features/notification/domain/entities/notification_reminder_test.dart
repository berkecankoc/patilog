import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/notification/domain/entities/notification_reminder.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';

void main() {
  const target = VaccinationNotificationTarget(
    petId: 'pet',
    vaccinationId: 'vaccination',
    daysBefore: 3,
  );
  NotificationReminder reminder({
    DateTime? date,
    int minute = 540,
    String title = 'Simba',
    String body = 'Vaccination reminder',
  }) => NotificationReminder(
    target: target,
    scheduledDate: date ?? DateTime(2026, 10, 27),
    scheduledMinute: minute,
    title: title,
    body: body,
  );

  test(
    'calendar date equality ignores clock/UTC flags but respects the day',
    () {
      expect(reminder(date: DateTime.utc(2026, 10, 27, 23)), reminder());
      expect(reminder(date: DateTime(2026, 10, 28)), isNot(reminder()));
    },
  );

  test(
    'changed timing or text updates the reminder without changing its target',
    () {
      final initial = reminder();
      for (final updated in [
        reminder(date: DateTime(2026, 10, 28)),
        reminder(minute: 600),
        reminder(title: 'New name'),
        reminder(body: 'Updated reminder'),
      ]) {
        expect(updated, isNot(initial));
        expect(updated.target.identityKey, initial.target.identityKey);
      }
    },
  );
}
