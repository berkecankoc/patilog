import 'package:equatable/equatable.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';

final class PetModel extends Equatable {
  final String id;
  final String name;
  final PetSpecies species;
  final String? customSpecies;
  final PetSex sex;
  final ReproductiveStatus reproductiveStatus;

  final String? breed;
  final DateTime? birthDate;
  final double? weight;
  final String? microchipId;
  final String? imagePath;

  /// Read-only here: pin order is written only by the pin operation.
  final bool isPinned;

  const PetModel({
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

  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
    id: json['id'] as String,
    name: json['name'] as String,
    species: PetSpecies.values.byName(json['species'] as String),
    customSpecies: json['custom_species'] as String?,
    sex: PetSex.values.byName(json['sex'] as String),
    reproductiveStatus: ReproductiveStatus.values.byName(
      json['reproductive_status'] as String,
    ),
    breed: json['breed'] as String?,
    birthDate: _parseDate(json['birth_date']),
    weight: (json['weight'] as num?)?.toDouble(),
    microchipId: json['microchip_id'] as String?,
    imagePath: json['image_path'] as String?,
    isPinned: json['is_pinned'] == 1,
  );

  factory PetModel.fromEntity(Pet pet) => PetModel(
    id: pet.id,
    name: pet.name,
    species: pet.species,
    customSpecies: pet.customSpecies,
    sex: pet.sex,
    reproductiveStatus: pet.reproductiveStatus,
    breed: pet.breed,
    birthDate: pet.birthDate,
    weight: pet.weight,
    microchipId: pet.microchipId,
    imagePath: pet.imagePath,
    isPinned: pet.isPinned,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species.name,
    'custom_species': customSpecies,
    'sex': sex.name,
    'reproductive_status': reproductiveStatus.name,
    'breed': breed,
    'birth_date': _formatDate(birthDate),
    'microchip_id': microchipId,
    'image_path': imagePath,
  };

  Pet toEntity() {
    return Pet(
      id: id,
      name: name,
      species: species,
      customSpecies: customSpecies,
      sex: sex,
      reproductiveStatus: reproductiveStatus,
      breed: breed,
      birthDate: birthDate,
      weight: weight,
      microchipId: microchipId,
      imagePath: imagePath,
      isPinned: isPinned,
    );
  }

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
