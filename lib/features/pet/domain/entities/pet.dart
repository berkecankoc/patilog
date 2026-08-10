enum PetSpecies { dog, cat, bird, other }

enum PetSex { male, female, unknown }

enum ReproductiveStatus { intact, sterilized, unknown }

class Pet {
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
}
