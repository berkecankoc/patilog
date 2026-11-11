import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';
import 'package:patilog/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_state.dart';

final class VaccinationCubit extends Cubit<VaccinationState> {
  final VaccinationRepository repository;
  int _loadRequest = 0;
  bool _dirty = false;
  Set<String> _petIds = {};
  String? _selectedPetId;
  final _removedPets = <String>{};
  final _removedRecords = <(String, String)>{};

  final DateTime Function() now;

  VaccinationCubit(this.repository, {this.now = DateTime.now})
    : super(const VaccinationInitial());

  bool get needsReload => _dirty || state is VaccinationInitial;

  void setPetContext(Iterable<String> petIds, {String? selectedPetId}) {
    _petIds = petIds.toSet();
    _selectedPetId = _petIds.contains(selectedPetId) ? selectedPetId : null;
  }

  void dismissDeletionError() {
    final current = state;
    if (!isClosed && current is VaccinationsLoaded && !current.isDeleting) {
      emit(current.copyWith(clearDeletion: true));
    }
  }

  bool _owns(VaccinationsLoaded loaded, Vaccination record) =>
      (loaded.petId == null
          ? _petIds.contains(record.petId) &&
                (_selectedPetId == null || _selectedPetId == record.petId)
          : loaded.petId == record.petId) &&
      !_removedPets.contains(record.petId);

  List<Vaccination> _remaining(Iterable<Vaccination> records) =>
      List.unmodifiable(
        records.where(
          (record) =>
              !_removedPets.contains(record.petId) &&
              !_removedRecords.contains((record.petId, record.id)),
        ),
      );

  bool get _canLoad =>
      !isClosed &&
      switch (state) {
        VaccinationsLoaded(isDeleting: true) ||
        VaccinationLoaded(isDeleting: true) ||
        VaccinationDeleted() => false,
        _ => true,
      };

  void invalidateList() {
    if (isClosed) return;
    _dirty = true;
    ++_loadRequest;
    final current = state;
    if (current is VaccinationsLoaded && current.isRefreshing) {
      emit(current.copyWith(isRefreshing: false));
    }
  }

  Future<void> loadVaccinations(String petId, {String? vetVisitId}) =>
      _loadList(petId, vetVisitId: vetVisitId);

  Future<void> loadAllVaccinations() => _loadList(null);

  Future<void> _loadList(String? petId, {String? vetVisitId}) async {
    if (!_canLoad) return;
    _dirty = false;
    final request = ++_loadRequest;
    final current = state;
    final previous =
        current is VaccinationsLoaded &&
            current.petId == petId &&
            current.vetVisitId == vetVisitId
        ? current
        : null;
    emit(
      previous == null
          ? const VaccinationLoading()
          : previous.copyWith(
              isRefreshing: true,
              clearRefreshError: true,
              clearDeletion: true,
            ),
    );
    final result = petId == null
        ? await repository.getAllVaccinations()
        : await repository.getVaccinations(petId, vetVisitId: vetVisitId);
    if (isClosed || request != _loadRequest) return;
    final latest = state;
    final retained =
        latest is VaccinationsLoaded &&
            latest.petId == petId &&
            latest.vetVisitId == vetVisitId
        ? latest
        : previous;
    switch (result) {
      case Success<List<Vaccination>>():
        emit(
          VaccinationsLoaded(
            petId,
            _remaining(result.data),
            vetVisitId: vetVisitId,
          ),
        );
      case Error<List<Vaccination>>():
        emit(
          retained == null
              ? VaccinationError(result.failure)
              : retained.copyWith(
                  isRefreshing: false,
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
          previous == null || result.failure is NotFoundFailure
              ? VaccinationError(result.failure)
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

  Future<void> deleteListedVaccination(Vaccination record) async {
    final current = state;
    if (isClosed ||
        current is! VaccinationsLoaded ||
        current.isDeleting ||
        current.isRefreshing ||
        !_owns(current, record)) {
      return;
    }
    final target = current.vaccinations
        .where((item) => item.id == record.id && item.petId == record.petId)
        .firstOrNull;
    if (target == null) return;
    ++_loadRequest;
    emit(
      current.copyWith(
        isDeleting: true,
        deletionVaccination: target,
        clearRefreshError: true,
      ),
    );
    final result = await repository.deleteVaccination(target.petId, target.id);
    if (isClosed) return;
    final latest = state is VaccinationsLoaded
        ? state as VaccinationsLoaded
        : current;
    switch (result) {
      case Success<void>():
        _removedRecords.add((target.petId, target.id));
        emit(
          latest.copyWith(
            vaccinations: _remaining(latest.vaccinations),
            isDeleting: false,
            clearDeletion: true,
          ),
        );
      case Error<void>():
        emit(
          latest.copyWith(
            isDeleting: false,
            deletionVaccination: target,
            deleteError: result.failure.message,
          ),
        );
    }
  }

  /// Known deletions also reconcile a read that is already in flight.
  void removeDeletedVaccination(String id, {String? petId}) {
    if (isClosed) return;
    final current = state;
    final owner =
        petId ??
        (current is VaccinationsLoaded
            ? current.vaccinations
                      .where((item) => item.id == id)
                      .firstOrNull
                      ?.petId ??
                  current.petId
            : null);
    if (owner == null) return;
    _removedRecords.add((owner, id));
    if (current is VaccinationsLoaded) {
      if (current.petId != null) ++_loadRequest;
      emit(
        current.copyWith(
          vaccinations: _remaining(current.vaccinations),
          isRefreshing: current.petId == null ? null : false,
          clearRefreshError: current.petId != null,
          clearDeletion:
              current.deletionVaccination?.id == id &&
              current.deletionVaccination?.petId == owner,
        ),
      );
    }
  }

  void removeDeletedPet(String petId) {
    if (isClosed) return;
    _removedPets.add(petId);
    final current = state;
    if (current is VaccinationsLoaded) {
      emit(
        current.copyWith(
          vaccinations: _remaining(current.vaccinations),
          clearDeletion: current.deletionVaccination?.petId == petId,
        ),
      );
    }
  }
}
