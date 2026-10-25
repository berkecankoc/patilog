import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';

final class AllPetsCareCubit extends Cubit<AllPetsCareState> {
  final PetRepository _pets;
  final VetVisitRepository _visits;
  final VaccinationRepository _vaccinations;
  final MedicationRepository _medications;
  final CalculateMedicationDoses _calculate;
  final DateTime Function() _now;
  final _requests = <AllPetsCareSection, int>{};
  final _dirty = <AllPetsCareSection>{};
  int _doseRequest = 0;
  // Reconcile reads already in flight without rereading a known deletion.
  final _deletedPets = <String>{};
  final _deletedVisits = <(String, String)>{};
  final _deletedVaccinations = <(String, String)>{};
  final _deletedMedications = <(String, String)>{};

  List<T> _remaining<T>(List<T> records) => records
      .where(
        (record) => switch (record) {
          Pet() => !_deletedPets.contains(record.id),
          VetVisit() =>
            !_deletedPets.contains(record.petId) &&
                !_deletedVisits.contains((record.petId, record.id)),
          Vaccination() =>
            !_deletedPets.contains(record.petId) &&
                !_deletedVaccinations.contains((record.petId, record.id)),
          Medication() =>
            !_deletedPets.contains(record.petId) &&
                !_deletedMedications.contains((record.petId, record.id)),
          _ => true,
        },
      )
      .toList();

