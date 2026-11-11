import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/vaccination/data/models/vaccination_model.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';

void main() {
  final vaccination = Vaccination(
    id: 'vaccination-1',
    petId: 'pet-1',
    vaccineName: 'Rabies',
    status: VaccinationStatus.administered,
    date: DateTime(2020, 1, 2),
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    notes: 'No reaction',
    vetVisitId: 'visit-1',
  );
  const json = {
    'id': 'vaccination-1',
    'pet_id': 'pet-1',
    'vaccine_name': 'Rabies',
    'status': 'administered',
    'date': '2020-01-02',
    'clinic_name': 'Clinic',
    'veterinarian_name': 'Dr. Smith',
    'notes': 'No reaction',
    'vet_visit_id': 'visit-1',
  };

  test('round-trips a complete administered record through storage', () {
    final model = VaccinationModel.fromEntity(vaccination);
    expect(model.toJson(), json);
    expect(VaccinationModel.fromJson(json).toEntity(), vaccination);
  });

  test('round-trips a planned record without optional details', () {
    final planned = Vaccination(
      id: 'planned',
      petId: 'pet-1',
      vaccineName: 'Rabies',
      status: VaccinationStatus.planned,
      date: DateTime(2030, 1, 2),
    );
    final stored = VaccinationModel.fromEntity(planned).toJson();
    expect(stored['status'], 'planned');
    expect(VaccinationModel.fromJson(stored).toEntity(), planned);
  });

  test('trims saved text and converts blank optional values to null', () {
    final model = VaccinationModel.fromJson({
      ...json,
      'vaccine_name': '  Rabies \n',
      'clinic_name': ' Clinic ',
      'veterinarian_name': ' \n ',
      'notes': '',
    });
    final restored = VaccinationModel.fromJson(model.toJson());
    expect(restored.vaccineName, 'Rabies');
    expect(restored.clinicName, 'Clinic');
    expect(restored.veterinarianName, isNull);
    expect(restored.notes, isNull);
  });

  test('stores local and UTC calendar components without shifting the day', () {
    for (final date in [
      DateTime(2020, 1, 2, 0, 1),
      DateTime.utc(2020, 1, 2, 23, 59),
    ]) {
      final model = VaccinationModel(
        id: 'vaccination-1',
        petId: 'pet-1',
        vaccineName: 'Rabies',
        status: VaccinationStatus.administered,
        date: date,
      );
      expect(model.toJson()['date'], '2020-01-02');
      expect(
        VaccinationModel.fromJson(model.toJson()).date,
        DateTime(2020, 1, 2),
      );
    }
  });

  test('does not replace invalid dates or unknown statuses with defaults', () {
    expect(
      () => VaccinationModel.fromJson({...json, 'date': 'not-a-date'}),
      throwsFormatException,
    );
    expect(
      () => VaccinationModel.fromJson({...json, 'status': 'unknown'}),
      throwsArgumentError,
    );
  });

  test('clinical models ignore unused per-record reminder metadata', () {
    for (final stored in [null, '{"mode":"off"}', '{"mode":"custom"}']) {
      expect(
        VaccinationModel.fromJson({
          ...json,
          'reminder_settings': stored,
        }).toEntity(),
        vaccination,
      );
    }
    expect(
      VaccinationModel.fromEntity(
        vaccination,
      ).toJson().containsKey('reminder_settings'),
      isFalse,
    );
  });
}
