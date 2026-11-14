import 'package:patilog/core/database/database_tables.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;

const _databaseName = 'patilog.db';
const _databaseVersion = 7;

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
          image_path TEXT,
          custom_species TEXT,
          pin_order INTEGER
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
      await _createVaccinationsTable(db);
      await _createMedicationTables(db);
      await _createFeedingTables(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await _createVetVisitsTable(db);
      if (oldVersion < 3) await _createVaccinationsTable(db);
      if (oldVersion < 4) await _createMedicationTables(db);
      // Older schemas create the current vaccination table above.
      if (oldVersion >= 3 && oldVersion < 5) {
        await db.execute('''
          ALTER TABLE ${DatabaseTables.vaccinations}
          ADD COLUMN reminder_settings TEXT
        ''');
      }
      if (oldVersion < 6) await _createFeedingTables(db);
      if (oldVersion < 7) {
        await db.execute(
          'ALTER TABLE ${DatabaseTables.pets} ADD COLUMN custom_species TEXT',
        );
        // Null means unpinned; increasing values keep pins in pin order.
        await db.execute(
          'ALTER TABLE ${DatabaseTables.pets} ADD COLUMN pin_order INTEGER',
        );
      }
    },
  );
}

Future<void> _createFeedingTables(Database db) async {
  await db.execute('''
    CREATE TABLE ${DatabaseTables.feedingPlans} (
      id TEXT PRIMARY KEY,
      pet_id TEXT NOT NULL REFERENCES ${DatabaseTables.pets}(id) ON DELETE CASCADE,
      start_date TEXT NOT NULL,
      end_date TEXT,
      UNIQUE (pet_id, start_date),
      CHECK (end_date IS NULL OR end_date >= start_date)
    )
  ''');
  await db.execute('''
    CREATE TABLE ${DatabaseTables.feedingMeals} (
      id TEXT PRIMARY KEY,
      plan_id TEXT NOT NULL REFERENCES ${DatabaseTables.feedingPlans}(id) ON DELETE CASCADE,
      scheduled_minute INTEGER NOT NULL CHECK (
        typeof(scheduled_minute) = 'integer' AND scheduled_minute BETWEEN 0 AND 1439
      ),
      amount_grams REAL NOT NULL CHECK (amount_grams > 0),
      food_name TEXT,
      UNIQUE (plan_id, scheduled_minute)
    )
  ''');
  await db.execute('''
    CREATE TABLE ${DatabaseTables.feedingEntries} (
      id TEXT PRIMARY KEY,
      pet_id TEXT NOT NULL REFERENCES ${DatabaseTables.pets}(id) ON DELETE CASCADE,
      amount_grams REAL NOT NULL CHECK (amount_grams > 0),
      given_at TEXT NOT NULL,
      food_name TEXT,
      notes TEXT,
      meal_id TEXT REFERENCES ${DatabaseTables.feedingMeals}(id) ON DELETE NO ACTION,
      scheduled_date TEXT,
      UNIQUE (meal_id, scheduled_date),
      CHECK ((meal_id IS NULL AND scheduled_date IS NULL) OR
             (meal_id IS NOT NULL AND scheduled_date IS NOT NULL))
    )
  ''');
  await db.execute('''
    CREATE INDEX feeding_entries_pet_given_at
    ON ${DatabaseTables.feedingEntries}(pet_id, given_at DESC)
  ''');
  await db.execute('''
    CREATE INDEX feeding_entries_given_at
    ON ${DatabaseTables.feedingEntries}(given_at DESC)
  ''');
  await db.execute('''
    CREATE INDEX feeding_entries_scheduled_date
    ON ${DatabaseTables.feedingEntries}(scheduled_date, pet_id)
  ''');
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

Future<void> _createVaccinationsTable(Database db) async {
  await db.execute('''
    CREATE TABLE ${DatabaseTables.vaccinations} (
      id TEXT PRIMARY KEY,
      pet_id TEXT NOT NULL REFERENCES ${DatabaseTables.pets}(id) ON DELETE CASCADE,
      vaccine_name TEXT NOT NULL CHECK (length(trim(vaccine_name)) > 0),
      status TEXT NOT NULL CHECK (status IN ('planned', 'administered')),
      date TEXT NOT NULL,
      clinic_name TEXT,
      veterinarian_name TEXT,
      notes TEXT,
      vet_visit_id TEXT REFERENCES ${DatabaseTables.vetVisits}(id) ON DELETE SET NULL,
      reminder_settings TEXT,
      CHECK (status = 'administered' OR vet_visit_id IS NULL)
    )
  ''');
}

Future<void> _createMedicationTables(Database db) async {
  await db.execute('''
    CREATE TABLE ${DatabaseTables.medications} (
      id TEXT PRIMARY KEY,
      pet_id TEXT NOT NULL REFERENCES ${DatabaseTables.pets}(id) ON DELETE CASCADE,
      name TEXT NOT NULL CHECK (length(trim(name)) > 0)
    )
  ''');
  await db.execute('''
    CREATE TABLE ${DatabaseTables.medicationPeriods} (
      id TEXT PRIMARY KEY,
      medication_id TEXT NOT NULL REFERENCES ${DatabaseTables.medications}(id) ON DELETE CASCADE,
      start_date TEXT NOT NULL,
      end_date TEXT,
      interval_days INTEGER NOT NULL CHECK (typeof(interval_days) = 'integer' AND interval_days > 0),
      dose_times TEXT NOT NULL,
      dosage_instructions TEXT,
      vet_visit_id TEXT REFERENCES ${DatabaseTables.vetVisits}(id) ON DELETE SET NULL,
      clinic_name TEXT,
      veterinarian_name TEXT,
      notes TEXT,
      UNIQUE (medication_id, start_date),
      CHECK (end_date IS NULL OR end_date >= start_date)
    )
  ''');
  await db.execute('''
    CREATE TABLE ${DatabaseTables.medicationDoseLogs} (
      period_id TEXT NOT NULL REFERENCES ${DatabaseTables.medicationPeriods}(id) ON DELETE CASCADE,
      scheduled_date TEXT NOT NULL,
      scheduled_minute INTEGER NOT NULL CHECK (
        typeof(scheduled_minute) = 'integer' AND scheduled_minute BETWEEN 0 AND 1439
      ),
      status TEXT NOT NULL CHECK (status IN ('given', 'skipped')),
      given_at TEXT,
      PRIMARY KEY (period_id, scheduled_date, scheduled_minute),
      CHECK ((status = 'given' AND given_at IS NOT NULL) OR
             (status = 'skipped' AND given_at IS NULL))
    )
  ''');
  await db.execute('''
    CREATE INDEX medications_pet ON ${DatabaseTables.medications}(pet_id)
  ''');
  await db.execute('''
    CREATE INDEX medication_periods_visit ON ${DatabaseTables.medicationPeriods}(vet_visit_id)
  ''');
}
