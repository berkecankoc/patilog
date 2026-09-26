import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';

final class UpdatePetParams {
  final String name;
  final PetSpecies species;
  final PetSex sex;
  final ReproductiveStatus reproductiveStatus;

  final String? breed;
  final DateTime? birthDate;
  final double? weight;
  final String? microchipId;
  final String? sourceImagePath;

  const UpdatePetParams({
    required this.name,
    required this.species,
    required this.sex,
    required this.reproductiveStatus,
    this.breed,
    this.birthDate,
    this.weight,
    this.microchipId,
    this.sourceImagePath,
  });
}

class UpdatePet {
  final PetRepository repository;
  final ImageStorage imageStorage;

  const UpdatePet(this.repository, this.imageStorage);

  Future<Result<void>> call(Pet pet, UpdatePetParams params) async {
    final String? finalImagePath;

    if (params.sourceImagePath == null) {
      // Remove the image.
      finalImagePath = null;
    } else if (params.sourceImagePath == pet.imagePath) {
      // Keep the same image.
      finalImagePath = pet.imagePath;
    } else {
      // Change the image and persist it.
      try {
        finalImagePath = await imageStorage.save(params.sourceImagePath!);
      } on ImageStorageException {
        return Error(ImageStorageFailure('Failed to save new image'));
      }
    }

    final updatedPet = Pet(
      id: pet.id,
      name: params.name,
      species: params.species,
      sex: params.sex,
      reproductiveStatus: params.reproductiveStatus,
      breed: params.breed,
      birthDate: params.birthDate,
      weight: params.weight,
      microchipId: params.microchipId,
      imagePath: finalImagePath,
    );

    final result = await repository.updatePet(updatedPet);

    switch (result) {
      case Success<void>():
        // If the update succeeds and the image changed,
        // delete the old persisted image.
        if (pet.imagePath != finalImagePath && pet.imagePath != null) {
          try {
            await imageStorage.delete(pet.imagePath!);
          } catch (_) {
            // Best-effort cleanup: the database update already succeeded,
            // so failure to delete the old image must not fail the update.
          }
        }

      case Error<void>():
        // If the update fails after saving a new image,
        // delete the newly saved image.
        if (finalImagePath != pet.imagePath && finalImagePath != null) {
          try {
            await imageStorage.delete(finalImagePath);
          } catch (_) {
            // Best-effort cleanup: preserve the original repository failure
            // if deleting the newly saved image also fails.
          }
        }
    }
    return result;
  }
}
