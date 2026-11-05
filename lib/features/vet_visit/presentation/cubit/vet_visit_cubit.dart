import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';

final class VetVisitCubit extends Cubit<VetVisitState> {
  final VetVisitRepository repository;
  int _loadRequest = 0;
  bool _dirty = false;
  Set<String> _petIds = {};
  String? _selectedPetId;
  final _removedPets = <String>{};
  final _removedRecords = <(String, String)>{};

  VetVisitCubit(this.repository) : super(const VetVisitInitial());

  bool get needsReload => _dirty || state is VetVisitInitial;

  void setPetContext(Iterable<String> petIds, {String? selectedPetId}) {
    _petIds = petIds.toSet();
    _selectedPetId = _petIds.contains(selectedPetId) ? selectedPetId : null;
  }

  void dismissDeletionError() {
    final current = state;
    if (!isClosed && current is VetVisitsLoaded && !current.isDeleting) {
      emit(current.copyWith(clearDeletion: true));
    }
  }

  bool _owns(VetVisitsLoaded loaded, VetVisit record) =>
      (loaded.petId == null
          ? _petIds.contains(record.petId) &&
                (_selectedPetId == null || _selectedPetId == record.petId)
          : loaded.petId == record.petId) &&
      !_removedPets.contains(record.petId);

  List<VetVisit> _remaining(Iterable<VetVisit> records) => List.unmodifiable(
    records.where(
      (record) =>
          !_removedPets.contains(record.petId) &&
          !_removedRecords.contains((record.petId, record.id)),
    ),
  );

  bool get _canLoad =>
      !isClosed &&
      switch (state) {
        VetVisitsLoaded(isDeleting: true) ||
        VetVisitLoaded(isDeleting: true) ||
        VetVisitDeleted() => false,
        _ => true,
      };

  void invalidateList() {
    if (isClosed) return;
    _dirty = true;
    ++_loadRequest;
    final current = state;
    if (current is VetVisitsLoaded && current.isRefreshing) {
      emit(current.copyWith(isRefreshing: false));
    }
  }

  Future<void> loadVetVisits(String petId) => _loadList(petId);

  Future<void> loadAllVetVisits() => _loadList(null);

  Future<void> _loadList(String? petId) async {
    if (!_canLoad) return;
    _dirty = false;
    final request = ++_loadRequest;
    final current = state;
    final previous = current is VetVisitsLoaded && current.petId == petId
        ? current
        : null;
    emit(
      previous == null
          ? const VetVisitLoading()
          : previous.copyWith(
              isRefreshing: true,
              clearRefreshError: true,
              clearDeletion: true,
            ),
    );
    final result = petId == null
        ? await repository.getAllVetVisits()
        : await repository.getVetVisits(petId);
    if (isClosed || request != _loadRequest) return;
    final latest = state;
    final retained = latest is VetVisitsLoaded && latest.petId == petId
        ? latest
        : previous;
    switch (result) {
      case Success<List<VetVisit>>():
        emit(VetVisitsLoaded(petId, _remaining(result.data)));
      case Error<List<VetVisit>>():
        emit(
          retained == null
              ? VetVisitError(result.failure)
              : retained.copyWith(
                  isRefreshing: false,
                  refreshError: result.failure.message,
                ),
        );
    }
  }

  Future<void> loadVetVisit(String petId, String visitId) async {
    if (!_canLoad) return;
    final request = ++_loadRequest;
    final current = state;
    final previous =
        current is VetVisitLoaded &&
            current.visit.petId == petId &&
            current.visit.id == visitId
        ? current
        : null;
    emit(
      previous == null
          ? const VetVisitLoading()
          : VetVisitLoaded(previous.visit, isRefreshing: true),
    );
    final result = await repository.getVetVisitById(petId, visitId);
    if (isClosed || request != _loadRequest) return;

    switch (result) {
      case Success<VetVisit>():
        emit(VetVisitLoaded(result.data));
      case Error<VetVisit>():
        emit(
          previous == null || result.failure is NotFoundFailure
              ? VetVisitError(result.failure)
              : VetVisitLoaded(
                  previous.visit,
                  refreshError: result.failure.message,
                ),
        );
    }
  }

  Future<void> deleteVetVisit() async {
    final current = state;
    if (isClosed || current is! VetVisitLoaded || current.isDeleting) return;
    // A refresh started before this write must not restore a deleted record.
    ++_loadRequest;
    final visit = current.visit;
    emit(VetVisitLoaded(visit, isDeleting: true));
    final result = await repository.deleteVetVisit(visit.petId, visit.id);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(VetVisitDeleted(visit.id));
      case Error<void>():
        emit(VetVisitLoaded(visit, deleteError: result.failure.message));
    }
  }

  Future<void> deleteListedVisit(VetVisit record) async {
    final current = state;
    if (isClosed ||
        current is! VetVisitsLoaded ||
        current.isDeleting ||
        current.isRefreshing ||
        !_owns(current, record)) {
      return;
    }
    final target = current.visits
        .where((item) => item.id == record.id && item.petId == record.petId)
        .firstOrNull;
    if (target == null) return;
    ++_loadRequest;
    emit(
      current.copyWith(
        isDeleting: true,
        deletionVisit: target,
        clearRefreshError: true,
      ),
    );
    final result = await repository.deleteVetVisit(target.petId, target.id);
    if (isClosed) return;
    final latest = state is VetVisitsLoaded
        ? state as VetVisitsLoaded
        : current;
    switch (result) {
      case Success<void>():
        _removedRecords.add((target.petId, target.id));
        emit(
          latest.copyWith(
            visits: _remaining(latest.visits),
            isDeleting: false,
            clearDeletion: true,
          ),
        );
      case Error<void>():
        emit(
          latest.copyWith(
            isDeleting: false,
            deletionVisit: target,
            deleteError: result.failure.message,
          ),
        );
    }
  }

  /// Known deletions also reconcile a read that is already in flight.
  void removeDeletedVisit(String id, {String? petId}) {
    if (isClosed) return;
    final current = state;
    final owner =
        petId ??
        (current is VetVisitsLoaded
            ? current.visits
                      .where((item) => item.id == id)
                      .firstOrNull
                      ?.petId ??
                  current.petId
            : null);
    if (owner == null) return;
    _removedRecords.add((owner, id));
    if (current is VetVisitsLoaded) {
      if (current.petId != null) ++_loadRequest;
      emit(
        current.copyWith(
          visits: _remaining(current.visits),
          isRefreshing: current.petId == null ? null : false,
          clearRefreshError: current.petId != null,
          clearDeletion:
              current.deletionVisit?.id == id &&
              current.deletionVisit?.petId == owner,
        ),
      );
    }
  }

  void removeDeletedPet(String petId) {
    if (isClosed) return;
    _removedPets.add(petId);
    final current = state;
    if (current is VetVisitsLoaded) {
      emit(
        current.copyWith(
          visits: _remaining(current.visits),
          clearDeletion: current.deletionVisit?.petId == petId,
        ),
      );
    }
  }
}
