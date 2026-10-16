import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_state.dart';

final class VetVisitFormCubit extends Cubit<VetVisitFormState> {
  final VetVisitRepository repository;
  final IdGenerator _idGenerator;
  int _suggestionsRequest = 0;

  VetVisitFormCubit(this.repository, this._idGenerator)
    : super(const VetVisitFormState());

  Future<void> loadSuggestions({String? clinicName}) async {
    if (isClosed || state.isSaved) return;
    final request = ++_suggestionsRequest;
    emit(
      state.copyWith(
        isLoadingSuggestions: true,
        clearSuggestionsError: true,
        // Do not offer a previous clinic's veterinarians for the new clinic.
        suggestions: VetVisitSuggestions(
          clinicNames: state.suggestions.clinicNames,
          veterinarianNames: const [],
        ),
      ),
    );
    final result = await repository.getSuggestions(clinicName: clinicName);
    if (isClosed || request != _suggestionsRequest) return;

    switch (result) {
      case Success<VetVisitSuggestions>():
        emit(
          state.copyWith(suggestions: result.data, isLoadingSuggestions: false),
        );
      case Error<VetVisitSuggestions>():
        emit(
          state.copyWith(
            isLoadingSuggestions: false,
            suggestionsError: result.failure.message,
          ),
        );
    }
  }

  Future<void> saveVetVisit({
    required String petId,
    required DateTime visitedOn,
    required String reason,
    String? visitId,
    String? clinicName,
    String? veterinarianName,
    String? diagnosis,
    String? notes,
    int? costMinorUnits,
    VetVisitCurrency? currency,
  }) async {
    if (isClosed || state.isSaving || state.isSaved) return;
    emit(state.copyWith(isSaving: true, clearSaveError: true));
    final visit = VetVisit(
      id: visitId ?? _idGenerator.generate(),
      petId: petId,
      visitedOn: visitedOn,
      reason: reason,
      clinicName: clinicName,
      veterinarianName: veterinarianName,
      diagnosis: diagnosis,
      notes: notes,
      costMinorUnits: costMinorUnits,
      currency: currency,
    );
    final result = visitId == null
        ? await repository.createVetVisit(visit)
        : await repository.updateVetVisit(visit);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        // Saving is terminal; late suggestions must not trigger another update.
        ++_suggestionsRequest;
        emit(
          state.copyWith(
            isSaving: false,
            isSaved: true,
            isLoadingSuggestions: false,
          ),
        );
      case Error<void>():
        emit(
          state.copyWith(isSaving: false, saveError: result.failure.message),
        );
    }
  }
}
