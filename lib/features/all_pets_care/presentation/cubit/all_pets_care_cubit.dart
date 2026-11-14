import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';

final class AllPetsCareCubit extends Cubit<AllPetsCareState> {
  final PetRepository _repository;
  int _request = 0;
  bool _dirty = false;
  final _deletedPets = <String>{};

  AllPetsCareCubit(this._repository) : super(AllPetsCareState());

  Future<void> activate(AllPetsCareSection section) async {
    if (isClosed) return;
    emit(state.copyWith(activeSection: section));
    final pets = state.pets;
    if (!pets.isLoading && (_dirty || !pets.hasLoaded && pets.error == null)) {
      await loadPets();
    }
  }

  void invalidatePets() {
    if (isClosed) return;
    _dirty = true;
    ++_request;
    emit(state.copyWith(pets: state.pets.copyWith(isLoading: false)));
  }

  Future<void> loadPets() async {
    if (isClosed) return;
    final request = ++_request;
    _dirty = false;
    emit(
      state.copyWith(
        pets: state.pets.copyWith(isLoading: true, clearError: true),
      ),
    );
    final result = await _repository.getPets();
    if (isClosed || request != _request) return;
    switch (result) {
      case Success<List<Pet>>():
        emit(
          state.copyWith(
            pets: CareRecords(
              records: result.data
                  .where((p) => !_deletedPets.contains(p.id))
                  .toList(),
              hasLoaded: true,
            ),
          ),
        );
      case Error<List<Pet>>():
        emit(
          state.copyWith(
            pets: state.pets.copyWith(
              isLoading: false,
              error: result.failure.message,
            ),
          ),
        );
    }
  }

  /// Returns whether the pin change was saved; a failed write keeps the list.
  Future<bool> setPetPinned(String petId, {required bool pinned}) async {
    if (isClosed || state.pinningPetIds.contains(petId)) return false;
    emit(state.copyWith(pinningPetIds: {...state.pinningPetIds, petId}));
    final result = await _repository.setPetPinned(petId, pinned: pinned);
    if (isClosed) return result is Success<void>;
    final pending = {...state.pinningPetIds}..remove(petId);
    if (result is Error<void>) {
      emit(state.copyWith(pinningPetIds: pending));
      return false;
    }
    // Show the saved pin even if the reordering refresh below fails.
    emit(
      state.copyWith(
        pinningPetIds: pending,
        pets: state.pets.copyWith(
          records: [
            for (final pet in state.pets.records)
              pet.id == petId ? pet.copyWith(isPinned: pinned) : pet,
          ],
        ),
      ),
    );
    await loadPets();
    return true;
  }

  void removeDeletedPet(String petId) {
    if (isClosed) return;
    _deletedPets.add(petId);
    emit(
      state.copyWith(
        pets: state.pets.copyWith(
          records: state.pets.records.where((p) => p.id != petId).toList(),
        ),
      ),
    );
  }
}
