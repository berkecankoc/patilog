import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/storage/image_storage.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';
import 'package:patilog/features/pet/domain/use_cases/delete_pet.dart';

class MockPets extends Mock implements PetRepository {}

class MockImages extends Mock implements ImageStorage {}

void main() {
  const pet = Pet(
    id: 'a',
    name: 'Toby',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  const other = Pet(
    id: 'b',
    name: 'Toby',
    species: PetSpecies.dog,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  const failure = LocalDatabaseFailure('Try again');
  late MockPets repository;
  late AllPetsCareCubit cubit;
  setUp(() {
    repository = MockPets();
    when(repository.getPets)
        .thenAnswer((_) async => const Success([pet, other]));
    cubit = AllPetsCareCubit(repository, DeletePet(repository, MockImages()));
  });
  tearDown(() => cubit.close());

  blocTest<AllPetsCareCubit, AllPetsCareState>(
    'loads the shared directory',
    build: () => cubit,
    act: (c) => c.loadPets(),
    expect: () => [
      isA<AllPetsCareState>().having((s) => s.pets.isLoading, 'loading', true),
      isA<AllPetsCareState>()
          .having((s) => s.pets.records, 'pets', [pet, other])
          .having((s) => s.pets.hasLoaded, 'loaded', true),
    ],
  );
  test(
    'all destinations reuse the directory; unchanged activation does no read',
    () async {
      for (final section in AllPetsCareSection.values) {
        await cubit.activate(section);
      }
      await cubit.activate(AllPetsCareSection.pets);
      verify(repository.getPets).called(1);
      expect(cubit.state.activeSection, AllPetsCareSection.pets);
    },
  );
  test(
    'initial failure is not an empty result or automatically retried',
    () async {
      when(repository.getPets).thenAnswer((_) async => const Error(failure));
      await cubit.activate(AllPetsCareSection.vetVisits);
      await cubit.activate(AllPetsCareSection.medications);
      expect(cubit.state.pets.hasLoaded, isFalse);
      expect(cubit.state.pets.error, 'Try again');
      verify(repository.getPets).called(1);
      when(repository.getPets).thenAnswer((_) async => const Success([]));
      await cubit.loadPets();
      expect(cubit.state.pets.hasLoaded, isTrue);
      expect(cubit.state.pets.error, isNull);
    },
  );
  test('failed refresh retains names and supports retry', () async {
    await cubit.loadPets();
    when(repository.getPets).thenAnswer((_) async => const Error(failure));
    await cubit.loadPets();
    expect(cubit.state.pets.records, [pet, other]);
    expect(cubit.state.pets.hasLoaded, isTrue);
    expect(cubit.state.pets.error, 'Try again');
  });
  test(
    'invalidation supersedes an old read and refreshes once on activation',
    () async {
      final pending = Completer<Result<List<Pet>>>();
      when(repository.getPets).thenAnswer((_) => pending.future);
      final old = cubit.loadPets();
      cubit.invalidatePets();
      when(repository.getPets).thenAnswer((_) async => const Success([other]));
      await cubit.activate(AllPetsCareSection.vaccinations);
      pending.complete(const Success([pet]));
      await old;
      expect(cubit.state.pets.records, [other]);
      await cubit.activate(AllPetsCareSection.pets);
      verify(repository.getPets).called(2);
    },
  );
  for (final fails in [false, true]) {
    test(
      'known deletion survives a late ${fails ? 'failed' : 'successful'} refresh without another read',
      () async {
        await cubit.loadPets();
        final pending = Completer<Result<List<Pet>>>();
        when(repository.getPets).thenAnswer((_) => pending.future);
        final refresh = cubit.loadPets();
        cubit.removeDeletedPet('b');
        pending.complete(
          fails ? const Error(failure) : const Success([pet, other]),
        );
        await refresh;
        expect(cubit.state.pets.records, [pet]);
        verify(repository.getPets).called(2);
      },
    );
  }
  test('known deletion during the first read is not restored', () async {
    final pending = Completer<Result<List<Pet>>>();
    when(repository.getPets).thenAnswer((_) => pending.future);
    final read = cubit.loadPets();
    cubit.removeDeletedPet('a');
    pending.complete(const Success([pet, other]));
    await read;
    expect(cubit.state.pets.records, [other]);
  });
  test(
    'closed directory ignores awaited results and starts no further reads',
    () async {
      final pending = Completer<Result<List<Pet>>>();
      when(repository.getPets).thenAnswer((_) => pending.future);
      final read = cubit.loadPets();
      await cubit.close();
      final closed = cubit.state;
      pending.complete(const Success([pet, other]));
      await read;
      await cubit.activate(AllPetsCareSection.feeding);
      expect(cubit.state, same(closed));
      verify(repository.getPets).called(1);
    },
  );
  group('pinning', () {
    setUp(() async {
      await cubit.loadPets();
      clearInteractions(repository);
    });

    test('blocks repeats while saving, then reloads the saved order', () async {
      final write = Completer<Result<void>>();
      when(() => repository.setPetPinned('b', pinned: true))
          .thenAnswer((_) => write.future);
      final pinned = other.copyWith(isPinned: true);
      when(repository.getPets).thenAnswer((_) async => Success([pinned, pet]));

      final saving = cubit.setPetPinned('b', pinned: true);
      expect(cubit.state.pinningPetIds, {'b'});
      expect(await cubit.setPetPinned('b', pinned: true), isFalse);
      write.complete(const Success(null));

      expect(await saving, isTrue);
      expect(cubit.state.pinningPetIds, isEmpty);
      expect(cubit.state.pets.records, [pinned, pet]);
      verify(() => repository.setPetPinned('b', pinned: true)).called(1);
      verify(repository.getPets).called(1);
    });

    test('failed write keeps the list and order without a reload', () async {
      when(() => repository.setPetPinned('b', pinned: true))
          .thenAnswer((_) async => const Error(failure));

      expect(await cubit.setPetPinned('b', pinned: true), isFalse);
      expect(cubit.state.pinningPetIds, isEmpty);
      expect(cubit.state.pets.records, [pet, other]);
      verifyNever(repository.getPets);
    });

    test('saved pin stays visible when the reordering read fails', () async {
      when(() => repository.setPetPinned('a', pinned: true))
          .thenAnswer((_) async => const Success(null));
      when(repository.getPets).thenAnswer((_) async => const Error(failure));

      expect(await cubit.setPetPinned('a', pinned: true), isTrue);
      expect(cubit.state.pets.records, [pet.copyWith(isPinned: true), other]);
      expect(cubit.state.pets.error, 'Try again');
    });
  });

  group('deletion', () {
    test('blocks concurrent deletes and clears the pending pet', () async {
      final write = Completer<Result<void>>();
      when(() => repository.deletePet('a')).thenAnswer((_) => write.future);
      final deleting = cubit.deletePet(pet);
      expect(cubit.state.deletingPetIds, {'a'});
      expect(await cubit.deletePet(other), isFalse);
      write.complete(const Success(null));
      expect(await deleting, isTrue);
      expect(cubit.state.deletingPetIds, isEmpty);
      verify(() => repository.deletePet('a')).called(1);
      verifyNever(() => repository.deletePet('b'));
    });

    test('failed delete reports false and keeps the directory', () async {
      await cubit.loadPets();
      when(() => repository.deletePet('a'))
          .thenAnswer((_) async => const Error(failure));
      expect(await cubit.deletePet(pet), isFalse);
      expect(cubit.state.deletingPetIds, isEmpty);
      expect(cubit.state.pets.records, [pet, other]);
    });
  });
}
