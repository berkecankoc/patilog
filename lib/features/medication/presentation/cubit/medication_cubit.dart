import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/medication/domain/repositories/medication_repository.dart';
import 'package:patilog/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:patilog/features/medication/domain/utils/medication_calendar.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';

final class MedicationCubit extends Cubit<MedicationState> {
  final MedicationRepository _repository;
  final CalculateMedicationDoses _calculateDoses;
  final DateTime Function() now;
  int _loadRequest = 0;
  int _dosesRequest = 0;
  int _calendarRequest = 0;

  bool _dirty = false;
  bool _active = true;
  Set<String> _petIds = {};
  String? _selectedPetId;
  final _removedPets = <String>{};
  final _removedMedications = <(String, String)>{};

  bool get needsReload => _dirty || state is MedicationInitial;

  void dismissActionError() {
    final loaded = state;
    if (!isClosed &&
        loaded is MedicationsLoaded &&
        loaded.pendingAction == null) {
      emit(loaded.copyWith(clearActionError: true));
    }
  }

  void setPetContext(
    Iterable<String> petIds, {
    String? selectedPetId,
    bool active = true,
  }) {
    _petIds = petIds.toSet();
    _selectedPetId = _petIds.contains(selectedPetId) ? selectedPetId : null;
    _active = active;
  }

  List<Medication> _remaining(Iterable<Medication> medications) =>
      List.unmodifiable(
        medications.where(
          (m) =>
              !_removedPets.contains(m.petId) &&
              !_removedMedications.contains((m.petId, m.id)),
        ),
      );

  void invalidateList() {
    if (isClosed) return;
    _dirty = true;
    ++_loadRequest;
    ++_dosesRequest;
    final current = state;
    if (current is MedicationsLoaded) {
      emit(
        current.copyWith(
          isRefreshing: false,
          clearActionError: true,
          doses: MedicationDosesState(
            date: current.doses.date,
            doses: current.doses.doses,
            followsToday: current.doses.followsToday,
          ),
        ),
      );
    }
  }

  MedicationCubit(
    this._repository,
    this._calculateDoses, {
    this.now = DateTime.now,
  }) : super(const MedicationInitial());

  Future<void> loadMedications(String petId, {String? vetVisitId}) =>
      _load(petId, vetVisitId: vetVisitId);

  Future<void> loadAllMedications() => _load(null);

  Future<void> loadMedication(String petId, String medicationId) =>
      _load(petId, medicationId: medicationId);

