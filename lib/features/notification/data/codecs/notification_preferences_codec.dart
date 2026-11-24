import 'dart:convert';

import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';
import 'package:patilog/features/notification/data/codecs/vaccination_reminder_schedule_codec.dart';

abstract final class NotificationPreferencesCodec {
  static String encode(NotificationPreferences preferences) => jsonEncode({
    'medication_reminders_enabled': preferences.medicationRemindersEnabled,
    'vaccination_reminders_enabled': preferences.vaccinationRemindersEnabled,
    'feeding_reminders_enabled': preferences.feedingRemindersEnabled,
    'vaccination_schedule': VaccinationReminderScheduleCodec.toJson(
      preferences.vaccinationSchedule,
    ),
    'offered_reminder_categories': [
      for (final category in ReminderCategory.values)
        if (preferences.offeredCategories.contains(category)) category.name,
    ],
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
      final offered = decoded['offered_reminder_categories'] ?? const [];
      if (offered is! List || offered.any((name) => name is! String)) {
        throw const FormatException('Invalid offered reminder categories');
      }
      return NotificationPreferences(
        medicationRemindersEnabled: medications,
        vaccinationRemindersEnabled: vaccinations,
        feedingRemindersEnabled: feeding,
        vaccinationSchedule: VaccinationReminderScheduleCodec.fromJson(
          schedule,
        ),
        // Unknown names from a newer app version are ignored.
        offeredCategories: {
          for (final category in ReminderCategory.values)
            if (offered.contains(category.name)) category,
        },
      );
    }
    throw const FormatException('Invalid notification preferences');
  }
}
