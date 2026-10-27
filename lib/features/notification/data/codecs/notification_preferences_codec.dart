import 'dart:convert';

import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/vaccination/data/codecs/vaccination_reminder_codec.dart';

abstract final class NotificationPreferencesCodec {
  static String encode(NotificationPreferences preferences) => jsonEncode({
    'medication_reminders_enabled': preferences.medicationRemindersEnabled,
    'vaccination_reminders_enabled': preferences.vaccinationRemindersEnabled,
    'vaccination_schedule': VaccinationReminderCodec.scheduleToJson(
      preferences.vaccinationSchedule,
    ),
  });

  static NotificationPreferences decode(String value) {
    if (jsonDecode(value) case {
      'medication_reminders_enabled': bool medications,
      'vaccination_reminders_enabled': bool vaccinations,
      'vaccination_schedule': final schedule,
    }) {
      return NotificationPreferences(
        medicationRemindersEnabled: medications,
        vaccinationRemindersEnabled: vaccinations,
        vaccinationSchedule: VaccinationReminderCodec.scheduleFromJson(
          schedule,
        ),
      );
    }
    throw const FormatException('Invalid notification preferences');
  }
}
