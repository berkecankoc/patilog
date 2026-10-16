import 'package:equatable/equatable.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';

final class VetVisitFormState extends Equatable {
  final bool isSaving;
  final bool isSaved;
  final String? saveError;
  final VetVisitSuggestions suggestions;
  final bool isLoadingSuggestions;
  final String? suggestionsError;

  const VetVisitFormState({
    this.isSaving = false,
    this.isSaved = false,
    this.saveError,
    this.suggestions = const VetVisitSuggestions(
      clinicNames: [],
      veterinarianNames: [],
    ),
    this.isLoadingSuggestions = false,
    this.suggestionsError,
  });

  VetVisitFormState copyWith({
    bool? isSaving,
    bool? isSaved,
    String? saveError,
    bool clearSaveError = false,
    VetVisitSuggestions? suggestions,
    bool? isLoadingSuggestions,
    String? suggestionsError,
    bool clearSuggestionsError = false,
  }) => VetVisitFormState(
    isSaving: isSaving ?? this.isSaving,
    isSaved: isSaved ?? this.isSaved,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    suggestions: suggestions ?? this.suggestions,
    isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
    suggestionsError: clearSuggestionsError
        ? null
        : suggestionsError ?? this.suggestionsError,
  );

  @override
  List<Object?> get props => [
    isSaving,
    isSaved,
    saveError,
    suggestions,
    isLoadingSuggestions,
    suggestionsError,
  ];
}
