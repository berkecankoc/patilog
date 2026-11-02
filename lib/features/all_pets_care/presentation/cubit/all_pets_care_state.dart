import 'package:equatable/equatable.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

enum AllPetsCareSection { pets, vetVisits, vaccinations, medications, feeding }

final class CareRecords<T> extends Equatable {
  final List<T> records;
  final bool hasLoaded;
  final bool isLoading;
  final String? error;

  CareRecords({
    List<T> records = const [],
    this.hasLoaded = false,
    this.isLoading = false,
    this.error,
  }) : records = List.unmodifiable(records);

  CareRecords<T> copyWith({
    List<T>? records,
    bool? hasLoaded,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => CareRecords(
    records: records ?? this.records,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [records, hasLoaded, isLoading, error];
}

final class AllPetsCareState extends Equatable {
  final AllPetsCareSection activeSection;
  final CareRecords<Pet> pets;
  final CareRecords<VetVisit> visits;
  final CareRecords<Vaccination> vaccinations;
  final CareRecords<Medication> medications;
  final CareRecords<MedicationDose> doses;
  final Map<AllPetsCareSection, String> petFilters;
  final DateTime currentTime;
  final DateTime doseDate;
  final bool followsToday;
  final AllPetsCareAction? pendingAction;
  final AllPetsCareAction? failedAction;
  final String? actionError;
  final AllPetsCareAction? lastMutation;
  final int mutationRevision;

  AllPetsCareState({
    required this.currentTime,
    this.activeSection = AllPetsCareSection.pets,
    CareRecords<Pet>? pets,
    CareRecords<VetVisit>? visits,
    CareRecords<Vaccination>? vaccinations,
    CareRecords<Medication>? medications,
    CareRecords<MedicationDose>? doses,
    Map<AllPetsCareSection, String> petFilters = const {},
    DateTime? doseDate,
    this.followsToday = true,
    this.pendingAction,
    this.failedAction,
    this.actionError,
    this.lastMutation,
    this.mutationRevision = 0,
  }) : pets = pets ?? CareRecords(),
       visits = visits ?? CareRecords(),
       vaccinations = vaccinations ?? CareRecords(),
       medications = medications ?? CareRecords(),
       doses = doses ?? CareRecords(),
       doseDate =
           doseDate ??
           DateTime(currentTime.year, currentTime.month, currentTime.day),
       petFilters = Map.unmodifiable(petFilters);

  late final Map<String, Pet> petsById = Map.unmodifiable({
    for (final pet in pets.records) pet.id: pet,
  });
  bool get isBusy => pendingAction != null;
  bool get doseResultsKnown =>
      medications.hasLoaded &&
      medications.error == null &&
      !medications.isLoading &&
      doses.hasLoaded &&
      !doses.isLoading &&
      doses.error == null;

  List<T> _visible<T>(
    List<T> records,
    AllPetsCareSection section,
    String Function(T) owner,
  ) {
    final petId = petFilters[section];
    return petId == null
        ? records
        : List.unmodifiable(records.where((record) => owner(record) == petId));
  }

  List<VetVisit> get visibleVisits =>
      _visible(visits.records, AllPetsCareSection.vetVisits, (v) => v.petId);
  List<Vaccination> get visibleVaccinations => _visible(
    vaccinations.records,
    AllPetsCareSection.vaccinations,
    (v) => v.petId,
  );
  List<Medication> get visibleMedications => _visible(
    medications.records,
    AllPetsCareSection.medications,
    (m) => m.petId,
  );
  List<MedicationDose> get visibleDoses => _visible(
    doses.records,
    AllPetsCareSection.medications,
    (d) => d.medication.petId,
  );
  List<Vaccination> get overdueVaccinations => List.unmodifiable(
    visibleVaccinations.where(
      (v) =>
          v.status == VaccinationStatus.planned &&
          calendarDayNumber(v.date) < calendarDayNumber(currentTime),
    ),
  );
  List<Vaccination> get todayVaccinations => List.unmodifiable(
    visibleVaccinations.where(
      (v) =>
          v.status == VaccinationStatus.planned &&
          calendarDayNumber(v.date) == calendarDayNumber(currentTime),
    ),
  );
  List<Vaccination> get upcomingVaccinations => List.unmodifiable(
    visibleVaccinations.where(
      (v) =>
          v.status == VaccinationStatus.planned &&
          calendarDayNumber(v.date) > calendarDayNumber(currentTime),
    ),
  );
  List<Vaccination> get administeredVaccinations => List.unmodifiable(
    visibleVaccinations.where(
      (v) => v.status == VaccinationStatus.administered,
    ),
  );

  AllPetsCareState copyWith({
    AllPetsCareSection? activeSection,
    CareRecords<Pet>? pets,
    CareRecords<VetVisit>? visits,
    CareRecords<Vaccination>? vaccinations,
    CareRecords<Medication>? medications,
    CareRecords<MedicationDose>? doses,
    Map<AllPetsCareSection, String>? petFilters,
    DateTime? currentTime,
    DateTime? doseDate,
    bool? followsToday,
    AllPetsCareAction? pendingAction,
    bool clearPendingAction = false,
    AllPetsCareAction? failedAction,
    String? actionError,
    bool clearActionError = false,
    AllPetsCareAction? lastMutation,
    int? mutationRevision,
  }) => AllPetsCareState(
    activeSection: activeSection ?? this.activeSection,
    pets: pets ?? this.pets,
    visits: visits ?? this.visits,
    vaccinations: vaccinations ?? this.vaccinations,
    medications: medications ?? this.medications,
    doses: doses ?? this.doses,
    petFilters: petFilters ?? this.petFilters,
    currentTime: currentTime ?? this.currentTime,
    doseDate: doseDate ?? this.doseDate,
    followsToday: followsToday ?? this.followsToday,
    pendingAction: clearPendingAction
        ? null
        : pendingAction ?? this.pendingAction,
    failedAction: clearActionError ? null : failedAction ?? this.failedAction,
    actionError: clearActionError ? null : actionError ?? this.actionError,
    lastMutation: lastMutation ?? this.lastMutation,
    mutationRevision: mutationRevision ?? this.mutationRevision,
  );

  @override
  List<Object?> get props => [
    activeSection,
    pets,
    visits,
    vaccinations,
    medications,
    doses,
    petFilters,
    currentTime,
    doseDate,
    followsToday,
    pendingAction,
    failedAction,
    actionError,
    lastMutation,
    mutationRevision,
  ];
}

sealed class AllPetsCareAction extends Equatable {
  final String petId;
  const AllPetsCareAction(this.petId);
  AllPetsCareSection get section;
}

final class DeleteGlobalVetVisit extends AllPetsCareAction {
  final String visitId;
  const DeleteGlobalVetVisit(super.petId, this.visitId);
  @override
  AllPetsCareSection get section => AllPetsCareSection.vetVisits;
  @override
  List<Object?> get props => [petId, visitId];
}

final class DeleteGlobalVaccination extends AllPetsCareAction {
  final String vaccinationId;
  const DeleteGlobalVaccination(super.petId, this.vaccinationId);
  @override
  AllPetsCareSection get section => AllPetsCareSection.vaccinations;
  @override
  List<Object?> get props => [petId, vaccinationId];
}

sealed class GlobalDoseAction extends AllPetsCareAction {
  final String medicationId;
  final MedicationDoseLog log;
  const GlobalDoseAction(super.petId, this.medicationId, this.log);
  @override
  AllPetsCareSection get section => AllPetsCareSection.medications;
  @override
  List<Object?> get props => [petId, medicationId, log];
}

final class SaveGlobalDose extends GlobalDoseAction {
  const SaveGlobalDose(super.petId, super.medicationId, super.log);
}

final class ClearGlobalDose extends GlobalDoseAction {
  const ClearGlobalDose(super.petId, super.medicationId, super.log);
}
