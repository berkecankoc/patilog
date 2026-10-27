import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/vaccination/data/models/vaccination_model.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';

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
    'reminder_settings': null,
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

  test(
    'preserves inherited, Off and Custom settings through entity and SQL JSON',
    () {
      for (final settings in [
        null,
        const VaccinationReminderSettings.off(),
        VaccinationReminderSettings.custom(
          VaccinationReminderSchedule(daysBefore: [7, 0], minuteOfDay: 1080),
        ),
      ]) {
        final entity = Vaccination(
          id: vaccination.id,
          petId: vaccination.petId,
          vaccineName: vaccination.vaccineName,
          status: vaccination.status,
          date: vaccination.date,
          reminderSettings: settings,
        );
        final model = VaccinationModel.fromEntity(entity);
        final stored = model.toJson();
        expect(
          stored['reminder_settings'],
          settings == null ? isNull : isA<String>(),
        );
        expect(VaccinationModel.fromJson(stored), model);
        expect(VaccinationModel.fromJson(stored).toEntity(), entity);
      }
    },
  );

  test('malformed reminder settings do not silently become inherited', () {
    for (final stored in [42, '', '{}', 'null', '{"mode":"custom"}']) {
      expect(
        () => VaccinationModel.fromJson({...json, 'reminder_settings': stored}),
        throwsFormatException,
      );
    }
  });
}
