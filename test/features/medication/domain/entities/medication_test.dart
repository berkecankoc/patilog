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

  test('period ordering is canonical without changing the caller list', () {
    final later = MedicationPeriod(
      id: 'later',
      medicationId: 'medication-1',
      startDate: DateTime.utc(2026, 10, 21, 23),
      intervalDays: 1,
      doseTimes: [480],
    );
    final values = [later, period()];
    final loaded = medication(values);
    expect(loaded.periods, [period(), later]);
    expect(values, [later, period()]);
  });

  test('status follows calendar windows, including gaps and the final end', () {
    final first = MedicationPeriod(
      id: 'first',
      medicationId: 'medication-1',
      startDate: DateTime(2026, 10, 20),
      endDate: DateTime(2026, 10, 22),
      intervalDays: 2,
      doseTimes: [480],
    );
    final next = MedicationPeriod(
      id: 'next',
      medicationId: 'medication-1',
      startDate: DateTime(2026, 10, 25),
      endDate: DateTime(2026, 10, 27),
      intervalDays: 1,
      doseTimes: [600],
    );
    final loaded = medication([next, first]);
    expect(loaded.statusOn(DateTime(2026, 10, 19)), MedicationStatus.upcoming);
    expect(
      loaded.statusOn(DateTime.utc(2026, 10, 21, 23)),
      MedicationStatus.active,
    );
    expect(loaded.statusOn(DateTime(2026, 10, 22)), MedicationStatus.active);
    expect(loaded.statusOn(DateTime(2026, 10, 23)), MedicationStatus.upcoming);
    expect(loaded.periodOn(DateTime(2026, 10, 23)), isNull);
    expect(loaded.statusOn(DateTime(2026, 10, 25)), MedicationStatus.active);
    expect(loaded.statusOn(DateTime(2026, 10, 27)), MedicationStatus.active);
    expect(loaded.statusOn(DateTime(2026, 10, 28)), MedicationStatus.completed);
  });

  test('an unbounded earlier plan never resumes after its successor ends', () {
    final next = MedicationPeriod(
      id: 'next',
      medicationId: 'medication-1',
      startDate: DateTime(2026, 10, 21),
      endDate: DateTime(2026, 10, 22),
      intervalDays: 1,
      doseTimes: [600],
    );
    final loaded = medication([period(), next]);
    expect(loaded.periodOn(DateTime(2026, 10, 21)), next);
    expect(loaded.periodOn(DateTime(2026, 10, 23)), isNull);
    expect(loaded.statusOn(DateTime(2026, 10, 23)), MedicationStatus.completed);
    expect(
      medication([period()]).statusOn(DateTime(2035, 1, 1)),
      MedicationStatus.active,
    );
  });
}
