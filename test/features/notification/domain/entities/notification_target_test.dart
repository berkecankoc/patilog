import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';

void main() {
  MedicationDoseNotificationTarget dose({
    String pet = 'pet',
    String medication = 'medicine',
    String period = 'period',
    DateTime? day,
    int minute = 540,
  }) => MedicationDoseNotificationTarget(
    petId: pet,
    medicationId: medication,
    periodId: period,
    scheduledDate: day ?? DateTime(2026, 10, 27),
    scheduledMinute: minute,
  );

  test(
    'dose identity uses calendar components without a timezone conversion',
    () {
      final local = dose();
      final utc = dose(day: DateTime.utc(2026, 10, 27, 23));
      expect(utc, local);
      expect(utc.identityKey, local.identityKey);
      expect(
        local.identityKey,
        '["dose","pet","medicine","period",2026,10,27,540]',
      );
    },
  );

  test(
    'owner, medication, period, day and minute distinguish dose targets',
    () {
      final targets = [
        dose(),
        dose(pet: 'other'),
        dose(medication: 'other'),
        dose(period: 'other'),
        dose(day: DateTime(2026, 10, 28)),
        dose(minute: 600),
      ];
      expect(targets.toSet(), hasLength(targets.length));
      expect(
        targets.map((target) => target.identityKey).toSet(),
        hasLength(targets.length),
      );
    },
  );

  test('each vaccination offset has a stable, distinct source identity', () {
    final targets = [
      for (final offset in [3, 1, 0])
        VaccinationNotificationTarget(
          petId: 'pet',
          vaccinationId: 'vaccine',
          daysBefore: offset,
        ),
    ];
    expect(targets.map((target) => target.identityKey).toSet(), hasLength(3));
    expect(targets.first.identityKey, '["vaccination","pet","vaccine",3]');
    expect(
      targets.first,
      const VaccinationNotificationTarget(
        petId: 'pet',
        vaccinationId: 'vaccine',
        daysBefore: 3,
      ),
    );
  });

  test('structured identities cannot collide through delimiters in IDs', () {
    expect(
      dose(pet: 'a/b', medication: 'c').identityKey,
      isNot(dose(pet: 'a', medication: 'b/c').identityKey),
    );
  });
}
