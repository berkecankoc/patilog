import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/medication/data/models/medication_model.dart';
import 'package:patilog/features/medication/data/models/medication_period_model.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';

void main() {
  final period = MedicationPeriod(
    id: 'period',
    medicationId: 'medicine',
    startDate: DateTime(2026, 10, 20),
    intervalDays: 2,
    doseTimes: [480, 1200],
    dosageInstructions: 'Half a tablet',
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    notes: 'After food',
    vetVisitId: 'visit',
  );
  final medication = Medication(
    id: 'medicine',
    petId: 'pet',
    name: 'Medicine',
    periods: [period],
  );

  test('entity conversion retains the complete period collection', () {
    expect(MedicationModel.fromEntity(medication).toEntity(), medication);
  });

  test('parent storage excludes periods while read assembly restores them', () {
    final model = MedicationModel.fromEntity(medication);
    expect(model.toJson(), {
      'id': 'medicine',
      'pet_id': 'pet',
      'name': 'Medicine',
    });
    final loaded = MedicationModel.fromJson(
      model.toJson(),
      periods: [MedicationPeriodModel.fromEntity(period)],
    );
    expect(loaded.toEntity(), medication);
  });
}
