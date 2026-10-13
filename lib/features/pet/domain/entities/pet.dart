import 'package:equatable/equatable.dart';

enum PetSpecies { dog, cat, bird, other }

enum PetSex { male, female, unknown }

enum ReproductiveStatus { intact, sterilized, unknown }

final class Pet extends Equatable {
  final String id;
  final String name;
  final PetSpecies species;
  final PetSex sex;
  final ReproductiveStatus reproductiveStatus;

  final String? breed;
  final DateTime? birthDate;

  /// Current weight derived from the newest historical measurement on reads.
  final double? weight;
  final String? microchipId;

  /// Stored photo filename; older records may contain an absolute path.
  final String? imagePath;

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
    this.imagePath,
  });

  Pet copyWith({
    String? name,
    PetSpecies? species,
    PetSex? sex,
    ReproductiveStatus? reproductiveStatus,
    String? breed,
    DateTime? birthDate,
    double? weight,
    String? microchipId,
    String? imagePath,
  }) {
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
      imagePath: imagePath ?? this.imagePath,
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
    imagePath,
  ];
}
