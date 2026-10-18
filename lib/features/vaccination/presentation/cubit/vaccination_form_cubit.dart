import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_state.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';

final class VaccinationFormCubit extends Cubit<VaccinationFormState> {
  final VaccinationRepository repository;
  final VetVisitRepository _vetVisitRepository;
  final SaveVaccination _saveVaccination;
  int _suggestionsRequest = 0;
  int _visitsRequest = 0;

  VaccinationFormCubit(
    this.repository,
    this._vetVisitRepository,
    this._saveVaccination,
  ) : super(const VaccinationFormState());

  Future<void> loadSuggestions({String? clinicName}) async {
    if (isClosed || state.isSaved) return;
    final request = ++_suggestionsRequest;
    emit(
      state.copyWith(
        isLoadingSuggestions: true,
        clearSuggestionsError: true,
        suggestions: VaccinationSuggestions(
          vaccineNames: state.suggestions.vaccineNames,
          clinicNames: state.suggestions.clinicNames,
          veterinarianNames: const [],
        ),
      ),
    );
    final result = await repository.getSuggestions(clinicName: clinicName);
    if (isClosed || request != _suggestionsRequest) return;

    switch (result) {
      case Success<VaccinationSuggestions>():
        emit(
          state.copyWith(suggestions: result.data, isLoadingSuggestions: false),
        );
      case Error<VaccinationSuggestions>():
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
        visits: state.visitsPetId == petId ? state.visits : const [],
        visitsPetId: petId,
        isLoadingVisits: true,
        clearVisitsError: true,
      ),
    );
    final result = await _vetVisitRepository.getVetVisits(petId);
    if (isClosed || request != _visitsRequest) return;

    switch (result) {
      case Success<List<VetVisit>>():
        emit(state.copyWith(visits: result.data, isLoadingVisits: false));
      case Error<List<VetVisit>>():
        emit(
          state.copyWith(
            isLoadingVisits: false,
            visitsError: result.failure.message,
          ),
        );
    }
  }

  Future<void> saveVaccination(SaveVaccinationParams params) async {
    if (isClosed || state.isSaving || state.isSaved) return;
    emit(state.copyWith(isSaving: true, clearSaveError: true));
    final result = await _saveVaccination(params);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        // Saving is terminal; late option responses cannot trigger another update.
        ++_suggestionsRequest;
        ++_visitsRequest;
        emit(
          state.copyWith(
            isSaving: false,
            isSaved: true,
            isLoadingSuggestions: false,
            isLoadingVisits: false,
          ),
        );
      case Error<void>():
        emit(
          state.copyWith(isSaving: false, saveError: result.failure.message),
        );
    }
  }
}
