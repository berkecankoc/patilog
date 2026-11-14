import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';

abstract interface class PetRepository {
  Future<Result<List<Pet>>> getPets();
  Future<Result<Pet>> getPetById(String id);

  /// Saves the pet and optional initial measurement atomically.
  Future<Result<void>> createPet(Pet pet, {WeightEntry? weightEntry});

  /// Saves profile changes and an optional new measurement atomically.
  Future<Result<void>> updatePet(Pet pet, {WeightEntry? weightEntry});
  Future<Result<void>> deletePet(String id);

  /// Changes list priority only; profile updates keep the current pin.
  Future<Result<void>> setPetPinned(String id, {required bool pinned});
}
