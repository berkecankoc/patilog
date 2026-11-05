import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';

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
