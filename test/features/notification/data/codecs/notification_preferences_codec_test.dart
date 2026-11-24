import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/notification/data/codecs/notification_preferences_codec.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';

void main() {
  test('offered categories round-trip with the other preferences', () {
    final preferences = NotificationPreferences(
      medicationRemindersEnabled: true,
      offeredCategories: {
        ReminderCategory.feeding,
        ReminderCategory.medication,
      },
    );
    expect(
      NotificationPreferencesCodec.decode(
        NotificationPreferencesCodec.encode(preferences),
      ),
      preferences,
    );
  });

  test('settings saved before offers existed have no offered categories', () {
    final stored = NotificationPreferencesCodec.encode(
      NotificationPreferences(vaccinationRemindersEnabled: true),
    );
    final legacy = Map.of(jsonDecode(stored) as Map<String, Object?>)
      ..remove('offered_reminder_categories');
    final decoded = NotificationPreferencesCodec.decode(jsonEncode(legacy));
    expect(decoded.offeredCategories, isEmpty);
    expect(decoded.vaccinationRemindersEnabled, isTrue);
  });

  test('unknown category names are ignored and invalid values rejected', () {
    final base = jsonDecode(
      NotificationPreferencesCodec.encode(NotificationPreferences()),
    ) as Map<String, Object?>;
    String withOffered(Object? value) =>
        jsonEncode({...base, 'offered_reminder_categories': value});
    expect(
      NotificationPreferencesCodec.decode(withOffered(['feeding', 'grooming']))
          .offeredCategories,
      {ReminderCategory.feeding},
    );
    expect(
      () => NotificationPreferencesCodec.decode(withOffered('feeding')),
      throwsFormatException,
    );
    expect(
      () => NotificationPreferencesCodec.decode(withOffered([1])),
      throwsFormatException,
    );
  });
}
