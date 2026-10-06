import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

void main() {
  late MockPetRepository repository;
  late MockImageStorage imageStorage;
  late UpdatePet updatePet;

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

    updatePet = UpdatePet(repository, imageStorage);
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
      () => repository.updatePet(expectedPet),
    ).thenAnswer((_) async => const Success(null));

    final result = await updatePet(pet, params);

    expect(result, const Success<void>(null));

    verify(() => repository.updatePet(expectedPet)).called(1);
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
}
