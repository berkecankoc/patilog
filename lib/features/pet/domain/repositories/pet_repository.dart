import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';

abstract interface class PetRepository {
  Future<Result<List<Pet>>> getPets();
  Future<Result<Pet>> getPetById(String id);
  Future<Result<void>> createPet(Pet pet);
  Future<Result<void>> updatePet(Pet pet);
  Future<Result<void>> deletePet(String id);
}
