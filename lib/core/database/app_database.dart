import 'package:petlytics/core/database/database_tables.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;

const _databaseName = 'petlytics.db';
const _databaseVersion = 1;

Future<Database> openAppDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, _databaseName);

  return openDatabase(
    path,
    version: _databaseVersion,

    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },

    onCreate: (db, version) async {
      // Client-generated TEXT IDs support both offline creation and future multi-device sync.
      await db.execute('''
        CREATE TABLE ${DatabaseTables.pets} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          species TEXT NOT NULL,
          sex TEXT NOT NULL,
          reproductive_status TEXT NOT NULL,
          breed TEXT,
          birth_date TEXT,
          weight REAL,
          microchip_id TEXT,
          image_path TEXT
        )
      ''');
    },
  );
}
