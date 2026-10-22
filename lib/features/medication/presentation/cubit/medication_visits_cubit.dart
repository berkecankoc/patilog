import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

/// Each schedule's linked visit keeps its own loading/error/result state.
class MedicationVisitsCubit extends Cubit<Map<String, VetVisitState>> {
  final VetVisitRepository repository;
  final _requests = <String, int>{};
  String? _petId;
  int _serial = 0;
  MedicationVisitsCubit(this.repository) : super(const {});

  Future<void> loadVisit(String petId, String visitId) async {
    if (isClosed) return;
    if (_petId != petId) {
      _petId = petId;
      _requests.clear();
      emit(const {});
    }
    final request = ++_serial;
    _requests[visitId] = request;
    final previous = state[visitId];
    emit({
      ...state,
      visitId: previous is VetVisitLoaded
          ? VetVisitLoaded(previous.visit, isRefreshing: true)
          : const VetVisitLoading(),
    });
    final result = await repository.getVetVisitById(petId, visitId);
    if (isClosed || _petId != petId || _requests[visitId] != request) return;
    emit({
      ...state,
      visitId: switch (result) {
        Success<VetVisit>() => VetVisitLoaded(result.data),
        Error<VetVisit>() =>
          previous is VetVisitLoaded
              ? VetVisitLoaded(
                  previous.visit,
                  refreshError: result.failure.message,
                )
              : VetVisitError(result.failure.message),
      },
    });
  }
}
