import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/storage/image_storage.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';

class DeletePet {
  final PetRepository repository;
  final ImageStorage imageStorage;

  const DeletePet(this.repository, this.imageStorage);

  Future<Result<void>> call(Pet pet) async {
    final result = await repository.deletePet(pet.id);
    if (result is Success<void> && pet.imagePath != null) {
      try {
        await imageStorage.delete(pet.imagePath!);
      } catch (_) {
        // Best-effort cleanup: the pet and its records are already deleted.
      }
    }
    return result;
  }
}