  Future<void> _load(
    String? petId, {
    String? medicationId,
    String? vetVisitId,
  }) async {
    if (isClosed || state is MedicationDeleted) return;
    final previous = state;
    if (previous is MedicationsLoaded && previous.pendingAction != null) return;
    final retained =
        previous is MedicationsLoaded &&
            previous.petId == petId &&
            previous.medicationId == medicationId &&
            previous.vetVisitId == vetVisitId
        ? previous
        : null;
    _dirty = false;
    final request = ++_loadRequest;
    ++_dosesRequest;
    ++_calendarRequest;
    emit(
      retained?.copyWith(isRefreshing: true, clearRefreshError: true) ??
          const MedicationLoading(),
    );
    final Result<List<Medication>> result;
    if (medicationId == null) {
      result = petId == null
          ? await _repository.getAllMedications()
          : await _repository.getMedications(petId, vetVisitId: vetVisitId);
    } else {
      final detail = await _repository.getMedicationById(petId!, medicationId);
      result = switch (detail) {
        Success<Medication>() => Success([detail.data]),
        Error<Medication>() => Error(detail.failure),
      };
    }
    if (isClosed || request != _loadRequest) return;
    final latest = state;
    final retainedAfter =
        latest is MedicationsLoaded &&
            latest.petId == petId &&
            latest.medicationId == medicationId &&
            latest.vetVisitId == vetVisitId
        ? latest
        : retained;
    switch (result) {
      case Success<List<Medication>>():
        final records = _remaining(result.data);
        final currentTime = now();
        final followsToday =
            retainedAfter == null || retainedAfter.doses.followsToday;
        final failedAction = retainedAfter?.failedAction;
        final keepFailedDose =
            failedAction is SaveMedicationDoseAction ||
            failedAction is ClearMedicationDoseAction;
        final date = followsToday && !keepFailedDose
            ? _day(currentTime)
            : retainedAfter!.doses.date;
        var refreshed = MedicationsLoaded(
          petId: petId,
          medications: records,
          medicationId: medicationId,
          vetVisitId: vetVisitId,
          currentTime: currentTime,
          failedAction: failedAction,
          actionError: retainedAfter?.actionError,
          lastMutation: retainedAfter?.lastMutation,
          mutationRevision: retainedAfter?.mutationRevision ?? 0,
          calendar: retainedAfter?.calendar == null
              ? null
              : MedicationCalendarState(
                  month: DateTime(date.year, date.month),
                  doses: _calendarDoses(
                    records,
                    _calendarLogs(retainedAfter!.calendar!),
                    DateTime(date.year, date.month),
                  ),
                ),
          doses: MedicationDosesState(
            date: date,
            followsToday: followsToday,
            doses:
                retainedAfter != null &&
                    _sameDay(date, retainedAfter.doses.date)
                ? _doses(records, _logs(retainedAfter.doses), date)
                : _doses(records, const [], date),
            hasLoaded:
                petId != null &&
                retainedAfter != null &&
                _sameDay(date, retainedAfter.doses.date) &&
                retainedAfter.doses.hasLoaded,
          ),
        );
        if (failedAction != null &&
            !_canPerform(refreshed, failedAction, retainingFailure: true)) {
          refreshed = refreshed.copyWith(clearActionError: true);
          if (followsToday && !_sameDay(date, currentTime)) {
            refreshed = refreshed.copyWith(
              doses: MedicationDosesState(date: _day(currentTime)),
            );
          }
        }
        emit(refreshed);
        if (refreshed.calendar != null) {
          await loadCalendar(refreshed.calendar!.month);
        } else if (vetVisitId == null) {
          await loadDoses(refreshed.doses.date);
        }
      case Error<List<Medication>>():
        if (retainedAfter != null &&
            !(medicationId != null && result.failure is NotFoundFailure)) {
          emit(
            retainedAfter.copyWith(
              isRefreshing: false,
              refreshError: result.failure.message,
              calendar: retainedAfter.calendar == null
                  ? null
                  : MedicationCalendarState(
                      month: retainedAfter.calendar!.month,
                      doses: retainedAfter.calendar!.doses,
                      hasLoaded: retainedAfter.calendar!.hasLoaded,
                      error: retainedAfter.calendar!.error,
                    ),
              doses: MedicationDosesState(
                date: retainedAfter.doses.date,
                doses: retainedAfter.doses.doses,
                hasLoaded: retainedAfter.doses.hasLoaded,
                error: retainedAfter.doses.error,
                followsToday: retainedAfter.doses.followsToday,
              ),
            ),
          );
        } else {
          emit(MedicationError(result.failure));
        }
    }
  }

