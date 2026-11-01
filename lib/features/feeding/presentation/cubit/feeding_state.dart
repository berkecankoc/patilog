import 'package:equatable/equatable.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_occurrence.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';

sealed class FeedingState extends Equatable {
  const FeedingState();
}

final class FeedingInitial extends FeedingState {
  const FeedingInitial();
  @override
  List<Object?> get props => [];
}

final class FeedingLoading extends FeedingState {
  const FeedingLoading();
  @override
  List<Object?> get props => [];
}

final class FeedingError extends FeedingState {
  final Failure failure;
  const FeedingError(this.failure);
  @override
  List<Object?> get props => [failure];
}

final class FeedingLoaded extends FeedingState {
  /// Null is the intentional all-pets scope.
  final String? petId;
  final DateTime date;
  final DateTime currentTime;
  final int historyDays;
  final bool followsToday;
  final List<FeedingPlan> plans;
  final List<FeedingEntry> entries;
  final List<FeedingEntry> plannedEntries;
  final List<FeedingOccurrence> meals;
  final bool isRefreshing;
  final Failure? refreshFailure;
  final FeedingAction? pendingAction;
  final FeedingAction? failedAction;
  final Failure? actionFailure;
  final FeedingAction? lastMutation;
  final int mutationRevision;

  FeedingLoaded({
    this.petId,
    required this.date,
    required this.currentTime,
    required this.historyDays,
    required this.followsToday,
    required List<FeedingPlan> plans,
    required List<FeedingEntry> entries,
    required List<FeedingEntry> plannedEntries,
    required List<FeedingOccurrence> meals,
    this.isRefreshing = false,
    this.refreshFailure,
    this.pendingAction,
    this.failedAction,
    this.actionFailure,
    this.lastMutation,
    this.mutationRevision = 0,
  }) : plans = List.unmodifiable(plans),
       entries = List.unmodifiable(entries),
       plannedEntries = List.unmodifiable(plannedEntries),
       meals = List.unmodifiable(meals);

  DateTime get fromDate =>
      DateTime(date.year, date.month, date.day - historyDays + 1);
  DateTime get before => DateTime(date.year, date.month, date.day + 1);

  FeedingLoaded copyWith({
    DateTime? currentTime,
    List<FeedingPlan>? plans,
    List<FeedingEntry>? entries,
    List<FeedingEntry>? plannedEntries,
    List<FeedingOccurrence>? meals,
    bool? isRefreshing,
    Failure? refreshFailure,
    bool clearRefreshFailure = false,
    FeedingAction? pendingAction,
    bool clearPendingAction = false,
    FeedingAction? failedAction,
    Failure? actionFailure,
    bool clearActionFailure = false,
    FeedingAction? lastMutation,
    int? mutationRevision,
  }) => FeedingLoaded(
    petId: petId,
    date: date,
    currentTime: currentTime ?? this.currentTime,
    historyDays: historyDays,
    followsToday: followsToday,
    plans: plans ?? this.plans,
    entries: entries ?? this.entries,
    plannedEntries: plannedEntries ?? this.plannedEntries,
    meals: meals ?? this.meals,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    refreshFailure: clearRefreshFailure
        ? null
        : refreshFailure ?? this.refreshFailure,
    pendingAction: clearPendingAction
        ? null
        : pendingAction ?? this.pendingAction,
    failedAction: clearActionFailure ? null : failedAction ?? this.failedAction,
    actionFailure: clearActionFailure
        ? null
        : actionFailure ?? this.actionFailure,
    lastMutation: lastMutation ?? this.lastMutation,
    mutationRevision: mutationRevision ?? this.mutationRevision,
  );

  @override
  List<Object?> get props => [
    petId,
    date,
    currentTime,
    historyDays,
    followsToday,
    plans,
    entries,
    plannedEntries,
    meals,
    isRefreshing,
    refreshFailure,
    pendingAction,
    failedAction,
    actionFailure,
    lastMutation,
    mutationRevision,
  ];
}

/// Retains the failed intent; deletion/cancellation retries need fresh UI confirmation.
sealed class FeedingAction extends Equatable {
  final String petId;
  const FeedingAction(this.petId);
}

final class RecordFeedingMealAction extends FeedingAction {
  final FeedingEntry entry;
  RecordFeedingMealAction(this.entry) : super(entry.petId);
  @override
  List<Object?> get props => [entry];
}

final class DeleteFeedingEntryAction extends FeedingAction {
  final String entryId;
  const DeleteFeedingEntryAction(super.petId, this.entryId);
  @override
  List<Object?> get props => [petId, entryId];
}

final class CancelFeedingPlanAction extends FeedingAction {
  final String planId;
  const CancelFeedingPlanAction(super.petId, this.planId);
  @override
  List<Object?> get props => [petId, planId];
}
