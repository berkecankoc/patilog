import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/vet_visit/data/models/vet_visit_model.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

void main() {
  final entity = VetVisit(
    id: 'visit-1',
    petId: 'pet-1',
    visitedOn: DateTime(2026, 10, 15),
    reason: 'Checkup',
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    diagnosis: 'Healthy',
    notes: 'Routine visit',
    costMinorUnits: 125050,
    currency: VetVisitCurrency.turkishLira,
  );
  const json = {
    'id': 'visit-1',
    'pet_id': 'pet-1',
    'visited_on': '2026-10-15',
    'reason': 'Checkup',
    'clinic_name': 'Clinic',
    'veterinarian_name': 'Dr. Smith',
    'diagnosis': 'Healthy',
    'notes': 'Routine visit',
    'cost_minor_units': 125050,
    'currency': 'TRY',
  };

  test('maps all entity fields through database storage without data loss', () {
    final model = VetVisitModel.fromEntity(entity);
    expect(model.toJson(), json);
    expect(VetVisitModel.fromJson(json), model);
    expect(VetVisitModel.fromJson(model.toJson()).toEntity(), entity);
  });

  test('trims text and stores blank optional fields as null', () {
    final model = VetVisitModel(
      id: 'visit-1',
      petId: 'pet-1',
      visitedOn: entity.visitedOn,
      reason: '  Checkup \n',
      clinicName: '  Clinic  ',
      veterinarianName: '  Dr. Smith  ',
      diagnosis: '  \n ',
      notes: '',
    );
    final restored = VetVisitModel.fromJson(model.toJson());
    expect(restored.reason, 'Checkup');
    expect(restored.clinicName, 'Clinic');
    expect(restored.veterinarianName, 'Dr. Smith');
    expect(restored.diagnosis, isNull);
    expect(restored.notes, isNull);
    expect(restored.costMinorUnits, isNull);
    expect(restored.currency, isNull);
  });

  for (final currency in VetVisitCurrency.values) {
    test('stores and restores ${currency.code} with an exact integer cost', () {
      final stored = {...json, 'currency': currency.code};
      final restored = VetVisitModel.fromJson(stored);
      expect(restored.currency, currency);
      expect(restored.costMinorUnits, 125050);
      expect(restored.toJson(), stored);
    });
  }

  test('keeps zero cost distinct from an absent cost', () {
    final free = VetVisitModel.fromJson({...json, 'cost_minor_units': 0});
    final unspecified = VetVisitModel.fromJson({
      ...json,
      'cost_minor_units': null,
      'currency': null,
    });
    expect(free.toJson()['cost_minor_units'], 0);
    expect(free.currency, VetVisitCurrency.turkishLira);
    expect(unspecified.toJson()['cost_minor_units'], isNull);
    expect(unspecified.currency, isNull);
  });

  test('serializes local and UTC calendar components without conversion', () {
    for (final date in [
      DateTime(2026, 1, 2, 0, 1),
      DateTime.utc(2026, 1, 2, 23, 59),
    ]) {
      final model = VetVisitModel(
        id: entity.id,
        petId: entity.petId,
        visitedOn: date,
        reason: entity.reason,
      );
      expect(model.toJson()['visited_on'], '2026-01-02');
      final restored = VetVisitModel.fromJson(model.toJson());
      expect(restored.visitedOn, DateTime(2026, 1, 2));
      expect(restored.visitedOn.isUtc, isFalse);
    }
  });

  test('does not invent a date or substitute an unknown currency', () {
    expect(
      () => VetVisitModel.fromJson({...json, 'visited_on': 'not-a-date'}),
      throwsFormatException,
    );
    expect(
      () => VetVisitModel.fromJson({...json, 'currency': 'unknown'}),
      throwsStateError,
    );
  });
}
