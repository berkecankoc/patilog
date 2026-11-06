import 'package:petlytics/core/error/failure.dart';
import 'package:equatable/equatable.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';

sealed class WeightHistoryState extends Equatable {
  const WeightHistoryState();
}

final class WeightHistoryInitial extends WeightHistoryState {
  const WeightHistoryInitial();

  @override
  List<Object?> get props => [];
}

final class WeightHistoryLoading extends WeightHistoryState {
  const WeightHistoryLoading();

  @override
  List<Object?> get props => [];
}

final class WeightHistoryLoaded extends WeightHistoryState {
  final String? petId;
  final List<WeightEntry> entries;
  final bool isDeleting;
  final WeightEntry? deletionEntry;
  final String? deleteError;
  final bool isRefreshing;
  final String? refreshError;

  const WeightHistoryLoaded(
    this.entries, {
    this.petId,
    this.isDeleting = false,
    this.deletionEntry,
    this.deleteError,
    this.isRefreshing = false,
    this.refreshError,
  });

  WeightHistoryLoaded copyWith({
    List<WeightEntry>? entries,
    bool? isDeleting,
    WeightEntry? deletionEntry,
    String? deleteError,
    bool clearDeletion = false,
    bool? isRefreshing,
    String? refreshError,
    bool clearRefreshError = false,
  }) => WeightHistoryLoaded(
    entries ?? this.entries,
    petId: petId,
    isDeleting: isDeleting ?? this.isDeleting,
    deletionEntry: clearDeletion ? null : deletionEntry ?? this.deletionEntry,
    deleteError: clearDeletion ? null : deleteError ?? this.deleteError,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
  );

  @override
  List<Object?> get props => [
    petId,
    entries,
    isDeleting,
    deletionEntry,
    deleteError,
    isRefreshing,
    refreshError,
  ];
}

final class WeightEntryCreated extends WeightHistoryState {
  const WeightEntryCreated();

  @override
  List<Object?> get props => [];
}

final class WeightEntryUpdated extends WeightHistoryState {
  const WeightEntryUpdated();

  @override
  List<Object?> get props => [];
}

final class WeightHistoryError extends WeightHistoryState {
  final Failure failure;
  const WeightHistoryError(this.failure);

  @override
  List<Object?> get props => [failure];
}
