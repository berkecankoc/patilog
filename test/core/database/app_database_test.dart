import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  Database? db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('app-db-');
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDown(() async {
    await db?.close();
    await directory.delete(recursive: true);
  });

  test(
    'fresh installation creates care tables and enables foreign keys',
    () async {
      db = await openAppDatabase();
      expect(await db!.getVersion(), 2);
      expect(await db!.query(DatabaseTables.weightEntries), isEmpty);
      expect(await db!.query('vet_visits'), isEmpty);
      expect(
        (await db!.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
        1,
      );
      final foreignKey = (await db!.rawQuery(
        'PRAGMA foreign_key_list(weight_entries)',
      )).single;
      expect(foreignKey['table'], DatabaseTables.pets);
      expect(foreignKey['on_delete'], 'CASCADE');
      final visitForeignKey = (await db!.rawQuery(
        'PRAGMA foreign_key_list(vet_visits)',
      )).single;
      expect(visitForeignKey['table'], DatabaseTables.pets);
      expect(visitForeignKey['on_delete'], 'CASCADE');
    },
  );

  test(
    'version 1 upgrade preserves pets and measurements across reopen',
    () async {
      final legacy = await databaseFactory.openDatabase(
        join(directory.path, 'petlytics.db'),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
            CREATE TABLE pets (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              species TEXT NOT NULL,
              sex TEXT NOT NULL,
              reproductive_status TEXT NOT NULL,
              breed TEXT,
              birth_date TEXT,
              microchip_id TEXT,
              image_path TEXT
            )
          ''');
            await db.execute('''
            CREATE TABLE weight_entries (
              id TEXT PRIMARY KEY,
              pet_id TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
              weight REAL NOT NULL CHECK (weight > 0),
              measured_at TEXT NOT NULL
            )
          ''');
          },
        ),
      );
      final pet = {
        'id': 'pet-1',
        'name': 'Milo',
        'species': 'cat',
        'sex': 'male',
        'reproductive_status': 'intact',
        'breed': 'Tabby',
        'birth_date': '2024-05-01',
        'microchip_id': 'chip-1',
        'image_path': 'milo.jpg',
      };
      final weight = {
        'id': 'weight-1',
        'pet_id': 'pet-1',
        'weight': 4.5,
        'measured_at': '2026-10-15T10:00:00.000000Z',
      };
      await legacy.insert('pets', pet);
      await legacy.insert('weight_entries', weight);
      await legacy.close();

      db = await openAppDatabase();
      expect(await db!.getVersion(), 2);
      expect(await db!.query('pets'), [pet]);
      expect(await db!.query('weight_entries'), [weight]);
      expect(await db!.query('vet_visits'), isEmpty);
      await db!.insert('vet_visits', {
        'id': 'visit-1',
        'pet_id': 'pet-1',
        'visited_on': '2026-10-15',
        'reason': 'Checkup',
      });
      await db!.close();

      db = await openAppDatabase();
      expect(await db!.query('vet_visits'), hasLength(1));
      await db!.delete('pets', where: 'id = ?', whereArgs: ['pet-1']);
      expect(await db!.query('vet_visits'), isEmpty);
      expect(await db!.query('weight_entries'), isEmpty);
    },
  );
}
