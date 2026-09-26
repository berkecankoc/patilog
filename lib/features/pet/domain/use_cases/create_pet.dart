import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/error/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';

final class CreatePetParams {
  final String name;
  final PetSpecies species;
  final PetSex sex;
  final ReproductiveStatus reproductiveStatus;

  final String? breed;
  final DateTime? birthDate;
  final double? weight;
  final String? microchipId;
  final String? sourceImagePath;

  const CreatePetParams({
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

class CreatePet {
  final PetRepository repository;
  final IdGenerator idGenerator;
  final ImageStorage imageStorage;

  const CreatePet(this.repository, this.idGenerator, this.imageStorage);

  Future<Result<void>> call(CreatePetParams params) async {
    String? savedImagePath;

    if (params.sourceImagePath != null) {
      try {
        savedImagePath = await imageStorage.save(params.sourceImagePath!);
      } on ImageStorageException {
        return Error(ImageStorageFailure('Failed to save new image'));
      }
    }

    final pet = Pet(
      id: idGenerator.generate(),
      name: params.name,
      species: params.species,
      sex: params.sex,
      reproductiveStatus: params.reproductiveStatus,
      breed: params.breed,
      birthDate: params.birthDate,
      weight: params.weight,
      microchipId: params.microchipId,
      imagePath: savedImagePath,
    );

    final result = await repository.createPet(pet);

    if (result case Error<void>()) {
      // If pet creation fails after saving an image,
      // delete the newly saved image.
      if (savedImagePath != null) {
        try {
          await imageStorage.delete(savedImagePath);
        } catch (_) {
          // Best-effort cleanup: preserve the original repository failure
          // if deleting the newly saved image also fails.
        }
      }
    }

    return result;
  }
}