  Future<void> loadDoses(DateTime date) async {
    if (isClosed) return;
    final loaded = state;
    if (loaded is! MedicationsLoaded ||
        loaded.vetVisitId != null ||
        loaded.isRefreshing ||
        loaded.pendingAction != null ||
        loaded.petId == null &&
            (!_active || _dirty || loaded.refreshError != null)) {
      return;
    }
    date = _day(date);
    final request = ++_dosesRequest;
    final sameDate = _sameDay(date, loaded.doses.date);
    emit(
      loaded.copyWith(
        clearActionError: !sameDate,
        doses: MedicationDosesState(
          date: date,
          isLoading: true,
          followsToday: sameDate
              ? loaded.doses.followsToday
              : _sameDay(date, now()),
          doses: sameDate
              ? loaded.doses.doses
              : _doses(loaded.medications, const [], date),
          hasLoaded: sameDate && loaded.doses.hasLoaded,
        ),
      ),
    );
    final result = loaded.petId == null
        ? await _repository.getAllDoseLogs(fromDate: date, toDate: date)
        : await _repository.getDoseLogs(
            loaded.petId!,
            medicationId: loaded.medicationId,
            fromDate: date,
            toDate: date,
          );
    if (isClosed || request != _dosesRequest) return;
    final current = state as MedicationsLoaded;
    switch (result) {
      case Success<List<MedicationDoseLog>>():
        emit(
          current.copyWith(
            doses: MedicationDosesState(
              date: date,
              doses: _doses(current.medications, result.data, date),
              hasLoaded: true,
              followsToday: current.doses.followsToday,
            ),
          ),
        );
      case Error<List<MedicationDoseLog>>():
        emit(
          current.copyWith(
            doses: MedicationDosesState(
              date: date,
              doses: current.doses.doses,
              hasLoaded: current.doses.hasLoaded,
              error: result.failure.message,
              followsToday: current.doses.followsToday,
            ),
          ),
        );
    }
  }

  Future<void> loadCalendar(DateTime month) async {
    if (isClosed) return;
    final loaded = state;
    if (loaded is! MedicationsLoaded ||
        loaded.medicationId == null ||
        loaded.isRefreshing ||
        loaded.pendingAction != null) {
      return;
    }
    month = DateTime(month.year, month.month);
    final previous = loaded.calendar;
    final sameMonth = previous?.month == month;
    final date =
        loaded.doses.date.year == month.year &&
            loaded.doses.date.month == month.month
        ? loaded.doses.date
        : month;
    final request = ++_calendarRequest;
    ++_dosesRequest;
    final doses = sameMonth
        ? previous!.doses
        : _calendarDoses(loaded.medications, const [], month);
    emit(
      loaded.copyWith(
        clearActionError: !_sameDay(date, loaded.doses.date),
        calendar: MedicationCalendarState(
          month: month,
          doses: doses,
          hasLoaded: sameMonth && previous!.hasLoaded,
          isLoading: true,
        ),
        doses: MedicationDosesState(
          date: date,
          doses: doses
              .where((dose) => _sameDay(dose.scheduledDate, date))
              .toList(),
          hasLoaded: sameMonth && previous!.hasLoaded,
          isLoading: true,
          followsToday: _sameDay(date, now()),
        ),
      ),
    );
    final result = await _repository.getDoseLogs(
      loaded.petId!,
      medicationId: loaded.medicationId,
      fromDate: month,
      toDate: DateTime(month.year, month.month + 1, 0),
    );
    if (isClosed || request != _calendarRequest) return;
    final current = state as MedicationsLoaded;
    final calendar = current.calendar!;
    final computed = switch (result) {
      Success<List<MedicationDoseLog>>() => _calendarDoses(
        current.medications,
        result.data,
        month,
      ),
      Error<List<MedicationDoseLog>>() => calendar.doses,
    };
    final error = result is Error<List<MedicationDoseLog>>
        ? result.failure.message
        : null;
    final known =
        result is Success<List<MedicationDoseLog>> || calendar.hasLoaded;
    emit(
      current.copyWith(
        calendar: MedicationCalendarState(
          month: month,
          doses: computed,
          hasLoaded: known,
          error: error,
        ),
        doses: MedicationDosesState(
          date: current.doses.date,
          doses: computed
              .where((dose) => _sameDay(dose.scheduledDate, current.doses.date))
              .toList(),
          hasLoaded: known,
          error: error,
          followsToday: current.doses.followsToday,
        ),
      ),
    );
  }

