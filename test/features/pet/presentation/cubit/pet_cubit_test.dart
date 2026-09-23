import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/error/result.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockCreatePet extends Mock implements CreatePet {}

void main() {
  late MockPetRepository repository;
  late MockCreatePet createPet;

  const pet = Pet(
    id: 'pet-1',
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
  );

  const params = CreatePetParams(
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
  );

  setUp(() {
    repository = MockPetRepository();
    createPet = MockCreatePet();
  });

  group('loadPets', () {
    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetsLoaded when repository succeeds',
      build: () {
        when(
          () => repository.getPets(),
        ).thenAnswer((_) async => const Success([pet]));

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.loadPets(),
      expect: () => [
        const PetLoading(),
        const PetsLoaded([pet]),
      ],
    );

    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetError when repository fails',
      build: () {
        when(() => repository.getPets()).thenAnswer(
          (_) async => const Error(LocalDatabaseFailure('Failed to get pets')),
        );

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.loadPets(),
      expect: () => [const PetLoading(), const PetError('Failed to get pets')],
    );
  });

  group('getPetById', () {
    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetLoaded when repository succeeds',
      build: () {
        when(
          () => repository.getPetById('pet-1'),
        ).thenAnswer((_) async => const Success(pet));

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.getPetById('pet-1'),
      expect: () => [const PetLoading(), const PetLoaded(pet)],
    );

    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetError when repository fails.',
      build: () {
        when(() => repository.getPetById('pet-1')).thenAnswer(
          (_) async => const Error(NotFoundFailure('Pet not found')),
        );

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.getPetById('pet-1'),
      expect: () => [const PetLoading(), const PetError('Pet not found')],
    );
  });
  group('createPet', () {
    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetCreated when repository succeeds',
      build: () {
        when(
          () => createPet(params),
        ).thenAnswer((_) async => const Success(null));

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.createPet(params),
      expect: () => [const PetLoading(), const PetCreated()],
      verify: (_) {
        verify(() => createPet(params)).called(1);
      },
    );

    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetError when repository fails',
      build: () {
        when(() => createPet(params)).thenAnswer(
          (_) async =>
              const Error(LocalDatabaseFailure('Failed to create pet')),
        );

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.createPet(params),
      expect: () => [
        const PetLoading(),
        const PetError('Failed to create pet'),
      ],
      verify: (_) {
        verify(() => createPet(params)).called(1);
      },
    );
  });
  group('updatePet', () {
    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetUpdated when repository succeeds',
      build: () {
        when(
          () => repository.updatePet(pet),
        ).thenAnswer((_) async => const Success(null));

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.updatePet(pet),
      expect: () => [const PetLoading(), const PetUpdated()],
      verify: (_) {
        verify(() => repository.updatePet(pet)).called(1);
      },
    );

    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetError when repository fails',
      build: () {
        when(() => repository.updatePet(pet)).thenAnswer(
          (_) async =>
              const Error(LocalDatabaseFailure('Failed to update pet')),
        );

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.updatePet(pet),
      expect: () => [
        const PetLoading(),
        const PetError('Failed to update pet'),
      ],
      verify: (_) {
        verify(() => repository.updatePet(pet)).called(1);
      },
    );
  });
  group('deletePet', () {
    blocTest<PetCubit, PetState>(
      'emits  PetLoading and PetsLoaded when repository succeeds',
      build: () {
        when(
          () => repository.deletePet(pet.id),
        ).thenAnswer((_) async => const Success(null));
        when(
          () => repository.getPets(),
        ).thenAnswer((_) async => const Success([]));

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.deletePet(pet.id),
      expect: () => [const PetLoading(), const PetsLoaded([])],
      verify: (_) {
        verify(() => repository.deletePet(pet.id)).called(1);
        verify(() => repository.getPets()).called(1);
      },
    );

    blocTest<PetCubit, PetState>(
      'emits  PetLoading and PetError when repository fails',
      build: () {
        when(() => repository.deletePet(pet.id)).thenAnswer(
          (_) async =>
              const Error(LocalDatabaseFailure('Failed to delete pet')),
        );

        return PetCubit(repository, createPet);
      },
      act: (cubit) => cubit.deletePet(pet.id),
      expect: () => [
        const PetLoading(),
        const PetError('Failed to delete pet'),
      ],
      verify: (_) {
        verify(() => repository.deletePet(pet.id)).called(1);
        verifyNever(() => repository.getPets());
      },
    );
  });
}
