import 'package:equatable/equatable.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';

final class FeedingFormState extends Equatable {
  final bool isSaving;
  final Failure? saveFailure;
  final FeedingPlan? savedPlan;
  final FeedingEntry? savedEntry;
  final String? plansPetId;
  final List<FeedingPlan> plans;
  final bool hasLoadedPlans;
  final bool isLoadingPlans;
  final Failure? plansFailure;

  const FeedingFormState({
    this.isSaving = false,
    this.saveFailure,
    this.savedPlan,
    this.savedEntry,
    this.plansPetId,
    this.plans = const [],
    this.hasLoadedPlans = false,
    this.isLoadingPlans = false,
    this.plansFailure,
  });

  bool get isSaved => savedPlan != null || savedEntry != null;

  FeedingFormState copyWith({
    bool? isSaving,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    FeedingPlan? savedPlan,
    FeedingEntry? savedEntry,
    String? plansPetId,
    List<FeedingPlan>? plans,
    bool? hasLoadedPlans,
    bool? isLoadingPlans,
    Failure? plansFailure,
    bool clearPlansFailure = false,
  }) => FeedingFormState(
    isSaving: isSaving ?? this.isSaving,
    saveFailure: clearSaveFailure ? null : saveFailure ?? this.saveFailure,
    savedPlan: savedPlan ?? this.savedPlan,
    savedEntry: savedEntry ?? this.savedEntry,
    plansPetId: plansPetId ?? this.plansPetId,
    plans: plans ?? this.plans,
    hasLoadedPlans: hasLoadedPlans ?? this.hasLoadedPlans,
    isLoadingPlans: isLoadingPlans ?? this.isLoadingPlans,
    plansFailure: clearPlansFailure ? null : plansFailure ?? this.plansFailure,
  );

  @override
  List<Object?> get props => [
    isSaving,
    saveFailure,
    savedPlan,
    savedEntry,
    plansPetId,
    plans,
    hasLoadedPlans,
    isLoadingPlans,
    plansFailure,
  ];
}
