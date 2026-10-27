import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';

/// Planning input; failed log reads must never be represented as empty results.
final class NotificationData {
  final List<Pet> pets;
  final List<Medication> medications;
  final List<Vaccination> vaccinations;
  final List<MedicationDoseLog> logs;

  NotificationData({
    List<Pet> pets = const [],
    List<Medication> medications = const [],
    List<Vaccination> vaccinations = const [],
    List<MedicationDoseLog> logs = const [],
  }) : pets = List.unmodifiable(pets),
       medications = List.unmodifiable(medications),
       vaccinations = List.unmodifiable(vaccinations),
       logs = List.unmodifiable(logs);

  NotificationData without({
    required String petId,
    bool petDeleted = false,
    String? medicationId,
    String? vaccinationId,
  }) => NotificationData(
    pets: petDeleted ? pets.where((pet) => pet.id != petId).toList() : pets,
    medications: medications
        .where(
          (medication) =>
              medication.petId != petId ||
              !petDeleted && medication.id != medicationId,
        )
        .toList(),
    vaccinations: vaccinations
        .where(
          (vaccination) =>
              vaccination.petId != petId ||
              !petDeleted && vaccination.id != vaccinationId,
        )
        .toList(),
    logs: logs,
  );
}
