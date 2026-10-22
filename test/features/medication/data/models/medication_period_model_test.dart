import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/medication/data/models/medication_period_model.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';

void main() {
  test('storage normalizes text and calendar dates without UTC conversion', () {
    final entity = MedicationPeriod(
      id: 'period',
      medicationId: 'medicine',
      startDate: DateTime.utc(2026, 10, 20, 23, 59),
      endDate: DateTime.utc(2026, 10, 22, 23),
      intervalDays: 2,
      doseTimes: [1200, 480],
      dosageInstructions: ' Half a tablet ',
      clinicName: ' Clinic ',
      veterinarianName: '  ',
      notes: ' Note ',
      vetVisitId: 'visit',
    );
    final json = MedicationPeriodModel.fromEntity(entity).toJson();
    expect(json, {
      'id': 'period',
      'medication_id': 'medicine',
      'start_date': '2026-10-20',
      'end_date': '2026-10-22',
      'interval_days': 2,
      'dose_times': '[480,1200]',
      'dosage_instructions': 'Half a tablet',
      'clinic_name': 'Clinic',
      'veterinarian_name': null,
      'notes': 'Note',
      'vet_visit_id': 'visit',
    });
    final loaded = MedicationPeriodModel.fromJson(json).toEntity();
    expect(loaded.startDate, DateTime(2026, 10, 20));
    expect(loaded.endDate, DateTime(2026, 10, 22));
    expect(loaded.doseTimes, [480, 1200]);
    expect(loaded.veterinarianName, isNull);
    expect(loaded.vetVisitId, 'visit');
  });

  test('unbounded periods and blank optional values round trip to null', () {
    final model = MedicationPeriodModel(
      id: 'period',
      medicationId: 'medicine',
      startDate: DateTime(2026, 1, 1),
      intervalDays: 1,
      doseTimes: [0, 1439],
      dosageInstructions: ' ',
      notes: '\n',
    );
    final loaded = MedicationPeriodModel.fromJson(model.toJson());
    expect(loaded.endDate, isNull);
    expect(loaded.dosageInstructions, isNull);
    expect(loaded.notes, isNull);
    expect(loaded.toEntity().doseTimes, [0, 1439]);
  });
}
