import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/database/app_database.dart';
import 'package:patilog/core/database/database_tables.dart';
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
      expect(await db!.getVersion(), 6);
      expect(await db!.query(DatabaseTables.weightEntries), isEmpty);
      expect(await db!.query('vet_visits'), isEmpty);
      expect(await db!.query(DatabaseTables.vaccinations), isEmpty);
      expect(await db!.query(DatabaseTables.medications), isEmpty);
      expect(await db!.query(DatabaseTables.medicationPeriods), isEmpty);
      expect(await db!.query(DatabaseTables.medicationDoseLogs), isEmpty);
      expect(await db!.query(DatabaseTables.feedingPlans), isEmpty);
      expect(await db!.query(DatabaseTables.feedingMeals), isEmpty);
      expect(await db!.query(DatabaseTables.feedingEntries), isEmpty);
      final reminderColumn = (await db!.rawQuery(
        'PRAGMA table_info(vaccinations)',
      )).singleWhere((column) => column['name'] == 'reminder_settings');
      expect(reminderColumn['type'], 'TEXT');
      expect(reminderColumn['notnull'], 0);
      expect(reminderColumn['dflt_value'], isNull);
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
      final vaccinationForeignKeys = await db!.rawQuery(
        'PRAGMA foreign_key_list(vaccinations)',
      );
      expect(
        vaccinationForeignKeys.map(
          (key) => (key['from'], key['table'], key['on_delete']),
        ),
        unorderedEquals([
          ('pet_id', DatabaseTables.pets, 'CASCADE'),
          ('vet_visit_id', DatabaseTables.vetVisits, 'SET NULL'),
        ]),
      );
    },
  );

  for (final legacyVersion in [1, 2, 3, 4, 5]) {
    test(
      'version $legacyVersion upgrade preserves existing care data across reopen',
      () async {
        final legacy = await databaseFactory.openDatabase(
          join(directory.path, 'patilog.db'),
          options: OpenDatabaseOptions(
            version: legacyVersion,
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
              if (legacyVersion >= 2) {
                await db.execute('''
                CREATE TABLE vet_visits (
                  id TEXT PRIMARY KEY,
                  pet_id TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
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
              if (legacyVersion >= 3) {
                await db.execute('''
                  CREATE TABLE vaccinations (
                    id TEXT PRIMARY KEY,
                    pet_id TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
                    vaccine_name TEXT NOT NULL CHECK (length(trim(vaccine_name)) > 0),
                    status TEXT NOT NULL CHECK (status IN ('planned', 'administered')),
                    date TEXT NOT NULL,
                    clinic_name TEXT,
                    veterinarian_name TEXT,
                    notes TEXT,
                    vet_visit_id TEXT REFERENCES vet_visits(id) ON DELETE SET NULL,
                    CHECK (status = 'administered' OR vet_visit_id IS NULL)
                  )
                ''');
              }
              if (legacyVersion >= 4) {
                await db.execute('''
                  CREATE TABLE medications (
                    id TEXT PRIMARY KEY,
                    pet_id TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
                    name TEXT NOT NULL CHECK (length(trim(name)) > 0)
                  )
                ''');
                await db.execute('''
                  CREATE TABLE medication_periods (
                    id TEXT PRIMARY KEY,
                    medication_id TEXT NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
                    start_date TEXT NOT NULL,
                    end_date TEXT,
                    interval_days INTEGER NOT NULL CHECK (typeof(interval_days) = 'integer' AND interval_days > 0),
                    dose_times TEXT NOT NULL,
                    dosage_instructions TEXT,
                    vet_visit_id TEXT REFERENCES vet_visits(id) ON DELETE SET NULL,
                    clinic_name TEXT,
                    veterinarian_name TEXT,
                    notes TEXT,
                    UNIQUE (medication_id, start_date),
                    CHECK (end_date IS NULL OR end_date >= start_date)
                  )
                ''');
                await db.execute('''
                  CREATE TABLE medication_dose_logs (
                    period_id TEXT NOT NULL REFERENCES medication_periods(id) ON DELETE CASCADE,
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
                await db.execute(
                  'CREATE INDEX medications_pet ON medications(pet_id)',
                );
                await db.execute(
                  'CREATE INDEX medication_periods_visit ON medication_periods(vet_visit_id)',
                );
              }
              if (legacyVersion >= 5) {
                await db.execute(
                  'ALTER TABLE vaccinations ADD COLUMN reminder_settings TEXT',
                );
              }
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
        final visit = {
          'id': 'visit-1',
          'pet_id': 'pet-1',
          'visited_on': '2026-10-15',
          'reason': 'Checkup',
          'clinic_name': 'Clinic',
          'veterinarian_name': 'Dr. Smith',
          'diagnosis': 'Healthy',
          'notes': 'Routine visit',
          'cost_minor_units': 125050,
          'currency': 'TRY',
        };
        await legacy.insert('pets', pet);
        await legacy.insert('weight_entries', weight);
        if (legacyVersion >= 2) await legacy.insert('vet_visits', visit);
        final vaccination = {
          'id': 'vaccination-1',
          'pet_id': 'pet-1',
          'vaccine_name': 'Rabies',
          'status': 'administered',
          'date': '2026-10-15',
          'vet_visit_id': 'visit-1',
          'clinic_name': 'Original clinic',
          'veterinarian_name': 'Original veterinarian',
          'notes': 'Preserve this history',
          if (legacyVersion >= 5)
            'reminder_settings': '{"daysBefore":[3,1,0],"minuteOfDay":540}',
        };
        if (legacyVersion >= 3) {
          await legacy.insert('vaccinations', vaccination);
        }
        final medication = {
          'id': 'medication-1',
          'pet_id': 'pet-1',
          'name': 'Medicine',
        };
        final period = {
          'id': 'period-1',
          'medication_id': 'medication-1',
          'start_date': '2026-10-15',
          'end_date': null,
          'interval_days': 1,
          'dose_times': '[540]',
          'dosage_instructions': 'Half a tablet',
          'vet_visit_id': 'visit-1',
          'clinic_name': 'Clinic',
          'veterinarian_name': 'Dr. Smith',
          'notes': 'Keep the schedule',
        };
        final dose = {
          'period_id': 'period-1',
          'scheduled_date': '2026-10-15',
          'scheduled_minute': 540,
          'status': 'given',
          'given_at': '2026-10-15T06:00:00.000Z',
        };
        if (legacyVersion >= 4) {
          await legacy.insert(DatabaseTables.medications, medication);
          await legacy.insert(DatabaseTables.medicationPeriods, period);
          await legacy.insert(DatabaseTables.medicationDoseLogs, dose);
        }
        final legacyTables = [
          'pets',
          'weight_entries',
          if (legacyVersion >= 2) 'vet_visits',
          if (legacyVersion >= 3) 'vaccinations',
          if (legacyVersion >= 4) ...[
            'medications',
            'medication_periods',
            'medication_dose_logs',
          ],
        ];
        final rowIds = {
          for (final table in legacyTables)
            table: await legacy.rawQuery('SELECT rowid FROM $table'),
        };
        await legacy.close();

        db = await openAppDatabase();
        expect(await db!.getVersion(), 6);
        for (final table in legacyTables) {
          expect(await db!.rawQuery('SELECT rowid FROM $table'), rowIds[table]);
        }
        expect(await db!.query(DatabaseTables.feedingPlans), isEmpty);
        expect(await db!.query(DatabaseTables.feedingMeals), isEmpty);
        expect(await db!.query(DatabaseTables.feedingEntries), isEmpty);
        expect(await db!.query('pets'), [pet]);
        expect(await db!.query('weight_entries'), [weight]);
        expect(
          await db!.query(DatabaseTables.vaccinations),
          legacyVersion >= 3
              ? [
                  {'reminder_settings': null, ...vaccination},
                ]
              : isEmpty,
        );
        expect(
          await db!.query(DatabaseTables.medications),
          legacyVersion >= 4 ? [medication] : isEmpty,
        );
        expect(
          await db!.query(DatabaseTables.medicationPeriods),
          legacyVersion >= 4 ? [period] : isEmpty,
        );
        expect(
          await db!.query(DatabaseTables.medicationDoseLogs),
          legacyVersion >= 4 ? [dose] : isEmpty,
        );
        if (legacyVersion == 1) {
          expect(await db!.query('vet_visits'), isEmpty);
          await db!.insert('vet_visits', visit);
        } else {
          expect(await db!.query('vet_visits'), [visit]);
        }
        if (legacyVersion < 3) {
          await db!.insert(DatabaseTables.vaccinations, vaccination);
        }
        await db!.close();

        db = await openAppDatabase();
        expect(await db!.query('pets'), [pet]);
        expect(await db!.query('weight_entries'), [weight]);
        expect(await db!.query('vet_visits'), [visit]);
        expect(await db!.query(DatabaseTables.vaccinations), [
          {'reminder_settings': null, ...vaccination},
        ]);
        if (legacyVersion >= 4) {
          expect(await db!.query(DatabaseTables.medications), [medication]);
          expect(await db!.query(DatabaseTables.medicationPeriods), [period]);
          expect(await db!.query(DatabaseTables.medicationDoseLogs), [dose]);
        }
        expect(
          (await db!.query(DatabaseTables.vaccinations)).single['vet_visit_id'],
          'visit-1',
        );
        await db!.delete('pets', where: 'id = ?', whereArgs: ['pet-1']);
        expect(await db!.query('vet_visits'), isEmpty);
        expect(await db!.query('weight_entries'), isEmpty);
        expect(await db!.query(DatabaseTables.vaccinations), isEmpty);
        expect(await db!.query(DatabaseTables.medications), isEmpty);
        expect(await db!.query(DatabaseTables.medicationPeriods), isEmpty);
        expect(await db!.query(DatabaseTables.medicationDoseLogs), isEmpty);
      },
    );
  }
}