  AllPetsCareCubit(
    this._pets,
    this._visits,
    this._vaccinations,
    this._medications,
    this._calculate, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(AllPetsCareState(currentTime: (now ?? DateTime.now)()));

  Future<bool> _load<T>(
    AllPetsCareSection section,
    Future<Result<List<T>>> Function() read,
    CareRecords<T> Function() current,
    void Function(CareRecords<T>) update,
  ) async {
    if (isClosed || state.isBusy) return false;
    final request = (_requests[section] ?? 0) + 1;
    _requests[section] = request;
    _dirty.remove(section);
    update(current().copyWith(isLoading: true, clearError: true));
    final result = await read();
    if (isClosed || request != _requests[section]) return false;
    switch (result) {
      case Success<List<T>>():
        update(
          current().copyWith(
            records: _remaining(result.data),
            hasLoaded: true,
            isLoading: false,
            clearError: true,
          ),
        );
        return true;
      case Error<List<T>>():
        update(
          current().copyWith(isLoading: false, error: result.failure.message),
        );
        return false;
    }
  }

  Future<void> loadPets() async {
    final previous = state.pets.records.map((pet) => pet.id).toSet();
    final loaded = await _load(
      AllPetsCareSection.pets,
      _pets.getPets,
      () => state.pets,
      (value) => emit(state.copyWith(pets: value)),
    );
    if (!loaded || isClosed) return;
    final existing = state.petsById.keys.toSet();
    for (final id in previous.difference(existing)) {
      removeDeletedPet(id);
    }
  }

  Future<void> loadVisits() async {
    await _load(
      AllPetsCareSection.vetVisits,
      _visits.getAllVetVisits,
      () => state.visits,
      (value) => emit(state.copyWith(visits: value)),
    );
  }

  Future<void> loadVaccinations() async {
    await _load(
      AllPetsCareSection.vaccinations,
      _vaccinations.getAllVaccinations,
      () => state.vaccinations,
      (value) => emit(state.copyWith(vaccinations: value)),
    );
  }

  Future<void> loadMedications() async {
    if (isClosed || state.isBusy) return;
    ++_doseRequest;
    final loaded = await _load(
      AllPetsCareSection.medications,
      _medications.getAllMedications,
      () => state.medications,
      (value) => emit(
        state.copyWith(
          medications: value,
          doses: state.doses.copyWith(
            isLoading: false,
            hasLoaded: false,
            clearError: true,
          ),
        ),
      ),
    );
    if (loaded &&
        !isClosed &&
        state.activeSection == AllPetsCareSection.medications) {
      await loadDoses(
        state.followsToday && state.failedAction is! GlobalDoseAction
            ? _now()
            : state.doseDate,
      );
    }
  }

  bool _needsLoad<T>(AllPetsCareSection section, CareRecords<T> data) =>
      !data.isLoading &&
      (_dirty.contains(section) || !data.hasLoaded && data.error == null);

  Future<void> activate(AllPetsCareSection section) async {
    if (isClosed || state.isBusy) return;
    emit(
      state.copyWith(
        activeSection: section,
        currentTime: _now(),
        clearActionError: section != state.activeSection,
      ),
    );
    final tasks = <Future<void>>[];
    if (_needsLoad(AllPetsCareSection.pets, state.pets)) tasks.add(loadPets());
    switch (section) {
      case AllPetsCareSection.pets:
        break;
      case AllPetsCareSection.vetVisits:
        if (_needsLoad(section, state.visits)) tasks.add(loadVisits());
      case AllPetsCareSection.vaccinations:
        if (_needsLoad(section, state.vaccinations)) {
          tasks.add(loadVaccinations());
        }
      case AllPetsCareSection.medications:
        if (_needsLoad(section, state.medications)) {
          tasks.add(loadMedications());
        }
    }
    await Future.wait(tasks);
    if (!isClosed && state.activeSection == section) {
      await refreshForClockChange();
    }
  }

  Future<void> refreshActive() async {
    if (isClosed || state.isBusy) return;
    switch (state.activeSection) {
      case AllPetsCareSection.pets:
        await loadPets();
      case AllPetsCareSection.vetVisits:
        await loadVisits();
      case AllPetsCareSection.vaccinations:
        await loadVaccinations();
      case AllPetsCareSection.medications:
        await loadMedications();
    }
    if (!isClosed) await refreshForClockChange();
  }

  void selectPet(AllPetsCareSection section, String? petId) {
    if (isClosed ||
        state.isBusy ||
        section != state.activeSection ||
        section == AllPetsCareSection.pets ||
        petId != null && !state.petsById.containsKey(petId)) {
      return;
    }
    final filters = Map<AllPetsCareSection, String>.of(state.petFilters);
    if (petId == null) {
      filters.remove(section);
    } else {
      filters[section] = petId;
    }
    emit(state.copyWith(petFilters: filters, clearActionError: true));
  }

  void invalidate(AllPetsCareSection section) {
    if (isClosed) return;
    _dirty.add(section);
    _requests[section] = (_requests[section] ?? 0) + 1;
    final next = state.copyWith(
      clearActionError: state.failedAction?.section == section,
    );
    switch (section) {
      case AllPetsCareSection.pets:
        emit(next.copyWith(pets: state.pets.copyWith(isLoading: false)));
      case AllPetsCareSection.vetVisits:
        emit(next.copyWith(visits: state.visits.copyWith(isLoading: false)));
      case AllPetsCareSection.vaccinations:
        emit(
          next.copyWith(
            vaccinations: state.vaccinations.copyWith(isLoading: false),
          ),
        );
      case AllPetsCareSection.medications:
        ++_doseRequest;
        emit(
          next.copyWith(
            medications: state.medications.copyWith(isLoading: false),
            doses: state.doses.copyWith(isLoading: false, hasLoaded: false),
          ),
        );
    }
  }

  List<MedicationDoseLog> _logs() => state.doses.records
      .map((dose) => dose.log)
      .whereType<MedicationDoseLog>()
      .toList();
  List<MedicationDose> _doses(List<MedicationDoseLog> logs, DateTime date) =>
      _calculate(
        medications: state.medications.records,
        logs: logs,
        fromDate: date,
        toDate: date,
      );

  Future<void> loadDoses(DateTime date) async {
    if (isClosed ||
        state.isBusy ||
        state.activeSection != AllPetsCareSection.medications ||
        _dirty.contains(AllPetsCareSection.medications) ||
        !state.medications.hasLoaded ||
        state.medications.isLoading ||
        state.medications.error != null) {
      return;
    }
    final day = DateTime(date.year, date.month, date.day);
    final sameDay = calendarDayNumber(day) == calendarDayNumber(state.doseDate);
    final request = ++_doseRequest;
    emit(
      state.copyWith(
        doseDate: day,
        followsToday: calendarDayNumber(day) == calendarDayNumber(_now()),
        clearActionError: !sameDay,
        doses: state.doses.copyWith(
          records: _doses(sameDay ? _logs() : [], day),
          hasLoaded: sameDay && state.doses.hasLoaded,
          isLoading: true,
          clearError: true,
        ),
      ),
    );
    final result = await _medications.getAllDoseLogs(
      fromDate: day,
      toDate: day,
    );
    if (isClosed || request != _doseRequest) return;
    switch (result) {
      case Success<List<MedicationDoseLog>>():
        emit(
          state.copyWith(
            doses: CareRecords(
              records: _doses(result.data, day),
              hasLoaded: true,
            ),
          ),
        );
      case Error<List<MedicationDoseLog>>():
        emit(
          state.copyWith(
            doses: state.doses.copyWith(
              isLoading: false,
              error: result.failure.message,
            ),
          ),
        );
    }
  }

  Future<void> refreshForClockChange() async {
    if (isClosed || state.isBusy) return;
    final time = _now();
    emit(state.copyWith(currentTime: time));
    if (state.activeSection != AllPetsCareSection.medications ||
        state.medications.isLoading ||
        state.doses.isLoading ||
        state.failedAction is GlobalDoseAction) {
      return;
    }
    final shouldFollow =
        state.followsToday &&
        calendarDayNumber(state.doseDate) != calendarDayNumber(time);
    if (shouldFollow || !state.doses.hasLoaded && state.doses.error == null) {
      await loadDoses(shouldFollow ? time : state.doseDate);
    }
  }

  Future<void> saveDose(
    MedicationDose dose,
    MedicationDoseStatus status, {
    DateTime? givenAt,
  }) => performAction(
    SaveGlobalDose(
      dose.medication.petId,
      dose.medication.id,
      MedicationDoseLog(
        periodId: dose.period.id,
        scheduledDate: dose.scheduledDate,
        scheduledMinute: dose.scheduledMinute,
        status: status,
        givenAt: status == MedicationDoseStatus.given
            ? givenAt ?? _now()
            : null,
      ),
    ),
  );

  bool _canPerform(AllPetsCareAction action) {
    if (state.activeSection != action.section ||
        _dirty.contains(action.section) ||
        !state.petsById.containsKey(action.petId) ||
        state.petFilters[action.section] != null &&
            state.petFilters[action.section] != action.petId) {
      return false;
    }
    switch (action) {
      case DeleteGlobalVetVisit():
        return state.visits.hasLoaded &&
            !state.visits.isLoading &&
            state.visits.records.any(
              (v) => v.id == action.visitId && v.petId == action.petId,
            );
      case DeleteGlobalVaccination():
        return state.vaccinations.hasLoaded &&
            !state.vaccinations.isLoading &&
            state.vaccinations.records.any(
              (v) => v.id == action.vaccinationId && v.petId == action.petId,
            );
      case GlobalDoseAction(:final log):
        if (!state.doseResultsKnown ||
            calendarDayNumber(log.scheduledDate) > calendarDayNumber(_now())) {
          return false;
        }
        final dose = state.doses.records
            .where(
              (d) =>
                  d.medication.petId == action.petId &&
                  d.medication.id == action.medicationId &&
                  d.period.id == log.periodId &&
                  calendarDayNumber(d.scheduledDate) ==
                      calendarDayNumber(log.scheduledDate) &&
                  d.scheduledMinute == log.scheduledMinute,
            )
            .firstOrNull;
        if (dose == null) return false;
        return switch (action) {
          ClearGlobalDose() => dose.log != null,
          SaveGlobalDose() =>
            log.status == MedicationDoseStatus.given
                ? log.givenAt != null && !log.givenAt!.isAfter(_now())
                : log.givenAt == null,
        };
    }
  }

  Future<void> performAction(AllPetsCareAction action) async {
    if (isClosed || state.isBusy || !_canPerform(action)) return;
    emit(state.copyWith(pendingAction: action, clearActionError: true));
    final result = await switch (action) {
      DeleteGlobalVetVisit() => _visits.deleteVetVisit(
        action.petId,
        action.visitId,
      ),
      DeleteGlobalVaccination() => _vaccinations.deleteVaccination(
        action.petId,
        action.vaccinationId,
      ),
      SaveGlobalDose() => _medications.saveDoseLog(
        action.petId,
        action.medicationId,
        action.log,
      ),
      ClearGlobalDose() => _medications.clearDoseLog(
        action.petId,
        action.medicationId,
        periodId: action.log.periodId,
        scheduledDate: action.log.scheduledDate,
        scheduledMinute: action.log.scheduledMinute,
      ),
    };
    if (isClosed) return;
    switch (result) {
      case Error<void>():
        emit(
          state.copyWith(
            clearPendingAction: true,
            failedAction: action,
            actionError: result.failure.message,
          ),
        );
      case Success<void>():
        AllPetsCareState updated;
        switch (action) {
          case DeleteGlobalVetVisit():
            updated = _withoutVisit(action.petId, action.visitId);
          case DeleteGlobalVaccination():
            updated = _withoutVaccination(action.petId, action.vaccinationId);
          case GlobalDoseAction():
            final logs = _logs()
              ..removeWhere(
                (log) =>
                    log.periodId == action.log.periodId &&
                    calendarDayNumber(log.scheduledDate) ==
                        calendarDayNumber(action.log.scheduledDate) &&
                    log.scheduledMinute == action.log.scheduledMinute,
              );
            if (action is SaveGlobalDose) logs.add(action.log);
            updated = state.copyWith(
              doses: CareRecords(
                records: _doses(logs, state.doseDate),
                hasLoaded: true,
              ),
            );
        }
        emit(
          updated.copyWith(
            clearPendingAction: true,
            clearActionError: true,
            lastMutation: action,
            mutationRevision: state.mutationRevision + 1,
          ),
        );
        if (action is DeleteGlobalVetVisit) {
          invalidate(AllPetsCareSection.vaccinations);
          invalidate(AllPetsCareSection.medications);
        }
    }
  }

  void removeDeletedVisit(String petId, String visitId) {
    if (isClosed || state.isBusy) return;
    emit(_withoutVisit(petId, visitId));
    invalidate(AllPetsCareSection.vaccinations);
    invalidate(AllPetsCareSection.medications);
  }

  void removeDeletedVaccination(String petId, String vaccinationId) {
    if (isClosed || state.isBusy) return;
    emit(_withoutVaccination(petId, vaccinationId));
  }

  AllPetsCareState _withoutVisit(String petId, String visitId) {
    _deletedVisits.add((petId, visitId));
    final failed = state.failedAction;
    return state.copyWith(
      clearActionError:
          failed is DeleteGlobalVetVisit &&
          failed.petId == petId &&
          failed.visitId == visitId,
      visits: state.visits.copyWith(
        records: state.visits.records
            .where((v) => v.petId != petId || v.id != visitId)
            .toList(),
      ),
    );
  }

  AllPetsCareState _withoutVaccination(String petId, String vaccinationId) {
    _deletedVaccinations.add((petId, vaccinationId));
    final failed = state.failedAction;
    return state.copyWith(
      clearActionError:
          failed is DeleteGlobalVaccination &&
          failed.petId == petId &&
          failed.vaccinationId == vaccinationId,
      vaccinations: state.vaccinations.copyWith(
        records: state.vaccinations.records
            .where((v) => v.petId != petId || v.id != vaccinationId)
            .toList(),
      ),
    );
  }

  void removeDeletedMedication(String petId, String medicationId) {
    if (isClosed || state.isBusy) return;
    _deletedMedications.add((petId, medicationId));
    final records = state.medications.records
        .where((m) => m.petId != petId || m.id != medicationId)
        .toList();
    final logs = _logs();
    final failed = state.failedAction;
    emit(
      state.copyWith(
        clearActionError:
            failed is GlobalDoseAction &&
            failed.petId == petId &&
            failed.medicationId == medicationId,
        medications: state.medications.copyWith(records: records),
        doses: state.doses.copyWith(
          records: _calculate(
            medications: records,
            logs: logs,
            fromDate: state.doseDate,
            toDate: state.doseDate,
          ),
        ),
      ),
    );
  }

  void removeDeletedPet(String petId) {
    if (isClosed || state.isBusy) return;
    _deletedPets.add(petId);
    final filters = Map<AllPetsCareSection, String>.of(state.petFilters)
      ..removeWhere((_, id) => id == petId);
    final logs = _logs();
    final remainingMedications = state.medications.records
        .where((m) => m.petId != petId)
        .toList();
    emit(
      state.copyWith(
        clearActionError: state.failedAction?.petId == petId,
        pets: state.pets.copyWith(
          records: state.pets.records.where((p) => p.id != petId).toList(),
        ),
        visits: state.visits.copyWith(
          records: state.visits.records.where((v) => v.petId != petId).toList(),
        ),
        vaccinations: state.vaccinations.copyWith(
          records: state.vaccinations.records
              .where((v) => v.petId != petId)
              .toList(),
        ),
        medications: state.medications.copyWith(records: remainingMedications),
        petFilters: filters,
        doses: state.doses.copyWith(
          records: _calculate(
            medications: remainingMedications,
            logs: logs,
            fromDate: state.doseDate,
            toDate: state.doseDate,
          ),
        ),
      ),
    );
  }
}
