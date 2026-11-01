import 'package:equatable/equatable.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';

final class FeedingFormState extends Equatable {
  final bool isSaving;
  final Failure? saveFailure;
  final FeedingPlan? savedPlan;
  final FeedingEntry? savedEntry;

  const FeedingFormState({
    this.isSaving = false,
    this.saveFailure,
    this.savedPlan,
    this.savedEntry,
  });

  bool get isSaved => savedPlan != null || savedEntry != null;

  @override
  List<Object?> get props => [isSaving, saveFailure, savedPlan, savedEntry];
}
