import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_state.dart';

final class WeightHistoryCubit extends Cubit<WeightHistoryState> {
  final WeightHistoryRepository repository;
  final IdGenerator _idGenerator;

  WeightHistoryCubit(this.repository, this._idGenerator)
    : super(const WeightHistoryInitial());

  Future<void> loadWeightHistory(String petId) async {
    emit(const WeightHistoryLoading());
    final result = await repository.getWeightEntries(petId);
    if (isClosed) return;

    switch (result) {
      case Success<List<WeightEntry>>():
        emit(WeightHistoryLoaded(result.data));
      case Error<List<WeightEntry>>():
        emit(WeightHistoryError(result.failure.message));
    }
  }

  Future<void> createWeightEntry({
    required String petId,
    required double weight,
    required DateTime measuredAt,
  }) async {
    emit(const WeightHistoryLoading());
    final entry = WeightEntry(
      id: _idGenerator.generate(),
      petId: petId,
      weight: weight,
      measuredAt: measuredAt,
    );
    final result = await repository.createWeightEntry(entry);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(const WeightEntryCreated());
      case Error<void>():
        emit(WeightHistoryError(result.failure.message));
    }
  }

  Future<void> updateWeightEntry(
    WeightEntry entry, {
    required double weight,
    required DateTime measuredAt,
  }) async {
    emit(const WeightHistoryLoading());
    final updated = WeightEntry(
      id: entry.id,
      petId: entry.petId,
      weight: weight,
      measuredAt: measuredAt,
    );
    final result = await repository.updateWeightEntry(updated);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(const WeightEntryUpdated());
      case Error<void>():
        emit(WeightHistoryError(result.failure.message));
    }
  }

  Future<void> deleteWeightEntry(WeightEntry entry) async {
    emit(const WeightHistoryLoading());
    final result = await repository.deleteWeightEntry(entry.id);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        await loadWeightHistory(entry.petId);
      case Error<void>():
        emit(WeightHistoryError(result.failure.message));
    }
  }
}
