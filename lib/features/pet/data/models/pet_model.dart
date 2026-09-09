import 'package:equatable/equatable.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';

class PetModel extends Equatable {
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

  const PetModel({
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

  Pet toEntity() {
    return Pet(
      id: id,
      name: name,
      species: species,
      sex: sex,
      reproductiveStatus: reproductiveStatus,
      breed: breed,
      birthDate: birthDate,
      weight: weight,
      microchipId: microchipId,
      imageUrl: imageUrl,
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
    sex,
    reproductiveStatus,
    breed,
    birthDate,
    weight,
    microchipId,
    imageUrl,
  ];
}
