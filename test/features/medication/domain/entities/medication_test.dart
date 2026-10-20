import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';

void main() {
  MedicationPeriod period({int intervalDays = 1}) => MedicationPeriod(
    id: 'period-1',
    medicationId: 'medication-1',
    startDate: DateTime(2026, 10, 20),
    intervalDays: intervalDays,
    doseTimes: [480, 1200],
  );

  Medication medication(List<MedicationPeriod> periods) => Medication(
    id: 'medication-1',
    petId: 'pet-1',
    name: 'Medicine',
    periods: periods,
  );

  test('loaded periods cannot change through the caller or the entity', () {
    final periods = [period()];
    final loaded = medication(periods);

    periods.clear();

    expect(loaded.periods, [period()]);
    expect(() => loaded.periods.clear(), throwsUnsupportedError);
  });

  test('a regimen change changes the loaded medication with the same ID', () {
    expect(medication([period()]), medication([period()]));
    expect(
      medication([period(intervalDays: 2)]),
      isNot(medication([period()])),
    );
  });
}
