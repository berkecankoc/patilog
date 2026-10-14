import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';

class MockRepository extends Mock implements PetRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

void main() {
  const pet = Pet(
    id: 'pet-1',
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.intact,
    imagePath: 'photo.jpg',
  );
  late MockRepository repository;
  late MockImageStorage images;
  late DeletePet delete;
  setUp(() {
    repository = MockRepository();
    images = MockImageStorage();
    delete = DeletePet(repository, images);
  });

  test('deletes the photo only after repository deletion succeeds', () async {
    when(
      () => repository.deletePet(pet.id),
    ).thenAnswer((_) async => const Success(null));
    when(() => images.delete(pet.imagePath!)).thenAnswer((_) async {});
    expect(await delete(pet), const Success<void>(null));
    verifyInOrder([
      () => repository.deletePet(pet.id),
      () => images.delete(pet.imagePath!),
    ]);
  });

  test('does not access image storage for a pet without a photo', () async {
    const noPhoto = Pet(
      id: 'pet-1',
      name: 'Fluffy',
      species: PetSpecies.cat,
      sex: PetSex.female,
      reproductiveStatus: ReproductiveStatus.intact,
    );
    when(
      () => repository.deletePet(pet.id),
    ).thenAnswer((_) async => const Success(null));
    expect(await delete(noPhoto), const Success<void>(null));
    verifyZeroInteractions(images);
  });

  for (final failure in [
    const LocalDatabaseFailure('Could not delete pet'),
    const NotFoundFailure('Pet not found'),
  ]) {
    test(
      'keeps the photo when deletion returns ${failure.runtimeType}',
      () async {
        when(
          () => repository.deletePet(pet.id),
        ).thenAnswer((_) async => Error(failure));
        expect(await delete(pet), Error<void>(failure));
        verifyZeroInteractions(images);
      },
    );
  }

  test('preserves successful deletion when photo cleanup fails', () async {
    when(
      () => repository.deletePet(pet.id),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => images.delete(pet.imagePath!),
    ).thenThrow(const ImageStorageException());
    expect(await delete(pet), const Success<void>(null));
    verify(() => images.delete(pet.imagePath!)).called(1);
  });
}
