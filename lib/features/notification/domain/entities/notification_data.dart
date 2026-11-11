import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';

/// Planning input; failed log reads must never be represented as empty results.
final class NotificationData {
  final List<Pet> pets;
  final List<Medication> medications;
  final List<Vaccination> vaccinations;
  final List<MedicationDoseLog> logs;
  final List<FeedingPlan> feedingPlans;
  final List<FeedingEntry> feedingEntries;

  NotificationData({
    List<Pet> pets = const [],
    List<Medication> medications = const [],
    List<Vaccination> vaccinations = const [],
    List<MedicationDoseLog> logs = const [],
    List<FeedingPlan> feedingPlans = const [],
    List<FeedingEntry> feedingEntries = const [],
  }) : pets = List.unmodifiable(pets),
       medications = List.unmodifiable(medications),
       vaccinations = List.unmodifiable(vaccinations),
       logs = List.unmodifiable(logs),
       feedingPlans = List.unmodifiable(feedingPlans),
       feedingEntries = List.unmodifiable(feedingEntries);

  NotificationData without({
    required String petId,
    bool petDeleted = false,
    String? medicationId,
    String? vaccinationId,
    String? feedingEntryId,
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
    feedingPlans: feedingPlans
        .where((p) => !petDeleted || p.petId != petId)
        .toList(),
    feedingEntries: feedingEntries
        .where((e) => e.petId != petId || !petDeleted && e.id != feedingEntryId)
        .toList(),
  );
}
