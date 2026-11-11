import 'dart:convert';

import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/data/codecs/vaccination_reminder_schedule_codec.dart';

abstract final class NotificationPreferencesCodec {
  static String encode(NotificationPreferences preferences) => jsonEncode({
    'medication_reminders_enabled': preferences.medicationRemindersEnabled,
    'vaccination_reminders_enabled': preferences.vaccinationRemindersEnabled,
    'feeding_reminders_enabled': preferences.feedingRemindersEnabled,
    'vaccination_schedule': VaccinationReminderScheduleCodec.toJson(
      preferences.vaccinationSchedule,
    ),
  });

  static NotificationPreferences decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded case {
      'medication_reminders_enabled': bool medications,
      'vaccination_reminders_enabled': bool vaccinations,
      'vaccination_schedule': final schedule,
    }) {
      final feeding = decoded.containsKey('feeding_reminders_enabled')
          ? decoded['feeding_reminders_enabled']
          : false;
      if (feeding is! bool) {
        throw const FormatException('Invalid feeding preference');
      }
      return NotificationPreferences(
        medicationRemindersEnabled: medications,
        vaccinationRemindersEnabled: vaccinations,
        feedingRemindersEnabled: feeding,
        vaccinationSchedule: VaccinationReminderScheduleCodec.fromJson(
          schedule,
        ),
      );
    }
    throw const FormatException('Invalid notification preferences');
  }
}
