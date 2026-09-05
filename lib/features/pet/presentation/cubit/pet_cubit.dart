import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/error/result.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';

final class PetCubit extends Cubit<PetState> {
  final PetRepository repository;
  final CreatePet _createPet;

  PetCubit(this.repository, this._createPet) : super(const PetInitial());

  Future<void> loadPets() async {
    emit(const PetLoading());

    final result = await repository.getPets();

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

    switch (result) {
      case Success<void>():
        await loadPets();
      case Error<void>():
        emit(PetError(result.failure.message));
    }
  }

  Future<void> updatePet(Pet pet) async {
    emit(const PetLoading());

    final result = await repository.updatePet(pet);

    switch (result) {
      case Success<void>():
        await getPetById(pet.id);
      case Error<void>():
        emit(PetError(result.failure.message));
    }
  }

  Future<void> deletePet(String id) async {
    emit(const PetLoading());

    final result = await repository.deletePet(id);

    switch (result) {
      case Success<void>():
        await loadPets();
      case Error<void>():
        emit(PetError(result.failure.message));
    }
  }
}
