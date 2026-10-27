import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';

void main() {
  Vaccination vaccination([VaccinationReminderSettings? settings]) =>
      Vaccination(
        id: 'vaccination',
        petId: 'pet',
        vaccineName: 'Rabies',
        status: VaccinationStatus.planned,
        date: DateTime(2026, 11, 3),
        reminderSettings: settings,
      );

  test('an existing vaccination inherits defaults without an override', () {
    expect(vaccination().reminderSettings, isNull);
  });

  test('default, Off and Custom participate in vaccination equality', () {
    final inherited = vaccination();
    final off = vaccination(const VaccinationReminderSettings.off());
    final custom = vaccination(
      VaccinationReminderSettings.custom(VaccinationReminderSchedule()),
    );
    expect({inherited, off, custom}, hasLength(3));
    expect(off, vaccination(const VaccinationReminderSettings.off()));
  });
}
