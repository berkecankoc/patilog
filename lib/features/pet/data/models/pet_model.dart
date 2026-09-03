import 'package:petlytics/features/pet/domain/entities/pet.dart';

class PetModel extends Pet {
  const PetModel({
    required super.id,
    required super.name,
    required super.species,
    required super.sex,
    required super.reproductiveStatus,
    super.breed,
    super.birthDate,
    super.weight,
    super.microchipId,
    super.imageUrl,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
    id: json['id'] as String,
    name: json['name'] as String,
    species: PetSpecies.values.byName(json['species'] as String),
    sex: PetSex.values.byName(json['sex'] as String),
    reproductiveStatus: ReproductiveStatus.values.byName(
      json['reproductive_status'] as String,
    ),
    breed: json['breed'] as String?,
    birthDate: _parseDate(json['birth_date']),
    weight: (json['weight'] as num?)?.toDouble(),
    microchipId: json['microchip_id'] as String?,
    imageUrl: json['image_url'] as String?,
  );

  factory PetModel.fromEntity(Pet pet) => PetModel(
    id: pet.id,
    name: pet.name,
    species: pet.species,
    sex: pet.sex,
    reproductiveStatus: pet.reproductiveStatus,
    breed: pet.breed,
    birthDate: pet.birthDate,
    weight: pet.weight,
    microchipId: pet.microchipId,
    imageUrl: pet.imageUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species.name,
    'sex': sex.name,
    'reproductive_status': reproductiveStatus.name,
    'breed': breed,
    'birth_date': _formatDate(birthDate),
    'weight': weight,
    'microchip_id': microchipId,
    'image_url': imageUrl,
  };

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;

    return DateTime.tryParse(value);
  }

  static String? _formatDate(DateTime? date) {
    if (date == null) return null;

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
