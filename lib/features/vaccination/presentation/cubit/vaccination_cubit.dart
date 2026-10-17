import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';

final class VaccinationCubit extends Cubit<VaccinationState> {
  final VaccinationRepository repository;
  int _loadRequest = 0;

  VaccinationCubit(this.repository) : super(const VaccinationInitial());

  bool get _canLoad =>
      !isClosed &&
      switch (state) {
        VaccinationsLoaded(isDeleting: true) ||
        VaccinationLoaded(isDeleting: true) ||
        VaccinationDeleted() => false,
        _ => true,
      };

  Future<void> loadVaccinations(String petId) async {
    if (!_canLoad) return;
    final request = ++_loadRequest;
    final current = state;
    final previous = current is VaccinationsLoaded && current.petId == petId
        ? current
        : null;
    emit(
      previous == null
          ? const VaccinationLoading()
          : VaccinationsLoaded(
              petId,
              previous.vaccinations,
              isRefreshing: true,
            ),
    );
    final result = await repository.getVaccinations(petId);
    if (isClosed || request != _loadRequest) return;

    switch (result) {
      case Success<List<Vaccination>>():
        emit(VaccinationsLoaded(petId, result.data));
      case Error<List<Vaccination>>():
        emit(
          previous == null
              ? VaccinationError(result.failure.message)
              : VaccinationsLoaded(
                  petId,
                  previous.vaccinations,
                  refreshError: result.failure.message,
                ),
        );
    }
  }

  Future<void> loadVaccination(String petId, String vaccinationId) async {
    if (!_canLoad) return;
    final request = ++_loadRequest;
    final current = state;
    final previous =
        current is VaccinationLoaded &&
            current.vaccination.petId == petId &&
            current.vaccination.id == vaccinationId
        ? current
        : null;
    emit(
      previous == null
          ? const VaccinationLoading()
          : VaccinationLoaded(previous.vaccination, isRefreshing: true),
    );
    final result = await repository.getVaccinationById(petId, vaccinationId);
    if (isClosed || request != _loadRequest) return;

    switch (result) {
      case Success<Vaccination>():
        emit(VaccinationLoaded(result.data));
      case Error<Vaccination>():
        emit(
          previous == null
              ? VaccinationError(result.failure.message)
              : VaccinationLoaded(
                  previous.vaccination,
                  refreshError: result.failure.message,
                ),
        );
    }
  }

  Future<void> deleteVaccination() async {
    final current = state;
    if (isClosed || current is! VaccinationLoaded || current.isDeleting) return;
    // A refresh started before this write must not restore a deleted record.
    ++_loadRequest;
    final vaccination = current.vaccination;
    emit(VaccinationLoaded(vaccination, isDeleting: true));
    final result = await repository.deleteVaccination(
      vaccination.petId,
      vaccination.id,
    );
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(VaccinationDeleted(vaccination.id));
      case Error<void>():
        emit(
          VaccinationLoaded(vaccination, deleteError: result.failure.message),
        );
    }
  }

  Future<void> deleteListedVaccination(Vaccination vaccination) async {
    final current = state;
    if (isClosed ||
        current is! VaccinationsLoaded ||
        current.isDeleting ||
        current.isRefreshing) {
      return;
    }
    final index = current.vaccinations.indexWhere(
      (item) => item.id == vaccination.id,
    );
    if (index < 0 || current.petId != vaccination.petId) return;
    final target = current.vaccinations[index];
    ++_loadRequest;
    emit(
      VaccinationsLoaded(
        current.petId,
        current.vaccinations,
        isDeleting: true,
        deletionVaccination: target,
      ),
    );
    final result = await repository.deleteVaccination(current.petId, target.id);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(
          VaccinationsLoaded(
            current.petId,
            current.vaccinations.where((item) => item.id != target.id).toList(),
          ),
        );
      case Error<void>():
        emit(
          VaccinationsLoaded(
            current.petId,
            current.vaccinations,
            deletionVaccination: target,
            deleteError: result.failure.message,
          ),
        );
    }
  }

  /// Applies a deletion confirmed by the detail route without another read.
  void removeDeletedVaccination(String vaccinationId) {
    final current = state;
    if (isClosed || current is! VaccinationsLoaded || current.isDeleting) {
      return;
    }
    ++_loadRequest;
    emit(
      VaccinationsLoaded(
        current.petId,
        current.vaccinations.where((item) => item.id != vaccinationId).toList(),
      ),
    );
  }
}
