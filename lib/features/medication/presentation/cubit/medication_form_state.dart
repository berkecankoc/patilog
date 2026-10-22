import 'package:equatable/equatable.dart';
import 'package:petlytics/features/medication/domain/entities/medication_suggestions.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

typedef MedicationPeriodKey = ({
  String petId,
  String medicationId,
  String periodId,
});

final class MedicationFormState extends Equatable {
  final bool isSaving;
  final bool isSaved;
  final String? saveError;
  final MedicationSuggestions suggestions;
  final bool isLoadingSuggestions;
  final String? suggestionsError;
  final List<VetVisit> visits;
  final String? visitsPetId;
  final bool isLoadingVisits;
  final String? visitsError;
  final MedicationPeriodKey? periodKey;
  final bool isCheckingPeriod;
  final bool? hasDoseLogs;
  final String? periodError;

  const MedicationFormState({
    this.isSaving = false,
    this.isSaved = false,
    this.saveError,
    this.suggestions = const MedicationSuggestions(
      medicationNames: [],
      clinicNames: [],
      veterinarianNames: [],
    ),
    this.isLoadingSuggestions = false,
    this.suggestionsError,
    this.visits = const [],
    this.visitsPetId,
    this.isLoadingVisits = false,
    this.visitsError,
    this.periodKey,
    this.isCheckingPeriod = false,
    this.hasDoseLogs,
    this.periodError,
  });

  MedicationFormState copyWith({
    bool? isSaving,
    bool? isSaved,
    String? saveError,
    bool clearSaveError = false,
    MedicationSuggestions? suggestions,
    bool? isLoadingSuggestions,
    String? suggestionsError,
    bool clearSuggestionsError = false,
    List<VetVisit>? visits,
    String? visitsPetId,
    bool? isLoadingVisits,
    String? visitsError,
    bool clearVisitsError = false,
    MedicationPeriodKey? periodKey,
    bool? isCheckingPeriod,
    bool? hasDoseLogs,
    bool clearPeriodCheck = false,
    String? periodError,
    bool clearPeriodError = false,
  }) => MedicationFormState(
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
    periodKey: periodKey ?? this.periodKey,
    isCheckingPeriod: isCheckingPeriod ?? this.isCheckingPeriod,
    hasDoseLogs: clearPeriodCheck ? null : hasDoseLogs ?? this.hasDoseLogs,
    periodError: clearPeriodError ? null : periodError ?? this.periodError,
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
    periodKey,
    isCheckingPeriod,
    hasDoseLogs,
    periodError,
  ];
}