  void selectCalendarDay(DateTime date) {
    if (isClosed) return;
    final loaded = state;
    if (loaded is! MedicationsLoaded ||
        loaded.calendar == null ||
        loaded.pendingAction != null ||
        loaded.isRefreshing) {
      return;
    }
    final calendar = loaded.calendar!;
    if (date.year != calendar.month.year ||
        date.month != calendar.month.month) {
      return;
    }
    ++_dosesRequest;
    emit(
      loaded.copyWith(
        clearActionError: !_sameDay(date, loaded.doses.date),
        doses: MedicationDosesState(
          date: _day(date),
          doses: calendar.doses
              .where((dose) => _sameDay(dose.scheduledDate, date))
              .toList(),
          hasLoaded: calendar.hasLoaded,
          isLoading: calendar.isLoading,
          error: calendar.error,
          followsToday: _sameDay(date, now()),
        ),
      ),
    );
  }

  Future<void> saveDose(
    MedicationDose dose,
    MedicationDoseStatus status, {
    DateTime? givenAt,
  }) => performAction(
    SaveMedicationDoseAction(
      dose.medication.id,
      MedicationDoseLog(
        periodId: dose.period.id,
        scheduledDate: dose.scheduledDate,
        scheduledMinute: dose.scheduledMinute,
        status: status,
        givenAt: status == MedicationDoseStatus.given ? givenAt ?? now() : null,
      ),
    ),
  );

  Future<void> performAction(MedicationAction action) async {
    if (isClosed) return;
    final loaded = state;
    if (loaded is! MedicationsLoaded ||
        loaded.pendingAction != null ||
        loaded.isRefreshing ||
        loaded.doses.isLoading ||
        !_canPerform(loaded, action)) {
      return;
    }
    final owner = loaded.medications
        .firstWhere((m) => m.id == action.medicationId)
        .petId;
    ++_loadRequest;
    ++_dosesRequest;
    ++_calendarRequest;
    emit(loaded.copyWith(pendingAction: action, clearActionError: true));
    final result = await switch (action) {
      DeleteMedicationAction() => _repository.deleteMedication(
        owner,
        action.medicationId,
      ),
      DeleteMedicationPeriodAction() => _repository.deletePeriod(
        owner,
        action.medicationId,
        action.periodId,
      ),
      SaveMedicationDoseAction() => _repository.saveDoseLog(
        owner,
        action.medicationId,
        action.log,
      ),
      ClearMedicationDoseAction() => _repository.clearDoseLog(
        owner,
        action.medicationId,
        periodId: action.log.periodId,
        scheduledDate: action.log.scheduledDate,
        scheduledMinute: action.log.scheduledMinute,
      ),
    };
    if (isClosed) return;
    final current = state as MedicationsLoaded;
    switch (result) {
      case Success<void>():
        if (action is DeleteMedicationAction &&
            current.medicationId == action.medicationId) {
          emit(MedicationDeleted(action.medicationId));
          return;
        }
        final medications = switch (action) {
          DeleteMedicationAction() =>
            current.medications
                .where((m) => m.id != action.medicationId)
                .toList(),
          DeleteMedicationPeriodAction() =>
            current.medications
                .map(
                  (m) => m.id != action.medicationId
                      ? m
                      : Medication(
                          id: m.id,
                          petId: m.petId,
                          name: m.name,
                          periods: m.periods
                              .where((p) => p.id != action.periodId)
                              .toList(),
                        ),
                )
                .toList(),
          _ => current.medications,
        };
        final logs = _logs(current.doses);
        if (action case SaveMedicationDoseAction(:final log)) {
          logs.removeWhere((old) => _sameDose(old, log));
          logs.add(log);
        } else if (action case ClearMedicationDoseAction(:final log)) {
          logs.removeWhere((old) => _sameDose(old, log));
        }
        emit(
          current.copyWith(
            medications: medications,
            clearPendingAction: true,
            clearActionError: true,
            lastMutation: (petId: owner, action: action),
            mutationRevision: current.mutationRevision + 1,
            calendar: current.calendar == null
                ? null
                : MedicationCalendarState(
                    month: current.calendar!.month,
                    doses: _calendarDoses(
                      medications,
                      _updatedCalendarLogs(current.calendar!, action),
                      current.calendar!.month,
                    ),
                    hasLoaded: current.calendar!.hasLoaded,
                    error: current.calendar!.error,
                  ),
            doses: MedicationDosesState(
              date: current.doses.date,
              doses: _doses(medications, logs, current.doses.date),
              hasLoaded: current.doses.hasLoaded,
              error: current.doses.error,
              followsToday: current.doses.followsToday,
            ),
          ),
        );
        await refreshForClockChange();
      case Error<void>():
        emit(
          current.copyWith(
            clearPendingAction: true,
            failedAction: action,
            actionError: result.failure.message,
          ),
        );
    }
  }

