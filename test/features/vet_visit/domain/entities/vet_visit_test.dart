import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';

void main() {
  final date = DateTime(2026, 10, 15);

  VetVisit visit({
    String id = 'visit-1',
    String petId = 'pet-1',
    DateTime? visitedOn,
    String reason = 'Annual checkup',
    String? clinicName,
    String? veterinarianName,
    String? diagnosis,
    String? notes,
    int? costMinorUnits,
    VetVisitCurrency? currency,
  }) => VetVisit(
    id: id,
    petId: petId,
    visitedOn: visitedOn ?? date,
    reason: reason,
    clinicName: clinicName,
    veterinarianName: veterinarianName,
    diagnosis: diagnosis,
    notes: notes,
    costMinorUnits: costMinorUnits,
    currency: currency,
  );

  test('optional details and an unrecorded cost can be omitted', () {
    final entry = visit();
    expect(entry.clinicName, isNull);
    expect(entry.veterinarianName, isNull);
    expect(entry.diagnosis, isNull);
    expect(entry.notes, isNull);
    expect(entry.costMinorUnits, isNull);
    expect(entry.currency, isNull);
  });

  test('equivalent visits compare equally', () {
    expect(
      visit(
        clinicName: 'Clinic',
        veterinarianName: 'Dr. Smith',
        diagnosis: 'Healthy',
        notes: 'Routine follow-up',
        costMinorUnits: 125050,
        currency: VetVisitCurrency.turkishLira,
      ),
      visit(
        clinicName: 'Clinic',
        veterinarianName: 'Dr. Smith',
        diagnosis: 'Healthy',
        notes: 'Routine follow-up',
        costMinorUnits: 125050,
        currency: VetVisitCurrency.turkishLira,
      ),
    );
  });

  final changes = <String, VetVisit Function()>{
    'id': () => visit(id: 'visit-2'),
    'pet': () => visit(petId: 'pet-2'),
    'date': () => visit(visitedOn: DateTime(2026, 10, 14)),
    'reason': () => visit(reason: 'Follow-up'),
    'clinic': () => visit(clinicName: 'Clinic'),
    'veterinarian': () => visit(veterinarianName: 'Dr. Smith'),
    'diagnosis': () => visit(diagnosis: 'Healthy'),
    'notes': () => visit(notes: 'Routine follow-up'),
    'cost': () =>
        visit(costMinorUnits: 125050, currency: VetVisitCurrency.euro),
  };

  for (final change in changes.entries) {
    test('changing ${change.key} changes visit equality', () {
      expect(change.value(), isNot(visit()));
    });
  }

  test(
    'cost and currency corrections each change equality with the same ID',
    () {
      final original = visit(
        costMinorUnits: 125050,
        currency: VetVisitCurrency.euro,
      );
      expect(
        visit(costMinorUnits: 125051, currency: VetVisitCurrency.euro),
        isNot(original),
      );
      expect(
        visit(costMinorUnits: 125050, currency: VetVisitCurrency.usDollar),
        isNot(original),
      );
    },
  );

  test('a recorded zero cost differs from an unrecorded cost', () {
    expect(
      visit(costMinorUnits: 0, currency: VetVisitCurrency.turkishLira),
      isNot(visit()),
    );
  });

  test('supported currencies have distinct stable storage codes', () {
    expect(
      {for (final currency in VetVisitCurrency.values) currency: currency.code},
      {
        VetVisitCurrency.turkishLira: 'TRY',
        VetVisitCurrency.usDollar: 'USD',
        VetVisitCurrency.euro: 'EUR',
      },
    );
  });
}
