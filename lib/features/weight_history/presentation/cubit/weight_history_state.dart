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
  final List<WeightEntry> entries;
  final bool isDeleting;
  final WeightEntry? deletionEntry;
  final String? deleteError;

  const WeightHistoryLoaded(
    this.entries, {
    this.isDeleting = false,
    this.deletionEntry,
    this.deleteError,
  });

  @override
  List<Object?> get props => [entries, isDeleting, deletionEntry, deleteError];
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
  final String message;
  const WeightHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}