  bool _canPerform(
    MedicationsLoaded loaded,
    MedicationAction action, {
    bool retainingFailure = false,
  }) {
    final medication = loaded.medications
        .where(
          (m) =>
              m.id == action.medicationId &&
              (loaded.petId == null || m.petId == loaded.petId),
        )
        .firstOrNull;
    if (medication == null || _removedPets.contains(medication.petId)) {
      return false;
    }
    if (loaded.petId == null &&
        (!_active && !retainingFailure ||
            _dirty ||
            loaded.refreshError != null ||
            !_petIds.contains(medication.petId) ||
            _selectedPetId != null && _selectedPetId != medication.petId)) {
      return false;
    }
    switch (action) {
      case DeleteMedicationAction():
        return true;
      case DeleteMedicationPeriodAction():
        return medication.periods.length > 1 &&
            medication.periods.any(
              (p) =>
                  p.id == action.periodId &&
                  calendarDayNumber(p.startDate) > calendarDayNumber(now()),
            );
      case SaveMedicationDoseAction(:final log):
      case ClearMedicationDoseAction(:final log):
        if (!retainingFailure && !loaded.doses.hasLoaded ||
            calendarDayNumber(log.scheduledDate) > calendarDayNumber(now())) {
          return false;
        }
        final dose = loaded.doses.doses
            .where(
              (d) =>
                  d.medication.id == action.medicationId &&
                  d.period.id == log.periodId &&
                  _sameDay(d.scheduledDate, log.scheduledDate) &&
                  d.scheduledMinute == log.scheduledMinute,
            )
            .firstOrNull;
        return dose != null &&
            (retainingFailure || loaded.doses.error == null) &&
            (action is! ClearMedicationDoseAction || dose.log != null) &&
            (action is! SaveMedicationDoseAction ||
                log.status == MedicationDoseStatus.skipped ||
                log.givenAt != null && !log.givenAt!.isAfter(now()));
    }
  }

  /// Called by the screen's clock/lifecycle observer; forms own separate state.
  Future<void> refreshForClockChange() async {
    if (isClosed) return;
    final loaded = state;
    if (loaded is! MedicationsLoaded ||
        loaded.isRefreshing ||
        loaded.pendingAction != null ||
        loaded.petId == null && (!_active || _dirty)) {
      return;
    }
    final currentTime = now();
    // Keep a failed dose's day visible until it is retried or deliberately left.
    final keepFailedDose =
        loaded.failedAction is SaveMedicationDoseAction ||
        loaded.failedAction is ClearMedicationDoseAction;
    emit(loaded.copyWith(currentTime: currentTime));
    final unknownGlobalResults =
        loaded.petId == null &&
        !loaded.doses.hasLoaded &&
        !loaded.doses.isLoading &&
        loaded.doses.error == null;
    if (loaded.vetVisitId == null &&
        (unknownGlobalResults ||
            loaded.doses.followsToday &&
                !keepFailedDose &&
                !_sameDay(loaded.doses.date, currentTime))) {
      if (loaded.calendar != null) {
        final month = DateTime(currentTime.year, currentTime.month);
        if (loaded.calendar!.month == month) {
          selectCalendarDay(currentTime);
        } else {
          await loadCalendar(month);
          if (!isClosed) selectCalendarDay(currentTime);
        }
      } else {
        await loadDoses(
          loaded.doses.followsToday && !keepFailedDose
              ? currentTime
              : loaded.doses.date,
        );
      }
    }
  }

