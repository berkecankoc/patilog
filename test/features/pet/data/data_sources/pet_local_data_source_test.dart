import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/data/data_sources/pet_local_data_source.dart';
import 'package:petlytics/features/pet/data/models/pet_model.dart';
import 'package:petlytics/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/weight_history/data/data_sources/weight_history_local_data_source.dart';
import 'package:petlytics/features/weight_history/data/models/weight_entry_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockImageStorage extends Mock implements ImageStorage {}

class SequenceIds implements IdGenerator {
  int _next = 0;
  @override
  String generate() => 'id-${_next++}';
}

void main() {
  late Directory directory;
  late Database db;
  late PetLocalDataSourceImpl source;
  late WeightHistoryLocalDataSourceImpl history;
  const pet = PetModel(
    id: 'pet-1',
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  final measuredAt = DateTime.utc(2026, 10, 13);
  WeightEntryModel measurement(String id, double weight, DateTime date) =>
      WeightEntryModel(id: id, petId: pet.id, weight: weight, measuredAt: date);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pet-weight-source-');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await openAppDatabase();
    source = PetLocalDataSourceImpl(db);
    history = WeightHistoryLocalDataSourceImpl(db);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'pet creation stores an initial measurement as the only weight source',
    () async {
      final weight = measurement('initial', 4.5, measuredAt);
      await source.createPet(pet, weightEntry: weight);
      expect((await source.getPetById(pet.id)).weight, 4.5);
      expect((await source.getPets()).single.weight, 4.5);
      expect(await history.getWeightEntries(pet.id), [weight]);
      expect(
        (await db.query(DatabaseTables.pets)).single.containsKey('weight'),
        isFalse,
      );
    },
  );

  test('a pet without measurements has no current weight', () async {
    await source.createPet(pet);
    expect((await source.getPetById(pet.id)).weight, isNull);
  });

  test(
    'reads follow dated history, insertion ties, edits and deletion',
    () async {
      await source.createPet(pet);
      await history.createWeightEntry(measurement('latest', 4.5, measuredAt));
      await history.createWeightEntry(
        measurement('older', 4.2, measuredAt.subtract(const Duration(days: 1))),
      );
      expect((await source.getPetById(pet.id)).weight, 4.5);
      await history.createWeightEntry(measurement('tie', 4.6, measuredAt));
      await history.updateWeightEntry(measurement('latest', 4.7, measuredAt));
      expect((await source.getPetById(pet.id)).weight, 4.6);
      await history.deleteWeightEntry('tie');
      expect((await source.getPetById(pet.id)).weight, 4.7);
      await history.deleteWeightEntry('latest');
      expect((await source.getPets()).single.weight, 4.2);
      await history.deleteWeightEntry('older');
      expect((await source.getPetById(pet.id)).weight, isNull);
    },
  );

  test(
    'create rolls back the pet when its initial measurement fails',
    () async {
      await expectLater(
        source.createPet(
          pet,
          weightEntry: measurement('invalid', -1, measuredAt),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getPets(), isEmpty);
      expect(await history.getWeightEntries(pet.id), isEmpty);
    },
  );

  test(
    'update rolls back profile changes when its measurement fails',
    () async {
      await source.createPet(
        pet,
        weightEntry: measurement('initial', 4.5, measuredAt),
      );
      final updated = PetModel.fromEntity(
        pet.toEntity().copyWith(name: 'Updated'),
      );
      await expectLater(
        source.updatePet(
          updated,
          weightEntry: measurement('initial', 4.8, measuredAt),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      final loaded = await source.getPetById(pet.id);
      expect(loaded.name, pet.name);
      expect(loaded.weight, 4.5);
      expect(await history.getWeightEntries(pet.id), hasLength(1));
    },
  );

  test(
    'old independent weight column is ignored without deleting existing records',
    () async {
      await db.execute('ALTER TABLE pets ADD COLUMN weight REAL');
      await source.createPet(pet);
      await db.update(
        DatabaseTables.pets,
        {'weight': 99},
        where: 'id = ?',
        whereArgs: [pet.id],
      );
      expect((await source.getPetById(pet.id)).weight, isNull);
      await history.createWeightEntry(measurement('initial', 4.5, measuredAt));
      expect((await source.getPetById(pet.id)).weight, 4.5);
      expect((await db.query(DatabaseTables.pets)).single['weight'], 99);
    },
  );

  test(
    'real pet use cases add only changed nonempty weights to history',
    () async {
      final repository = PetRepositoryImpl(source);
      final ids = SequenceIds();
      final images = MockImageStorage();
      final create = CreatePet(repository, ids, images);
      final update = UpdatePet(repository, images, ids);
      expect(
        await create(
          const CreatePetParams(
            name: 'Fluffy',
            species: PetSpecies.cat,
            sex: PetSex.female,
            reproductiveStatus: ReproductiveStatus.intact,
            weight: 4.5,
          ),
        ),
        const Success<void>(null),
      );
      final initialPet =
          (await repository.getPets() as Success<List<Pet>>).data.single;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toUtc();
      final initial = (await history.getWeightEntries(initialPet.id)).single;
      expect(initial.measuredAt, today);
      expect(initial.weight, 4.5);
      expect(initial.id, isNot(initialPet.id));

      for (final weight in <double?>[4.5, null, 4.8]) {
        expect(
          await update(
            initialPet,
            UpdatePetParams(
              name: 'Updated',
              species: initialPet.species,
              sex: initialPet.sex,
              reproductiveStatus: initialPet.reproductiveStatus,
              weight: weight,
            ),
          ),
          const Success<void>(null),
        );
      }
      final measurements = await history.getWeightEntries(initialPet.id);
      expect(measurements.map((e) => e.weight), [4.8, 4.5]);
      expect(measurements.every((e) => e.measuredAt == today), isTrue);
      expect((await source.getPetById(initialPet.id)).weight, 4.8);
      verifyZeroInteractions(images);
    },
  );

  test('a missing pet cannot create a measurement during update', () async {
    await expectLater(
      source.updatePet(pet, weightEntry: measurement('new', 4.5, measuredAt)),
      throwsA(isA<LocalDataNotFoundException>()),
    );
    expect(await history.getWeightEntries(pet.id), isEmpty);
  });

  test(
    'pet deletion cascades its measurements and leaves other pets intact',
    () async {
      const other = PetModel(
        id: 'pet-2',
        name: 'Buddy',
        species: PetSpecies.dog,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      );
      await source.createPet(
        pet,
        weightEntry: measurement('weight-1', 4.5, measuredAt),
      );
      await history.createWeightEntry(measurement('weight-2', 4.6, measuredAt));
      await source.createPet(
        other,
        weightEntry: WeightEntryModel(
          id: 'other-weight',
          petId: other.id,
          weight: 10,
          measuredAt: measuredAt,
        ),
      );
      final images = MockImageStorage();
      final delete = DeletePet(PetRepositoryImpl(source), images);
      expect(await delete(pet.toEntity()), const Success<void>(null));
      expect(await history.getWeightEntries(pet.id), isEmpty);
      expect((await source.getPets()).single.id, other.id);
      expect((await history.getWeightEntries(other.id)).single.weight, 10);
      verifyZeroInteractions(images);
    },
  );
}
