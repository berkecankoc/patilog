import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';

final class PetCubit extends Cubit<PetState> {
  final PetRepository repository;
  final CreatePet _createPet;
  final UpdatePet _updatePet;
  final DeletePet _deletePet;

  PetCubit(this.repository, this._createPet, this._updatePet, this._deletePet)
    : super(const PetInitial());

  Future<void> loadPets() async {
    emit(const PetLoading());

    final result = await repository.getPets();
    if (isClosed) return;

    switch (result) {
      case Success<List<Pet>>():
        emit(PetsLoaded(result.data));
      case Error<List<Pet>>():
        emit(PetError(result.failure.message));
    }
  }

  Future<void> getPetById(String id) async {
    emit(const PetLoading());

    final result = await repository.getPetById(id);
    if (isClosed) return;

    switch (result) {
      case Success<Pet>():
        emit(PetLoaded(result.data));
      case Error<Pet>():
        emit(PetError(result.failure.message));
    }
  }

  Future<void> createPet(CreatePetParams params) async {
    emit(const PetLoading());

    final result = await _createPet(params);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(const PetCreated());
      case Error<void>():
        emit(PetError(result.failure.message));
    }
  }

  Future<void> updatePet(Pet pet, UpdatePetParams params) async {
    emit(const PetLoading());

    final result = await _updatePet(pet, params);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(const PetUpdated());
      case Error<void>():
        emit(PetError(result.failure.message));
    }
  }

  Future<void> deletePet(Pet pet) async {
    if (state case PetLoaded(isDeleting: true)) return;
    emit(PetLoaded(pet, isDeleting: true));

    final result = await _deletePet(pet);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(const PetDeleted());
      case Error<void>():
        emit(PetLoaded(pet, deleteError: result.failure.message));
    }
  }
}
