import 'package:equatable/equatable.dart';

enum PetSpecies { dog, cat, bird, other }

enum PetSex { male, female, unknown }

enum ReproductiveStatus { intact, sterilized, unknown }

class Pet extends Equatable {
  final String id;
  final String name;
  final PetSpecies species;
  final PetSex sex;
  final ReproductiveStatus reproductiveStatus;

  final String? breed;
  final DateTime? birthDate;
  final double? weight;
  final String? microchipId;
  final String? imageUrl;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    required this.sex,
    required this.reproductiveStatus,
    this.breed,
    this.birthDate,
    this.weight,
    this.microchipId,
    this.imageUrl,
  });

  Pet copyWith(
    String? name,
    PetSpecies? species,
    PetSex? sex,
    ReproductiveStatus? reproductiveStatus,
    String? breed,
    DateTime? birthDate,
    double? weight,
    String? microchipId,
    String? imageUrl,
  ) {
    return Pet(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      sex: sex ?? this.sex,
      reproductiveStatus: reproductiveStatus ?? this.reproductiveStatus,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      microchipId: microchipId ?? this.microchipId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    species,
    sex,
    reproductiveStatus,
    breed,
    birthDate,
    weight,
    microchipId,
    imageUrl,
  ];
}