  void removeDeletedMedication(String medicationId, {String? petId}) {
    if (isClosed) return;
    final loaded = state;
    if (loaded is MedicationsLoaded && loaded.pendingAction != null) return;
    final owner =
        petId ??
        (loaded is MedicationsLoaded
            ? loaded.medications
                      .where((m) => m.id == medicationId)
                      .firstOrNull
                      ?.petId ??
                  loaded.petId
            : null);
    if (owner == null) return;
    _removedMedications.add((owner, medicationId));
    if (loaded is! MedicationsLoaded) return;
    if (loaded.medicationId == medicationId && loaded.petId == owner) {
      ++_loadRequest;
      ++_dosesRequest;
      emit(MedicationDeleted(medicationId));
      return;
    }
    _prune(loaded);
  }

  void removeDeletedPet(String petId) {
    if (isClosed) return;
    _removedPets.add(petId);
    final loaded = state;
    if (loaded is MedicationsLoaded) _prune(loaded);
  }

  void _prune(MedicationsLoaded loaded) {
    final medications = _remaining(loaded.medications);
    final failed = loaded.failedAction;
    emit(
      loaded.copyWith(
        medications: medications,
        clearActionError:
            failed != null &&
            !medications.any((m) => m.id == failed.medicationId),
        calendar: loaded.calendar == null
            ? null
            : MedicationCalendarState(
                month: loaded.calendar!.month,
                doses: _calendarDoses(
                  medications,
                  _calendarLogs(loaded.calendar!),
                  loaded.calendar!.month,
                ),
                hasLoaded: loaded.calendar!.hasLoaded,
                isLoading: loaded.calendar!.isLoading,
                error: loaded.calendar!.error,
              ),
        doses: MedicationDosesState(
          date: loaded.doses.date,
          doses: _doses(medications, _logs(loaded.doses), loaded.doses.date),
          hasLoaded: loaded.doses.hasLoaded,
          isLoading: loaded.doses.isLoading,
          error: loaded.doses.error,
          followsToday: loaded.doses.followsToday,
        ),
      ),
    );
  }

  List<MedicationDose> _doses(
    List<Medication> medications,
    List<MedicationDoseLog> logs,
    DateTime date,
  ) => _calculateDoses(
    medications: medications,
    logs: logs,
    fromDate: date,
    toDate: date,
  );

  List<MedicationDoseLog> _logs(MedicationDosesState state) => state.doses
      .map((dose) => dose.log)
      .whereType<MedicationDoseLog>()
      .toList();

  List<MedicationDose> _calendarDoses(
    List<Medication> medications,
    List<MedicationDoseLog> logs,
    DateTime month,
  ) => _calculateDoses(
    medications: medications,
    logs: logs,
    fromDate: month,
    toDate: DateTime(month.year, month.month + 1, 0),
  );

  List<MedicationDoseLog> _calendarLogs(MedicationCalendarState calendar) =>
      calendar.doses
          .map((dose) => dose.log)
          .whereType<MedicationDoseLog>()
          .toList();

  List<MedicationDoseLog> _updatedCalendarLogs(
    MedicationCalendarState calendar,
    MedicationAction action,
  ) {
    final logs = _calendarLogs(calendar);
    if (action case SaveMedicationDoseAction(:final log)) {
      logs.removeWhere((old) => _sameDose(old, log));
      logs.add(log);
    } else if (action case ClearMedicationDoseAction(:final log)) {
      logs.removeWhere((old) => _sameDose(old, log));
    }
    return logs;
  }

  bool _sameDose(MedicationDoseLog a, MedicationDoseLog b) =>
      a.periodId == b.periodId &&
      _sameDay(a.scheduledDate, b.scheduledDate) &&
      a.scheduledMinute == b.scheduledMinute;

  bool _sameDay(DateTime a, DateTime b) =>
      calendarDayNumber(a) == calendarDayNumber(b);
  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}
