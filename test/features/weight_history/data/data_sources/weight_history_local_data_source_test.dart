import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/weight_history/data/data_sources/weight_history_local_data_source.dart';
import 'package:petlytics/features/weight_history/data/models/weight_entry_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late Database db;
  late WeightHistoryLocalDataSourceImpl source;
  final measuredAt = DateTime.utc(2026, 10, 13);
  final entry = WeightEntryModel(
    id: 'entry-1',
    petId: 'pet-1',
    weight: 5.4,
    measuredAt: measuredAt,
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('weight-source-');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await openAppDatabase();
    source = WeightHistoryLocalDataSourceImpl(db);
    for (final id in ['pet-1', 'pet-2']) {
      await db.insert(DatabaseTables.pets, {
        'id': id,
        'name': id,
        'species': 'cat',
        'sex': 'female',
        'reproductive_status': 'intact',
      });
    }
  });

  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test('returns an empty history when there are no measurements', () async {
    expect(await source.getWeightEntries('pet-1'), isEmpty);
    expect(await source.getAllWeightEntries(), isEmpty);
  });

  test('all-pet reads preserve ownership, date order and insertion ties after edits and pet deletion', () async {
    final other = WeightEntryModel(
      id: 'other',
      petId: 'pet-2',
      weight: 7,
      measuredAt: measuredAt,
    );
    final latest = WeightEntryModel(
      id: 'latest',
      petId: entry.petId,
      weight: 5.5,
      measuredAt: measuredAt.add(const Duration(days: 1)),
    );
    await source.createWeightEntry(entry);
    await source.createWeightEntry(other);
    await source.createWeightEntry(latest);
    expect(await source.getAllWeightEntries(), [latest, other, entry]);
    final corrected = WeightEntryModel(
      id: entry.id,
      petId: entry.petId,
      weight: 5.6,
      measuredAt: measuredAt,
    );
    await source.updateWeightEntry(corrected);
    expect(await source.getAllWeightEntries(), [latest, other, corrected]);
    expect(await source.getWeightEntries('pet-2'), [other]);
    await db.delete(DatabaseTables.pets, where: 'id = ?', whereArgs: ['pet-2']);
    expect(await source.getAllWeightEntries(), [latest, corrected]);
  });

  test(
    'create and update persist three decimals without changing tie order',
    () async {
      WeightEntryModel value(double weight) => WeightEntryModel(
        id: entry.id,
        petId: entry.petId,
        weight: weight,
        measuredAt: measuredAt,
      );
      await source.createWeightEntry(value(5.4326));
      expect(
        (await db.query(DatabaseTables.weightEntries)).single['weight'],
        5.433,
      );
      await source.createWeightEntry(
        WeightEntryModel(
          id: 'tie',
          petId: entry.petId,
          weight: 0.001,
          measuredAt: measuredAt,
        ),
      );
      await source.updateWeightEntry(value(5.4324));
      final stored = await source.getWeightEntries(entry.petId);
      expect(stored.map((e) => e.id), ['tie', entry.id]);
      expect(stored.map((e) => e.weight), [0.001, 5.432]);
      expect(stored.every((e) => e.measuredAt == measuredAt), isTrue);
    },
  );

  test(
    'stores measurements and lists only the requested pet newest first',
    () async {
      final older = WeightEntryModel(
        id: 'older',
        petId: entry.petId,
        weight: 5.2,
        measuredAt: measuredAt.subtract(const Duration(days: 1)),
      );
      final otherPet = WeightEntryModel(
        id: 'other',
        petId: 'pet-2',
        weight: 7,
        measuredAt: measuredAt,
      );
      await source.createWeightEntry(entry);
      await source.createWeightEntry(otherPet);
      await source.createWeightEntry(older);

      expect(await source.getWeightEntries(entry.petId), [entry, older]);
      expect(await source.getWeightEntries(otherPet.petId), [otherPet]);
    },
  );

  test(
    'sorts measurements within a millisecond and resolves exact ties by insertion',
    () async {
      final later = WeightEntryModel(
        id: 'later',
        petId: entry.petId,
        weight: 5.5,
        measuredAt: measuredAt.add(const Duration(microseconds: 1)),
      );
      final tie = WeightEntryModel(
        id: 'tie',
        petId: entry.petId,
        weight: 5.6,
        measuredAt: measuredAt,
      );
      await source.createWeightEntry(later);
      await source.createWeightEntry(entry);
      await source.createWeightEntry(tie);

      expect(await source.getWeightEntries(entry.petId), [later, tie, entry]);
    },
  );

  test('updates the weight and date of an existing measurement', () async {
    await source.createWeightEntry(entry);
    final updated = WeightEntryModel(
      id: entry.id,
      petId: entry.petId,
      weight: 5.8,
      measuredAt: measuredAt.subtract(const Duration(days: 1)),
    );
    await source.updateWeightEntry(updated);
    expect(await source.getWeightEntries(entry.petId), [updated]);
  });

  test('does not move a measurement to a different pet', () async {
    await source.createWeightEntry(entry);
    await expectLater(
      source.updateWeightEntry(
        WeightEntryModel(
          id: entry.id,
          petId: 'pet-2',
          weight: entry.weight,
          measuredAt: measuredAt,
        ),
      ),
      throwsA(isA<LocalDataNotFoundException>()),
    );
    expect(await source.getWeightEntries(entry.petId), [entry]);
    expect(await source.getWeightEntries('pet-2'), isEmpty);
  });

  test('deletes an existing measurement', () async {
    await source.createWeightEntry(entry);
    await source.deleteWeightEntry(entry.id);
    expect(await source.getWeightEntries(entry.petId), isEmpty);
  });

  test('reports missing measurements for update and delete', () async {
    await expectLater(
      source.updateWeightEntry(entry),
      throwsA(isA<LocalDataNotFoundException>()),
    );
    await expectLater(
      source.deleteWeightEntry(entry.id),
      throwsA(isA<LocalDataNotFoundException>()),
    );
  });

  test('rejects measurements for a missing pet', () async {
    await expectLater(
      source.createWeightEntry(
        WeightEntryModel(
          id: entry.id,
          petId: 'missing',
          weight: entry.weight,
          measuredAt: measuredAt,
        ),
      ),
      throwsA(isA<LocalDataSourceException>()),
    );
  });

  test('duplicate IDs do not overwrite an existing measurement', () async {
    await source.createWeightEntry(entry);
    await expectLater(
      source.createWeightEntry(entry),
      throwsA(isA<LocalDataSourceException>()),
    );
    expect(await source.getWeightEntries(entry.petId), [entry]);
  });

  test('pet deletion cascades to its measurements', () async {
    await source.createWeightEntry(entry);
    await db.delete(
      DatabaseTables.pets,
      where: 'id = ?',
      whereArgs: [entry.petId],
    );
    expect(await source.getWeightEntries(entry.petId), isEmpty);
  });

  test('identifier strings are treated as values rather than SQL', () async {
    await source.createWeightEntry(entry);
    const injectedId = "' OR 1=1 --";
    expect(await source.getWeightEntries(injectedId), isEmpty);
    await expectLater(
      source.deleteWeightEntry(injectedId),
      throwsA(isA<LocalDataNotFoundException>()),
    );
    expect(await source.getWeightEntries(entry.petId), [entry]);
  });

  for (final operation in ['read', 'readAll', 'create', 'update', 'delete']) {
    test('maps SQLite errors for $operation', () async {
      await db.execute('DROP TABLE ${DatabaseTables.weightEntries}');
      final result = switch (operation) {
        'read' => source.getWeightEntries(entry.petId),
        'readAll' => source.getAllWeightEntries(),
        'create' => source.createWeightEntry(entry),
        'update' => source.updateWeightEntry(entry),
        _ => source.deleteWeightEntry(entry.id),
      };
      await expectLater(result, throwsA(isA<LocalDataSourceException>()));
    });
  }
}
