import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';

final class SaveVaccinationParams {
  final String petId;
  final String? vaccinationId;
  final String vaccineName;
  final VaccinationStatus status;
  final DateTime date;
  final String? clinicName;
  final String? veterinarianName;
  final String? notes;
  final String? vetVisitId;
  final DateTime? nextDoseDate;
  final VaccinationReminderSettings? reminderSettings;

  const SaveVaccinationParams({
    required this.petId,
    this.vaccinationId,
    required this.vaccineName,
    required this.status,
    required this.date,
    this.clinicName,
    this.veterinarianName,
    this.notes,
    this.vetVisitId,
    this.nextDoseDate,
    this.reminderSettings,
  });
}

class SaveVaccination {
  final VaccinationRepository repository;
  final IdGenerator _idGenerator;

  const SaveVaccination(this.repository, this._idGenerator);

  Future<Result<void>> call(SaveVaccinationParams params) {
    final vaccination = Vaccination(
      id: params.vaccinationId ?? _idGenerator.generate(),
      petId: params.petId,
      vaccineName: params.vaccineName,
      status: params.status,
      date: params.date,
      clinicName: params.clinicName,
      veterinarianName: params.veterinarianName,
      notes: params.notes,
      reminderSettings: params.reminderSettings,
      vetVisitId: params.status == VaccinationStatus.administered
          ? params.vetVisitId
          : null,
    );
    final nextDate = params.nextDoseDate;
    // A next dose is an independent plan, not a copy of the medical details.
    final nextDose = nextDate == null
        ? null
        : Vaccination(
            id: _idGenerator.generate(),
            petId: params.petId,
            vaccineName: params.vaccineName,
            status: VaccinationStatus.planned,
            date: nextDate,
          );

    return params.vaccinationId == null
        ? repository.createVaccination(vaccination, nextDose: nextDose)
        : repository.updateVaccination(vaccination, nextDose: nextDose);
  }
}
