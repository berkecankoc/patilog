import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/pet/data/models/pet_model.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';

void main() {
  final model = PetModel(
    id: 'pet-1',
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
    breed: 'Siamese',
    birthDate: DateTime(2022, 7, 11),
    weight: 5.4,
    microchipId: '123456789',
    imagePath: 'fluffy.jpg',
  );

  final entity = Pet(
    id: 'pet-1',
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
    breed: 'Siamese',
    birthDate: DateTime(2022, 7, 11),
    weight: 5.4,
    microchipId: '123456789',
    imagePath: 'fluffy.jpg',
  );

  test('serializes PetModel to JSON', () {
    final result = model.toJson();

    expect(result, {
      'id': 'pet-1',
      'name': 'Fluffy',
      'species': 'cat',
      'sex': 'male',
      'reproductive_status': 'sterilized',
      'breed': 'Siamese',
      'birth_date': '2022-07-11',
      'microchip_id': '123456789',
      'image_path': 'fluffy.jpg',
    });
  });

  test('deserializes JSON into PetModel', () {
    final json = {
      'id': 'pet-1',
      'name': 'Fluffy',
      'species': 'cat',
      'sex': 'male',
      'reproductive_status': 'sterilized',
      'breed': 'Siamese',
      'birth_date': '2022-07-11',
      'weight': 5.4,
      'microchip_id': '123456789',
      'image_path': 'fluffy.jpg',
    };

    final result = PetModel.fromJson(json);

    expect(result, model);
  });

  test('maps PetModel to Pet', () {
    final result = model.toEntity();

    expect(result, entity);
  });

  test('maps Pet to PetModel', () {
    final result = PetModel.fromEntity(entity);

    expect(result, model);
  });

  test('handles null values for optional fields', () {
    final result = PetModel.fromJson({
      'id': 'pet-1',
      'name': 'Fluffy',
      'species': 'cat',
      'sex': 'male',
      'reproductive_status': 'sterilized',
      'breed': null,
      'birth_date': null,
      'weight': null,
      'microchip_id': null,
      'image_path': null,
    });

    expect(result.breed, isNull);
    expect(result.birthDate, isNull);
    expect(result.weight, isNull);
    expect(result.microchipId, isNull);
    expect(result.imagePath, isNull);
  });

  test('converts numeric weight to double', () {
    final result = PetModel.fromJson({
      'id': 'pet-1',
      'name': 'Fluffy',
      'species': 'cat',
      'sex': 'male',
      'reproductive_status': 'sterilized',
      'breed': null,
      'birth_date': null,
      'weight': 5,
      'microchip_id': null,
      'image_path': null,
    });
    expect(result.weight, 5.0);
  });
}
