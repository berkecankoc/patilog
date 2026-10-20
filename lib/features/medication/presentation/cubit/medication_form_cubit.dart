import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_suggestions.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/create_medication.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_form_state.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';

final class MedicationFormCubit extends Cubit<MedicationFormState> {
  final MedicationRepository _repository;
  final VetVisitRepository _vetVisitRepository;
  final CreateMedication _createMedication;
  final IdGenerator _idGenerator;
  int _suggestionsRequest = 0;
  int _visitsRequest = 0;
  int _periodRequest = 0;

  MedicationFormCubit(
    this._repository,
    this._vetVisitRepository,
    this._createMedication,
    this._idGenerator,
  ) : super(const MedicationFormState());

  Future<void> loadSuggestions({String? clinicName}) async {
    if (isClosed || state.isSaved) return;
    final request = ++_suggestionsRequest;
    emit(
      state.copyWith(
        isLoadingSuggestions: true,
        clearSuggestionsError: true,
        suggestions: MedicationSuggestions(
          medicationNames: state.suggestions.medicationNames,
          clinicNames: state.suggestions.clinicNames,
          veterinarianNames: const [],
        ),
      ),
    );
    final result = await _repository.getSuggestions(clinicName: clinicName);
    if (isClosed || request != _suggestionsRequest) return;
    switch (result) {
      case Success<MedicationSuggestions>():
        emit(
          state.copyWith(suggestions: result.data, isLoadingSuggestions: false),
        );
      case Error<MedicationSuggestions>():
        emit(
          state.copyWith(
            isLoadingSuggestions: false,
            suggestionsError: result.failure.message,
          ),
        );
    }
  }

  Future<void> loadVisits(String petId) async {
    if (isClosed || state.isSaved) return;
    final request = ++_visitsRequest;
    emit(
      state.copyWith(
        visitsPetId: petId,
        visits: state.visitsPetId == petId ? state.visits : const [],
        isLoadingVisits: true,
        clearVisitsError: true,
      ),
    );
    final result = await _vetVisitRepository.getVetVisits(petId);
    if (isClosed || request != _visitsRequest) return;
    switch (result) {
      case Success<List<VetVisit>>():
        emit(
          state.copyWith(
            visits: List.unmodifiable(result.data),
            isLoadingVisits: false,
          ),
        );
      case Error<List<VetVisit>>():
        emit(
          state.copyWith(
            isLoadingVisits: false,
            visitsError: result.failure.message,
          ),
        );
    }
  }

  Future<void> checkPeriod(
    String petId,
    String medicationId,
    String periodId,
  ) async {
    if (isClosed || state.isSaved || state.isSaving) return;
    final request = ++_periodRequest;
    emit(
      state.copyWith(
        periodKey: (
          petId: petId,
          medicationId: medicationId,
          periodId: periodId,
        ),
        isCheckingPeriod: true,
        clearPeriodCheck: true,
        clearPeriodError: true,
      ),
    );
    final result = await _repository.hasDoseLogs(petId, medicationId, periodId);
    if (isClosed || request != _periodRequest) return;
    switch (result) {
      case Success<bool>():
        emit(state.copyWith(hasDoseLogs: result.data, isCheckingPeriod: false));
      case Error<bool>():
        emit(
          state.copyWith(
            isCheckingPeriod: false,
            periodError: result.failure.message,
          ),
        );
    }
  }

  Future<void> createMedication(CreateMedicationParams params) =>
      _save(() => _createMedication(params));

  Future<void> renameMedication(
    String petId,
    String medicationId,
    String name,
  ) => _save(() => _repository.renameMedication(petId, medicationId, name));

  Future<void> savePeriod({
    required String petId,
    required String medicationId,
    String? periodId,
    required DateTime startDate,
    DateTime? endDate,
    required int intervalDays,
    required List<int> doseTimes,
    String? dosageInstructions,
    String? vetVisitId,
    String? clinicName,
    String? veterinarianName,
    String? notes,
  }) {
    if (periodId != null &&
        (state.isCheckingPeriod ||
            state.hasDoseLogs == null ||
            state.periodKey !=
                (
                  petId: petId,
                  medicationId: medicationId,
                  periodId: periodId,
                ))) {
      return Future.value();
    }
    return _save(() {
      final period = MedicationPeriod(
        id: periodId ?? _idGenerator.generate(),
        medicationId: medicationId,
        startDate: startDate,
        endDate: endDate,
        intervalDays: intervalDays,
        doseTimes: doseTimes,
        dosageInstructions: dosageInstructions,
        vetVisitId: vetVisitId,
        clinicName: clinicName,
        veterinarianName: veterinarianName,
        notes: notes,
      );
      return periodId == null
          ? _repository.createPeriod(petId, period)
          : _repository.updatePeriod(petId, period);
    });
  }

  Future<void> _save(Future<Result<void>> Function() write) async {
    if (isClosed || state.isSaving || state.isSaved) return;
    emit(state.copyWith(isSaving: true, clearSaveError: true));
    final result = await write();
    if (isClosed) return;
    switch (result) {
      case Success<void>():
        // A saved form is terminal, including any late option/check responses.
        ++_suggestionsRequest;
        ++_visitsRequest;
        ++_periodRequest;
        emit(
          state.copyWith(
            isSaving: false,
            isSaved: true,
            isLoadingSuggestions: false,
            isLoadingVisits: false,
            isCheckingPeriod: false,
          ),
        );
      case Error<void>():
        emit(
          state.copyWith(isSaving: false, saveError: result.failure.message),
        );
    }
  }
}
