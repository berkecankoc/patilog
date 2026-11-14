import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/core/storage/image_storage.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';

final class CreatePetParams {
  final String name;
  final PetSpecies species;

  /// Ignored unless [species] is [PetSpecies.other].
  final String? customSpecies;
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
    this.customSpecies,
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
      customSpecies: customSpeciesFor(params.species, params.customSpecies),
      sex: params.sex,
      reproductiveStatus: params.reproductiveStatus,
      breed: params.breed,
      birthDate: params.birthDate,
      weight: params.weight,
      microchipId: params.microchipId,
      imagePath: savedImagePath,
    );

    final now = DateTime.now();
    final weightEntry = params.weight == null
        ? null
        : WeightEntry(
            id: idGenerator.generate(),
            petId: pet.id,
            weight: params.weight!,
            measuredAt: DateTime(now.year, now.month, now.day),
          );
    final result = await repository.createPet(pet, weightEntry: weightEntry);

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
