import 'package:petlytics/core/error/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
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
  final String? imagePath;

  const CreatePetParams({
    required this.name,
    required this.species,
    required this.sex,
    required this.reproductiveStatus,
    this.breed,
    this.birthDate,
    this.weight,
    this.microchipId,
    this.imagePath,
  });
}

class CreatePet {
  final PetRepository repository;
  final IdGenerator idGenerator;

  const CreatePet(this.repository, this.idGenerator);

  Future<Result<void>> call(CreatePetParams params) {
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
      imagePath: params.imagePath,
    );

    return repository.createPet(pet);
  }
}
