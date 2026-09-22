import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/error/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockIdGenerator extends Mock implements IdGenerator {}

void main() {
  late MockPetRepository repository;
  late MockIdGenerator idGenerator;
  late CreatePet createPet;

  final params = CreatePetParams(
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

  final expectedPet = Pet(
    id: 'generated-id',
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

  setUp(() {
    repository = MockPetRepository();
    idGenerator = MockIdGenerator();

    createPet = CreatePet(repository, idGenerator);
  });

  test(
    'creates the pet with a generated id when repository creation succeeds',
    () async {
      when(() => idGenerator.generate()).thenReturn('generated-id');

      when(
        () => repository.createPet(expectedPet),
      ).thenAnswer((_) async => const Success(null));

      final result = await createPet(params);

      expect(result, const Success<void>(null));

      verify(() => idGenerator.generate()).called(1);
      verify(() => repository.createPet(expectedPet)).called(1);
    },
  );

  test('returns the repository error when repository creation fails', () async {
    when(() => idGenerator.generate()).thenReturn('generated-id');

    when(() => repository.createPet(expectedPet)).thenAnswer(
      (_) async => const Error(LocalDatabaseFailure('Failed to create pet')),
    );

    final result = await createPet(params);

    expect(
      result,
      const Error<void>(LocalDatabaseFailure('Failed to create pet')),
    );

    verify(() => idGenerator.generate()).called(1);
    verify(() => repository.createPet(expectedPet)).called(1);
  });
}
