import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/pet/data/data_sources/pet_local_data_source.dart';
import 'package:petlytics/features/pet/data/models/pet_model.dart';
import 'package:petlytics/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/data/models/weight_entry_model.dart';

class MockPetLocalDataSource extends Mock implements PetLocalDataSource {}

void main() {
  late MockPetLocalDataSource localDataSource;
  late PetRepositoryImpl repository;

  final pet = Pet(
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

  final petModel = PetModel.fromEntity(pet);

  setUp(() {
    localDataSource = MockPetLocalDataSource();
    repository = PetRepositoryImpl(localDataSource);
  });

  for (final creating in [true, false]) {
    test(
      '${creating ? 'create' : 'update'} passes the measurement model to the atomic save',
      () async {
        final entry = WeightEntry(
          id: 'weight-1',
          petId: pet.id,
          weight: 5.4,
          measuredAt: DateTime(2026),
        );
        final model = WeightEntryModel.fromEntity(entry);
        if (creating) {
          when(
            () => localDataSource.createPet(petModel, weightEntry: model),
          ).thenAnswer((_) async {});
          expect(
            await repository.createPet(pet, weightEntry: entry),
            const Success<void>(null),
          );
          verify(
            () => localDataSource.createPet(petModel, weightEntry: model),
          ).called(1);
        } else {
          when(
            () => localDataSource.updatePet(petModel, weightEntry: model),
          ).thenAnswer((_) async {});
          expect(
            await repository.updatePet(pet, weightEntry: entry),
            const Success<void>(null),
          );
          verify(
            () => localDataSource.updatePet(petModel, weightEntry: model),
          ).called(1);
        }
      },
    );
  }

  group('createPet', () {
    test('returns Success<void> when data source succeeds', () async {
      when(() => localDataSource.createPet(petModel)).thenAnswer((_) async {});

      final result = await repository.createPet(pet);

      expect(result, const Success<void>(null));

      verify(() => localDataSource.createPet(petModel)).called(1);
    });

    test(
      'returns LocalDatabaseFailure when data source throws LocalDataSourceException',
      () async {
        when(
          () => localDataSource.createPet(petModel),
        ).thenThrow(const LocalDataSourceException());

        final result = await repository.createPet(pet);

        expect(
          result,
          const Error<void>(LocalDatabaseFailure('Failed to create pet')),
        );

        verify(() => localDataSource.createPet(petModel)).called(1);
      },
    );
  });

  group('deletePet', () {
    test('returns Success<void> when data source succeeds', () async {
      when(() => localDataSource.deletePet(pet.id)).thenAnswer((_) async {});

      final result = await repository.deletePet(pet.id);

      expect(result, const Success<void>(null));

      verify(() => localDataSource.deletePet(pet.id)).called(1);
    });

    test(
      'returns LocalDatabaseFailure when data source throws LocalDataSourceException',
      () async {
        when(
          () => localDataSource.deletePet(pet.id),
        ).thenThrow(const LocalDataSourceException());

        final result = await repository.deletePet(pet.id);

        expect(
          result,
          const Error<void>(LocalDatabaseFailure('Failed to delete pet')),
        );

        verify(() => localDataSource.deletePet(pet.id)).called(1);
      },
    );

    test(
      'returns NotFoundFailure when data source throws LocalDataNotFoundException',
      () async {
        when(
          () => localDataSource.deletePet(pet.id),
        ).thenThrow(const LocalDataNotFoundException());

        final result = await repository.deletePet(pet.id);

        expect(result, const Error<void>(NotFoundFailure('Pet not found')));

        verify(() => localDataSource.deletePet(pet.id)).called(1);
      },
    );
  });

  group('getPetById', () {
    test('returns Success<Pet> when data source succeeds', () async {
      when(
        () => localDataSource.getPetById(pet.id),
      ).thenAnswer((_) async => petModel);

      final result = await repository.getPetById(pet.id);

      expect(result, Success<Pet>(pet));

      verify(() => localDataSource.getPetById(pet.id)).called(1);
    });

    test(
      'returns LocalDatabaseFailure when data source throws LocalDataSourceException',
      () async {
        when(
          () => localDataSource.getPetById(pet.id),
        ).thenThrow(const LocalDataSourceException());

        final result = await repository.getPetById(pet.id);

        expect(
          result,
          const Error<Pet>(LocalDatabaseFailure('Failed to get pet')),
        );

        verify(() => localDataSource.getPetById(pet.id)).called(1);
      },
    );

    test(
      'returns NotFoundFailure when data source throws LocalDataNotFoundException',
      () async {
        when(
          () => localDataSource.getPetById(pet.id),
        ).thenThrow(const LocalDataNotFoundException());

        final result = await repository.getPetById(pet.id);

        expect(result, const Error<Pet>(NotFoundFailure('Pet not found')));

        verify(() => localDataSource.getPetById(pet.id)).called(1);
      },
    );
  });

  group('getPets', () {
    test('returns Success<List<Pet>> when data source succeeds', () async {
      when(() => localDataSource.getPets()).thenAnswer((_) async => [petModel]);

      final result = await repository.getPets();

      expect(result, Success<List<Pet>>([pet]));

      verify(() => localDataSource.getPets()).called(1);
    });

    test('returns Success with an empty list when no pets exist', () async {
      when(() => localDataSource.getPets()).thenAnswer((_) async => []);

      final result = await repository.getPets();

      expect(result, const Success<List<Pet>>([]));

      verify(() => localDataSource.getPets()).called(1);
    });

    test(
      'returns LocalDatabaseFailure when data source throws LocalDataSourceException',
      () async {
        when(
          () => localDataSource.getPets(),
        ).thenThrow(const LocalDataSourceException());

        final result = await repository.getPets();

        expect(
          result,
          const Error<List<Pet>>(LocalDatabaseFailure('Failed to get pets')),
        );

        verify(() => localDataSource.getPets()).called(1);
      },
    );
  });

  group('updatePet', () {
    test('returns Success<void> when data source succeeds', () async {
      when(() => localDataSource.updatePet(petModel)).thenAnswer((_) async {});

      final result = await repository.updatePet(pet);

      expect(result, const Success<void>(null));

      verify(() => localDataSource.updatePet(petModel)).called(1);
    });

    test(
      'returns LocalDatabaseFailure when data source throws LocalDataSourceException',
      () async {
        when(
          () => localDataSource.updatePet(petModel),
        ).thenThrow(const LocalDataSourceException());

        final result = await repository.updatePet(pet);

        expect(
          result,
          const Error<void>(LocalDatabaseFailure('Failed to update pet')),
        );

        verify(() => localDataSource.updatePet(petModel)).called(1);
      },
    );

    test(
      'returns NotFoundFailure when data source throws LocalDataNotFoundException',
      () async {
        when(
          () => localDataSource.updatePet(petModel),
        ).thenThrow(const LocalDataNotFoundException());

        final result = await repository.updatePet(pet);

        expect(result, const Error<void>(NotFoundFailure('Pet not found')));

        verify(() => localDataSource.updatePet(petModel)).called(1);
      },
    );
  });
}
