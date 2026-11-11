import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/storage/image_storage.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';
import 'package:patilog/features/pet/domain/use_cases/update_pet.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

class MockIdGenerator extends Mock implements IdGenerator {}

void main() {
  late MockPetRepository repository;
  late MockImageStorage imageStorage;
  late UpdatePet updatePet;
  late MockIdGenerator idGenerator;

  const oldImagePath = 'old.jpg';
  const sourceNewImagePath = '/picker/new.jpg';
  const savedNewImagePath = 'new.jpg';

  const pet = Pet(
    id: 'pet-1',
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
    imagePath: oldImagePath,
  );

  setUp(() {
    repository = MockPetRepository();
    imageStorage = MockImageStorage();

    idGenerator = MockIdGenerator();
    when(idGenerator.generate).thenReturn('weight-id');
    updatePet = UpdatePet(repository, imageStorage, idGenerator);
  });

  setUpAll(() {
    registerFallbackValue(pet);
    registerFallbackValue(
      WeightEntry(
        id: 'weight-id',
        petId: pet.id,
        weight: 1,
        measuredAt: DateTime(2026),
      ),
    );
  });

  test('keeps the existing image when image path is unchanged', () async {
    const params = UpdatePetParams(
      name: 'Fluffy Updated',
      species: PetSpecies.cat,
      sex: PetSex.male,
      reproductiveStatus: ReproductiveStatus.sterilized,
      weight: 5.8,
      sourceImagePath: oldImagePath,
    );

    const expectedPet = Pet(
      id: 'pet-1',
      name: 'Fluffy Updated',
      species: PetSpecies.cat,
      sex: PetSex.male,
      reproductiveStatus: ReproductiveStatus.sterilized,
      weight: 5.8,
      imagePath: oldImagePath,
    );

    when(
      () => repository.updatePet(
        expectedPet,
        weightEntry: any(named: 'weightEntry'),
      ),
    ).thenAnswer((_) async => const Success(null));

    final result = await updatePet(pet, params);

    expect(result, const Success<void>(null));

    final measurement =
        verify(
              () => repository.updatePet(
                expectedPet,
                weightEntry: captureAny(named: 'weightEntry'),
              ),
            ).captured.single
            as WeightEntry;
    expect(measurement.id, 'weight-id');
    expect(measurement.petId, pet.id);
    expect(measurement.weight, 5.8);
    final now = DateTime.now();
    expect(measurement.measuredAt, DateTime(now.year, now.month, now.day));
    verifyZeroInteractions(imageStorage);
  });

  test('deletes the old image when repository succeeds', () async {
    const params = UpdatePetParams(
      name: 'Fluffy Updated',
      species: PetSpecies.cat,
      sex: PetSex.male,
      reproductiveStatus: ReproductiveStatus.sterilized,
      sourceImagePath: null,
    );

    const expectedPet = Pet(
      id: 'pet-1',
      name: 'Fluffy Updated',
      species: PetSpecies.cat,
      sex: PetSex.male,
      reproductiveStatus: ReproductiveStatus.sterilized,
      imagePath: null,
    );

    when(
      () => repository.updatePet(expectedPet),
    ).thenAnswer((_) async => const Success(null));

    when(() => imageStorage.delete(oldImagePath)).thenAnswer((_) async {});

    final result = await updatePet(pet, params);

    expect(result, const Success<void>(null));

    verify(() => repository.updatePet(expectedPet)).called(1);
    verify(() => imageStorage.delete(oldImagePath)).called(1);
  });

  test(
    'saves the new image and deletes the old image when repository succeeds',
    () async {
      const params = UpdatePetParams(
        name: 'Fluffy Updated',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.sterilized,
        sourceImagePath: sourceNewImagePath,
      );

      const expectedPet = Pet(
        id: 'pet-1',
        name: 'Fluffy Updated',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.sterilized,
        imagePath: savedNewImagePath,
      );

      when(
        () => imageStorage.save(sourceNewImagePath),
      ).thenAnswer((_) async => savedNewImagePath);

      when(
        () => repository.updatePet(expectedPet),
      ).thenAnswer((_) async => const Success(null));

      when(() => imageStorage.delete(oldImagePath)).thenAnswer((_) async {});

      final result = await updatePet(pet, params);

      expect(result, const Success<void>(null));

      verify(() => imageStorage.save(sourceNewImagePath)).called(1);
      verify(() => repository.updatePet(expectedPet)).called(1);
      verify(() => imageStorage.delete(oldImagePath)).called(1);
    },
  );

  test(
    'deletes the newly saved image and keeps the old image when repository fails',
    () async {
      const params = UpdatePetParams(
        name: 'Fluffy Updated',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.sterilized,
        sourceImagePath: sourceNewImagePath,
      );

      const expectedPet = Pet(
        id: 'pet-1',
        name: 'Fluffy Updated',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.sterilized,
        imagePath: savedNewImagePath,
      );

      when(
        () => imageStorage.save(sourceNewImagePath),
      ).thenAnswer((_) async => savedNewImagePath);

      when(() => repository.updatePet(expectedPet)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Failed to update pet')),
      );

      when(
        () => imageStorage.delete(savedNewImagePath),
      ).thenAnswer((_) async {});

      final result = await updatePet(pet, params);

      expect(
        result,
        const Error<void>(LocalDatabaseFailure('Failed to update pet')),
      );

      verify(() => imageStorage.save(sourceNewImagePath)).called(1);
      verify(() => repository.updatePet(expectedPet)).called(1);
      verify(() => imageStorage.delete(savedNewImagePath)).called(1);
      verifyNever(() => imageStorage.delete(oldImagePath));
    },
  );

  test('returns ImageStorageFailure when image storage fails', () async {
    const params = UpdatePetParams(
      name: 'Fluffy Updated',
      species: PetSpecies.cat,
      sex: PetSex.male,
      reproductiveStatus: ReproductiveStatus.sterilized,
      sourceImagePath: sourceNewImagePath,
    );

    when(
      () => imageStorage.save(sourceNewImagePath),
    ).thenThrow(const ImageStorageException());

    final result = await updatePet(pet, params);

    expect(
      result,
      const Error<void>(ImageStorageFailure('Failed to save new image')),
    );

    verify(() => imageStorage.save(sourceNewImagePath)).called(1);
    verifyZeroInteractions(repository);
  });

  for (final weight in <double?>[5.8, null]) {
    test(
      'weight $weight does not add a measurement when unchanged or cleared',
      () async {
        final current = pet.copyWith(weight: 5.8);
        final params = UpdatePetParams(
          name: pet.name,
          species: pet.species,
          sex: pet.sex,
          reproductiveStatus: pet.reproductiveStatus,
          weight: weight,
          sourceImagePath: pet.imagePath,
        );
        when(
          () => repository.updatePet(any(), weightEntry: null),
        ).thenAnswer((_) async => const Success(null));
        expect(await updatePet(current, params), const Success<void>(null));
        verify(() => repository.updatePet(any(), weightEntry: null)).called(1);
        verifyNever(idGenerator.generate);
      },
    );
  }
}
