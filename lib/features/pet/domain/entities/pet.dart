import 'package:equatable/equatable.dart';

enum PetSpecies { dog, cat, bird, other }

enum PetSex { male, female, unknown }

enum ReproductiveStatus { intact, sterilized, unknown }

/// Keeps a trimmed custom species name only for [PetSpecies.other].
String? customSpeciesFor(PetSpecies species, String? name) {
  final trimmed = name?.trim();
  return species == PetSpecies.other && trimmed != null && trimmed.isNotEmpty
      ? trimmed
      : null;
}

final class Pet extends Equatable {
  final String id;
  final String name;
  final PetSpecies species;

  /// User-entered species name; present only for [PetSpecies.other].
  final String? customSpecies;
  final PetSex sex;
  final ReproductiveStatus reproductiveStatus;

  final String? breed;
  final DateTime? birthDate;

  /// Current weight derived from the newest historical measurement on reads.
  final double? weight;
  final String? microchipId;

  /// Stored photo filename; older records may contain an absolute path.
  final String? imagePath;

  /// Pinned pets are listed first; profile updates do not change this flag.
  final bool isPinned;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.customSpecies,
    required this.sex,
    required this.reproductiveStatus,
    this.breed,
    this.birthDate,
    this.weight,
    this.microchipId,
    this.imagePath,
    this.isPinned = false,
  });

  Pet copyWith({
    String? name,
    PetSpecies? species,
    String? customSpecies,
    PetSex? sex,
    ReproductiveStatus? reproductiveStatus,
    String? breed,
    DateTime? birthDate,
    double? weight,
    String? microchipId,
    String? imagePath,
    bool? isPinned,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      customSpecies: customSpecies ?? this.customSpecies,
      sex: sex ?? this.sex,
      reproductiveStatus: reproductiveStatus ?? this.reproductiveStatus,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      microchipId: microchipId ?? this.microchipId,
      imagePath: imagePath ?? this.imagePath,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    species,
    customSpecies,
    sex,
    reproductiveStatus,
    breed,
    birthDate,
    weight,
    microchipId,
    imagePath,
    isPinned,
  ];
}
