import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';

final class VetVisitCubit extends Cubit<VetVisitState> {
  final VetVisitRepository repository;
  int _loadRequest = 0;

  VetVisitCubit(this.repository) : super(const VetVisitInitial());

  bool get _canLoad =>
      !isClosed &&
      switch (state) {
        VetVisitsLoaded(isDeleting: true) ||
        VetVisitLoaded(isDeleting: true) ||
        VetVisitDeleted() => false,
        _ => true,
      };

  Future<void> loadVetVisits(String petId) async {
    if (!_canLoad) return;
    final request = ++_loadRequest;
    final current = state;
    final previous = current is VetVisitsLoaded && current.petId == petId
        ? current
        : null;
    emit(
      previous == null
          ? const VetVisitLoading()
          : VetVisitsLoaded(petId, previous.visits, isRefreshing: true),
    );
    final result = await repository.getVetVisits(petId);
    if (isClosed || request != _loadRequest) return;

    switch (result) {
      case Success<List<VetVisit>>():
        emit(VetVisitsLoaded(petId, result.data));
      case Error<List<VetVisit>>():
        emit(
          previous == null
              ? VetVisitError(result.failure.message)
              : VetVisitsLoaded(
                  petId,
                  previous.visits,
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
          previous == null
              ? VetVisitError(result.failure.message)
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

  Future<void> deleteListedVisit(VetVisit visit) async {
    final current = state;
    if (isClosed ||
        current is! VetVisitsLoaded ||
        current.isDeleting ||
        current.isRefreshing) {
      return;
    }
    final index = current.visits.indexWhere((item) => item.id == visit.id);
    if (index < 0 || current.petId != visit.petId) return;
    final target = current.visits[index];
    ++_loadRequest;
    emit(
      VetVisitsLoaded(
        current.petId,
        current.visits,
        isDeleting: true,
        deletionVisit: target,
      ),
    );
    final result = await repository.deleteVetVisit(current.petId, target.id);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(
          VetVisitsLoaded(
            current.petId,
            current.visits.where((item) => item.id != target.id).toList(),
          ),
        );
      case Error<void>():
        emit(
          VetVisitsLoaded(
            current.petId,
            current.visits,
            deletionVisit: target,
            deleteError: result.failure.message,
          ),
        );
    }
  }

  /// Applies a deletion confirmed by the detail route without another read.
  void removeDeletedVisit(String visitId) {
    final current = state;
    if (isClosed || current is! VetVisitsLoaded || current.isDeleting) return;
    ++_loadRequest;
    emit(
      VetVisitsLoaded(
        current.petId,
        current.visits.where((visit) => visit.id != visitId).toList(),
      ),
    );
  }
}
