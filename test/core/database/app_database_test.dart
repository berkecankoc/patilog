import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/database/database_tables.dart';
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
    'fresh installation creates the weight table and enables foreign keys',
    () async {
      db = await openAppDatabase();
      expect(await db!.getVersion(), 1);
      expect(await db!.query(DatabaseTables.weightEntries), isEmpty);
      expect(
        (await db!.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
        1,
      );
      final foreignKey = (await db!.rawQuery(
        'PRAGMA foreign_key_list(weight_entries)',
      )).single;
      expect(foreignKey['table'], DatabaseTables.pets);
      expect(foreignKey['on_delete'], 'CASCADE');
    },
  );
}
