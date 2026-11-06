import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_state.dart';

final class WeightHistoryCubit extends Cubit<WeightHistoryState> {
  final WeightHistoryRepository repository;
  final IdGenerator _idGenerator;
  int _loadRequest = 0;
  bool _dirty = false;
  Set<String> _petIds = {};
  String? _selectedPetId;
  final _removedPets = <String>{};
  final _removedEntries = <(String, String)>{};

  WeightHistoryCubit(this.repository, this._idGenerator)
    : super(const WeightHistoryInitial());

  bool get needsReload => _dirty || state is WeightHistoryInitial;

  void setPetContext(Iterable<String> petIds, {String? selectedPetId}) {
    _petIds = petIds.toSet();
    _selectedPetId = _petIds.contains(selectedPetId) ? selectedPetId : null;
  }

  void dismissDeletionError() {
    final current = state;
    if (!isClosed && current is WeightHistoryLoaded && !current.isDeleting) {
      emit(current.copyWith(clearDeletion: true));
    }
  }

  void invalidateList() {
    if (isClosed) return;
    _dirty = true;
    ++_loadRequest;
    final current = state;
    if (current is WeightHistoryLoaded && current.isRefreshing) {
      emit(current.copyWith(isRefreshing: false));
    }
  }

  List<WeightEntry> _remaining(Iterable<WeightEntry> entries) => entries
      .where(
        (entry) =>
            !_removedPets.contains(entry.petId) &&
            !_removedEntries.contains((entry.petId, entry.id)),
      )
      .toList();

  Future<void> loadWeightHistory(String petId) => _load(petId);
  Future<void> loadAllWeightHistory() => _load(null);

  Future<void> _load(String? petId) async {
    if (isClosed ||
        state is WeightHistoryLoaded &&
            (state as WeightHistoryLoaded).isDeleting) {
      return;
    }
    _dirty = false;
    final current = state;
    final previous = current is WeightHistoryLoaded && current.petId == petId
        ? current
        : null;
    final request = ++_loadRequest;
    emit(
      previous == null
          ? const WeightHistoryLoading()
          : previous.copyWith(isRefreshing: true, clearRefreshError: true),
    );
    final result = petId == null
        ? await repository.getAllWeightEntries()
        : await repository.getWeightEntries(petId);
    if (isClosed || request != _loadRequest) return;
    final latest = state;
    final retained = latest is WeightHistoryLoaded && latest.petId == petId
        ? latest
        : previous;

    switch (result) {
      case Success<List<WeightEntry>>():
        emit(WeightHistoryLoaded(_remaining(result.data), petId: petId));
      case Error<List<WeightEntry>>():
        emit(
          retained == null
              ? WeightHistoryError(result.failure)
              : retained.copyWith(
                  isRefreshing: false,
                  refreshError: result.failure.message,
                ),
        );
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
        emit(WeightHistoryError(result.failure));
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
        emit(WeightHistoryError(result.failure));
    }
  }

  Future<void> deleteWeightEntry(WeightEntry entry) async {
    final current = state;
    if (isClosed ||
        current is! WeightHistoryLoaded ||
        current.isDeleting ||
        current.isRefreshing ||
        _removedPets.contains(entry.petId) ||
        (current.petId == null
            ? !_petIds.contains(entry.petId) ||
                  (_selectedPetId != null && _selectedPetId != entry.petId)
            : current.petId != entry.petId) ||
        !current.entries.any(
          (item) => item.id == entry.id && item.petId == entry.petId,
        )) {
      return;
    }
    ++_loadRequest;
    emit(current.copyWith(isDeleting: true, deletionEntry: entry));
    final result = await repository.deleteWeightEntry(entry.id);
    if (isClosed) return;
    final latest = state is WeightHistoryLoaded
        ? state as WeightHistoryLoaded
        : current;

    switch (result) {
      case Success<void>():
        _removedEntries.add((entry.petId, entry.id));
        // The committed deletion is known; keep the list and its scroll state.
        emit(
          latest.copyWith(
            entries: _remaining(latest.entries),
            isDeleting: false,
            clearDeletion: true,
          ),
        );
      case Error<void>():
        emit(
          latest.copyWith(
            isDeleting: false,
            deletionEntry: entry,
            deleteError: result.failure.message,
          ),
        );
    }
  }

  void removeDeletedEntry(String id, {String? petId}) {
    if (isClosed) return;
    final current = state;
    final owner =
        petId ??
        (current is WeightHistoryLoaded
            ? current.entries
                  .where((entry) => entry.id == id)
                  .firstOrNull
                  ?.petId
            : null);
    if (owner == null) return;
    _removedEntries.add((owner, id));
    if (current is WeightHistoryLoaded) {
      emit(
        current.copyWith(
          entries: _remaining(current.entries),
          clearDeletion: current.deletionEntry?.id == id,
        ),
      );
    }
  }

  void removeDeletedPet(String petId) {
    if (isClosed) return;
    _removedPets.add(petId);
    final current = state;
    if (current is WeightHistoryLoaded) {
      emit(
        current.copyWith(
          entries: _remaining(current.entries),
          clearDeletion: current.deletionEntry?.petId == petId,
        ),
      );
    }
  }
}
