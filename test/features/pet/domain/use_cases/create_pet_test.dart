import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockIdGenerator extends Mock implements IdGenerator {}

class MockImageStorage extends Mock implements ImageStorage {}

void main() {
  late MockPetRepository repository;
  late MockIdGenerator idGenerator;
  late MockImageStorage imageStorage;
  late CreatePet createPet;

  const sourceImagePath = '/picker/fluffy.jpg';
  const savedImagePath = '/documents/pet_images/fluffy-persisted.jpg';

  final params = CreatePetParams(
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
    breed: 'Siamese',
    birthDate: DateTime(2022, 7, 11),
    weight: 5.4,
    microchipId: '123456789',
    sourceImagePath: sourceImagePath,
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
    imagePath: savedImagePath,
  );

  setUp(() {
    repository = MockPetRepository();
    idGenerator = MockIdGenerator();
    imageStorage = MockImageStorage();

    createPet = CreatePet(repository, idGenerator, imageStorage);
  });

  test(
    'saves the image and creates the pet with a generated id when repository succeeds',
    () async {
      when(
        () => imageStorage.save(sourceImagePath),
      ).thenAnswer((_) async => savedImagePath);

      when(() => idGenerator.generate()).thenReturn('generated-id');

      when(
        () => repository.createPet(expectedPet),
      ).thenAnswer((_) async => const Success(null));

      final result = await createPet(params);

      expect(result, const Success<void>(null));

      verify(() => imageStorage.save(sourceImagePath)).called(1);
      verify(() => idGenerator.generate()).called(1);
      verify(() => repository.createPet(expectedPet)).called(1);
    },
  );

  test(
    'creates the pet without using image storage when no image is provided',
    () async {
      const paramsWithoutImage = CreatePetParams(
        name: 'Fluffy',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.sterilized,
      );

      const expectedPetWithoutImage = Pet(
        id: 'generated-id',
        name: 'Fluffy',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.sterilized,
      );

      when(() => idGenerator.generate()).thenReturn('generated-id');

      when(
        () => repository.createPet(expectedPetWithoutImage),
      ).thenAnswer((_) async => const Success(null));

      final result = await createPet(paramsWithoutImage);

      expect(result, const Success<void>(null));

      verifyNever(() => imageStorage.save(any()));
      verify(() => repository.createPet(expectedPetWithoutImage)).called(1);
    },
  );

  test(
    'deletes the newly saved image and returns the repository error when repository fails',
    () async {
      when(
        () => imageStorage.save(sourceImagePath),
      ).thenAnswer((_) async => savedImagePath);

      when(() => idGenerator.generate()).thenReturn('generated-id');

      when(() => repository.createPet(expectedPet)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Failed to create pet')),
      );

      when(() => imageStorage.delete(savedImagePath)).thenAnswer((_) async {});

      final result = await createPet(params);

      expect(
        result,
        const Error<void>(LocalDatabaseFailure('Failed to create pet')),
      );

      verify(() => idGenerator.generate()).called(1);
      verify(() => repository.createPet(expectedPet)).called(1);
      verify(() => imageStorage.delete(savedImagePath)).called(1);
    },
  );

  test('returns ImageStorageFailure when image storage fails', () async {
    when(
      () => imageStorage.save(sourceImagePath),
    ).thenThrow(const ImageStorageException());

    final result = await createPet(params);

    expect(
      result,
      const Error<void>(ImageStorageFailure('Failed to save new image')),
    );

    verify(() => imageStorage.save(sourceImagePath)).called(1);
    verifyNever(() => idGenerator.generate());
    verifyNever(() => repository.createPet(expectedPet));
  });

  test(
    'preserves the repository failure when image storage also fails',
    () async {
      when(
        () => imageStorage.save(sourceImagePath),
      ).thenAnswer((_) async => savedImagePath);

      when(() => idGenerator.generate()).thenReturn('generated-id');

      when(() => repository.createPet(expectedPet)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Failed to create pet')),
      );

      when(
        () => imageStorage.delete(savedImagePath),
      ).thenThrow(const ImageStorageException());

      final result = await createPet(params);

      expect(
        result,
        const Error<void>(LocalDatabaseFailure('Failed to create pet')),
      );
    },
  );
}
