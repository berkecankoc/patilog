import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

class MockDeletePet extends Mock implements DeletePet {}

void main() {
  late MockPetRepository repository;
  late MockCreatePet createPet;
  late MockUpdatePet updatePet;
  late MockDeletePet deletePet;

  const pet = Pet(
    id: 'pet-1',
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
  );

  const createParams = CreatePetParams(
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
  );

  const updateParams = UpdatePetParams(
    name: 'Fluffy Updated',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.sterilized,
  );

  setUpAll(() => registerFallbackValue(pet));

  setUp(() {
    repository = MockPetRepository();
    createPet = MockCreatePet();
    updatePet = MockUpdatePet();
    deletePet = MockDeletePet();
  });

  group('loadPets', () {
    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetsLoaded when repository succeeds',
      build: () {
        when(
          () => repository.getPets(),
        ).thenAnswer((_) async => const Success([pet]));

        return PetCubit(repository, createPet, updatePet, deletePet);
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

        return PetCubit(repository, createPet, updatePet, deletePet);
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

        return PetCubit(repository, createPet, updatePet, deletePet);
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

        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      act: (cubit) => cubit.getPetById('pet-1'),
      expect: () => [const PetLoading(), const PetError('Pet not found')],
    );
  });
  group('refreshPet', () {
    blocTest<PetCubit, PetState>(
      'keeps the loaded profile while refreshing and retains it on failure',
      build: () {
        when(() => repository.getPetById(pet.id)).thenAnswer(
          (_) async => const Error(LocalDatabaseFailure('Refresh failed')),
        );
        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      seed: () => const PetLoaded(pet),
      act: (cubit) => cubit.refreshPet(pet.id),
      expect: () => [
        const PetLoaded(pet, isRefreshing: true),
        const PetLoaded(pet, refreshError: 'Refresh failed'),
      ],
    );
    blocTest<PetCubit, PetState>(
      'refresh replaces the profile without a loading-only state',
      build: () {
        when(
          () => repository.getPetById(pet.id),
        ).thenAnswer((_) async => Success(pet.copyWith(weight: 4.5)));
        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      seed: () => const PetLoaded(pet),
      act: (cubit) => cubit.refreshPet(pet.id),
      expect: () => [
        const PetLoaded(pet, isRefreshing: true),
        PetLoaded(pet.copyWith(weight: 4.5)),
      ],
    );
    test('a late refresh cannot clear a deletion failure', () async {
      when(
        () => repository.getPetById(pet.id),
      ).thenAnswer((_) async => const Success(pet));
      final cubit = PetCubit(repository, createPet, updatePet, deletePet);
      addTearDown(cubit.close);
      await cubit.getPetById(pet.id);
      final pending = Completer<Result<Pet>>();
      when(
        () => repository.getPetById(pet.id),
      ).thenAnswer((_) => pending.future);
      when(() => deletePet(pet)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Delete failed')),
      );
      final refresh = cubit.refreshPet(pet.id);
      await cubit.deletePet(pet);
      pending.complete(const Success(pet));
      await refresh;
      expect(cubit.state, const PetLoaded(pet, deleteError: 'Delete failed'));
    });
  });
  group('createPet', () {
    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetCreated when use case succeeds',
      build: () {
        when(
          () => createPet(createParams),
        ).thenAnswer((_) async => const Success(null));

        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      act: (cubit) => cubit.createPet(createParams),
      expect: () => [const PetLoading(), const PetCreated()],
      verify: (_) {
        verify(() => createPet(createParams)).called(1);
      },
    );

    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetError when use case fails',
      build: () {
        when(() => createPet(createParams)).thenAnswer(
          (_) async =>
              const Error(LocalDatabaseFailure('Failed to create pet')),
        );

        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      act: (cubit) => cubit.createPet(createParams),
      expect: () => [
        const PetLoading(),
        const PetError('Failed to create pet'),
      ],
      verify: (_) {
        verify(() => createPet(createParams)).called(1);
      },
    );
  });
  group('updatePet', () {
    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetUpdated when use case succeeds',
      build: () {
        when(
          () => updatePet(pet, updateParams),
        ).thenAnswer((_) async => const Success(null));

        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      act: (cubit) => cubit.updatePet(pet, updateParams),
      expect: () => [const PetLoading(), const PetUpdated()],
      verify: (_) {
        verify(() => updatePet(pet, updateParams)).called(1);
      },
    );

    blocTest<PetCubit, PetState>(
      'emits PetLoading and PetError when use case fails',
      build: () {
        when(() => updatePet(pet, updateParams)).thenAnswer(
          (_) async =>
              const Error(LocalDatabaseFailure('Failed to update pet')),
        );

        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      act: (cubit) => cubit.updatePet(pet, updateParams),
      expect: () => [
        const PetLoading(),
        const PetError('Failed to update pet'),
      ],
      verify: (_) {
        verify(() => updatePet(pet, updateParams)).called(1);
      },
    );
  });
  group('deletePet', () {
    blocTest<PetCubit, PetState>(
      'keeps the profile while deleting and emits PetDeleted on success',
      build: () {
        when(() => deletePet(pet)).thenAnswer((_) async => const Success(null));
        when(
          () => repository.getPets(),
        ).thenAnswer((_) async => const Success([]));

        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      act: (cubit) => cubit.deletePet(pet),
      expect: () => [
        const PetLoaded(pet, isDeleting: true),
        const PetDeleted(),
      ],
      verify: (_) {
        verify(() => deletePet(pet)).called(1);
        verifyNever(() => repository.getPets());
      },
    );

    blocTest<PetCubit, PetState>(
      'restores the profile with a deletion error when the use case fails',
      build: () {
        when(() => deletePet(pet)).thenAnswer(
          (_) async =>
              const Error(LocalDatabaseFailure('Failed to delete pet')),
        );

        return PetCubit(repository, createPet, updatePet, deletePet);
      },
      act: (cubit) => cubit.deletePet(pet),
      expect: () => [
        const PetLoaded(pet, isDeleting: true),
        const PetLoaded(pet, deleteError: 'Failed to delete pet'),
      ],
      verify: (_) {
        verify(() => deletePet(pet)).called(1);
        verifyNever(() => repository.getPets());
      },
    );
  });

  group('closing during a pending operation', () {
    for (final succeeds in [true, false]) {
      final outcome = succeeds ? 'success' : 'failure';
      const failure = LocalDatabaseFailure('Operation failed');

      test('loadPets ignores $outcome after close', () async {
        final pending = Completer<Result<List<Pet>>>();
        when(() => repository.getPets()).thenAnswer((_) => pending.future);
        final cubit = PetCubit(repository, createPet, updatePet, deletePet);

        final operation = cubit.loadPets();
        await cubit.close();
        pending.complete(
          succeeds ? const Success([pet]) : const Error(failure),
        );

        await expectLater(operation, completes);
        expect(cubit.state, const PetLoading());
      });

      test('getPetById ignores $outcome after close', () async {
        final pending = Completer<Result<Pet>>();
        when(
          () => repository.getPetById(pet.id),
        ).thenAnswer((_) => pending.future);
        final cubit = PetCubit(repository, createPet, updatePet, deletePet);

        final operation = cubit.getPetById(pet.id);
        await cubit.close();
        pending.complete(succeeds ? const Success(pet) : const Error(failure));

        await expectLater(operation, completes);
        expect(cubit.state, const PetLoading());
      });

      test('createPet ignores $outcome after close', () async {
        final pending = Completer<Result<void>>();
        when(() => createPet(createParams)).thenAnswer((_) => pending.future);
        final cubit = PetCubit(repository, createPet, updatePet, deletePet);

        final operation = cubit.createPet(createParams);
        await cubit.close();
        pending.complete(succeeds ? const Success(null) : const Error(failure));

        await expectLater(operation, completes);
        expect(cubit.state, const PetLoading());
      });

      test('updatePet ignores $outcome after close', () async {
        final pending = Completer<Result<void>>();
        when(
          () => updatePet(pet, updateParams),
        ).thenAnswer((_) => pending.future);
        final cubit = PetCubit(repository, createPet, updatePet, deletePet);

        final operation = cubit.updatePet(pet, updateParams);
        await cubit.close();
        pending.complete(succeeds ? const Success(null) : const Error(failure));

        await expectLater(operation, completes);
        expect(cubit.state, const PetLoading());
      });

      test(
        'deletePet ignores $outcome without reloading after close',
        () async {
          final pending = Completer<Result<void>>();
          when(() => deletePet(pet)).thenAnswer((_) => pending.future);
          final cubit = PetCubit(repository, createPet, updatePet, deletePet);

          final operation = cubit.deletePet(pet);
          await cubit.close();
          pending.complete(
            succeeds ? const Success(null) : const Error(failure),
          );

          await expectLater(operation, completes);
          expect(cubit.state, const PetLoaded(pet, isDeleting: true));
          verifyNever(() => repository.getPets());
        },
      );
    }
  });
}
