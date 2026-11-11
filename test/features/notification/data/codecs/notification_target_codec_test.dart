import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/notification/data/codecs/notification_target_codec.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';

void main() {
  test(
    'round-trips typed dose and vaccination identities without text/URLs',
    () {
      for (final target in [
        MedicationDoseNotificationTarget(
          petId: 'pet,1',
          medicationId: 'medicine"2',
          periodId: 'period/3',
          scheduledDate: DateTime.utc(2030, 1, 2, 23),
          scheduledMinute: 1439,
        ),
        const VaccinationNotificationTarget(
          petId: 'pet1',
          vaccinationId: 'vax1',
          daysBefore: 0,
        ),
        FeedingMealNotificationTarget(
          petId: 'pet1',
          planId: 'plan1',
          mealId: 'meal1',
          scheduledDate: DateTime(2030, 1, 2),
          scheduledMinute: 720,
        ),
      ]) {
        final encoded = NotificationTargetCodec.encode(target);
        expect(NotificationTargetCodec.isOwned(encoded), isTrue);
        expect(NotificationTargetCodec.decode(encoded), target);
      }
    },
  );

  for (final (index, invalid) in <Object?>[
    null,
    {},
    [],
    ['unknown', 'pet1'],
    ['feeding', 'pet1', 'plan1', 'meal1', 2030, 2, 29, 720],
    ['feeding', 'pet1', 'plan1', '', 2030, 1, 1, 720],
    ['feeding', 'pet1', 'plan1', 'meal1', 2030, 1, 1, 1440],
    ['vaccination', 'pet1', 'vax1', -1],
    ['vaccination', '', 'vax1', 0],
    ['vaccination', 'pet1', '  ', 0],
    ['vaccination', 'pet1', 'vax1', 1.0],
    ['vaccination', 'pet1', 'vax1', 1, 'extra'],
    ['dose', 'pet1', 'med1', 'period1', 2030, 2, 29, 540],
    ['dose', 'pet1', 'med1', 'period1', 2030, 13, 1, 540],
    ['dose', 'pet1', 'med1', 'period1', 10000, 1, 1, 540],
    ['dose', 'pet1', 'med1', 'period1', 2030, 1, 1, -1],
    ['dose', 'pet1', 'med1', 'period1', 2030, 1, 1, 1440],
    ['dose', 'pet1', 'med1', 'period1', 2030, 1, 1, '540'],
  ].indexed) {
    test('ignores malformed owned payload $index', () {
      final payload = 'patilog.reminder.v1:${jsonEncode(invalid)}';
      expect(NotificationTargetCodec.isOwned(payload), isTrue);
      expect(NotificationTargetCodec.decode(payload), isNull);
    });
  }

  test('ignores absent, foreign, unknown-version and truncated payloads', () {
    for (final payload in [
      null,
      '',
      'other',
      'patilog.reminder.v2:[]',
      'patilog.reminder.v1:{',
    ]) {
      expect(NotificationTargetCodec.decode(payload), isNull);
    }
  });

  test('rejects invalid domain targets before encoding', () {
    expect(
      () => NotificationTargetCodec.encode(
        const VaccinationNotificationTarget(
          petId: '',
          vaccinationId: 'vax',
          daysBefore: 0,
        ),
      ),
      throwsFormatException,
    );
  });
}
