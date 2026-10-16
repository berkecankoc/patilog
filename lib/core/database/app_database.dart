import 'package:petlytics/core/database/database_tables.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;

const _databaseName = 'petlytics.db';
const _databaseVersion = 2;

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
          microchip_id TEXT,
          image_path TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE ${DatabaseTables.weightEntries} (
          id TEXT PRIMARY KEY,
          pet_id TEXT NOT NULL REFERENCES ${DatabaseTables.pets}(id) ON DELETE CASCADE,
          weight REAL NOT NULL CHECK (weight > 0),
          measured_at TEXT NOT NULL
        )
      ''');
      await _createVetVisitsTable(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await _createVetVisitsTable(db);
    },
  );
}

Future<void> _createVetVisitsTable(Database db) async {
  await db.execute('''
    CREATE TABLE ${DatabaseTables.vetVisits} (
      id TEXT PRIMARY KEY,
      pet_id TEXT NOT NULL REFERENCES ${DatabaseTables.pets}(id) ON DELETE CASCADE,
      visited_on TEXT NOT NULL,
      reason TEXT NOT NULL CHECK (length(trim(reason)) > 0),
      clinic_name TEXT,
      veterinarian_name TEXT,
      diagnosis TEXT,
      notes TEXT,
      cost_minor_units INTEGER,
      currency TEXT,
      CHECK (
        (cost_minor_units IS NULL AND currency IS NULL) OR
        (cost_minor_units IS NOT NULL AND typeof(cost_minor_units) = 'integer'
          AND cost_minor_units >= 0 AND currency IS NOT NULL
          AND currency IN ('TRY', 'USD', 'EUR'))
      )
    )
  ''');
}
