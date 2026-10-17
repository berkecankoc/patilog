import 'package:equatable/equatable.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

final class VaccinationFormState extends Equatable {
  final bool isSaving;
  final bool isSaved;
  final String? saveError;
  final VaccinationSuggestions suggestions;
  final bool isLoadingSuggestions;
  final String? suggestionsError;
  final List<VetVisit> visits;
  final String? visitsPetId;
  final bool isLoadingVisits;
  final String? visitsError;

  const VaccinationFormState({
    this.isSaving = false,
    this.isSaved = false,
    this.saveError,
    this.suggestions = const VaccinationSuggestions(
      vaccineNames: [],
      clinicNames: [],
      veterinarianNames: [],
    ),
    this.isLoadingSuggestions = false,
    this.suggestionsError,
    this.visits = const [],
    this.visitsPetId,
    this.isLoadingVisits = false,
    this.visitsError,
  });

  VaccinationFormState copyWith({
    bool? isSaving,
    bool? isSaved,
    String? saveError,
    bool clearSaveError = false,
    VaccinationSuggestions? suggestions,
    bool? isLoadingSuggestions,
    String? suggestionsError,
    bool clearSuggestionsError = false,
    List<VetVisit>? visits,
    String? visitsPetId,
    bool? isLoadingVisits,
    String? visitsError,
    bool clearVisitsError = false,
  }) => VaccinationFormState(
    isSaving: isSaving ?? this.isSaving,
    isSaved: isSaved ?? this.isSaved,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    suggestions: suggestions ?? this.suggestions,
    isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
    suggestionsError: clearSuggestionsError
        ? null
        : suggestionsError ?? this.suggestionsError,
    visits: visits ?? this.visits,
    visitsPetId: visitsPetId ?? this.visitsPetId,
    isLoadingVisits: isLoadingVisits ?? this.isLoadingVisits,
    visitsError: clearVisitsError ? null : visitsError ?? this.visitsError,
  );

  @override
  List<Object?> get props => [
    isSaving,
    isSaved,
    saveError,
    suggestions,
    isLoadingSuggestions,
    suggestionsError,
    visits,
    visitsPetId,
    isLoadingVisits,
    visitsError,
  ];
}
