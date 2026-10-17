import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/vaccination/data/data_sources/vaccination_local_data_source.dart';
import 'package:petlytics/features/vaccination/data/models/vaccination_model.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late Database db;
  late VaccinationLocalDataSourceImpl source;

  VaccinationModel vaccination({
    String id = 'vaccination-1',
    String petId = 'pet-1',
    String vaccineName = 'Rabies',
    VaccinationStatus status = VaccinationStatus.administered,
    DateTime? date,
    String? clinicName,
    String? veterinarianName,
    String? notes,
    String? vetVisitId,
  }) => VaccinationModel(
    id: id,
    petId: petId,
    vaccineName: vaccineName,
    status: status,
    date: date ?? DateTime(2020, 1, 2),
    clinicName: clinicName,
    veterinarianName: veterinarianName,
    notes: notes,
    vetVisitId: vetVisitId,
  );

  VaccinationModel nextDose() => vaccination(
    id: 'next-dose',
    status: VaccinationStatus.planned,
    date: DateTime(2021, 1, 2),
  );

  Future<void> addVisit({
    String id = 'visit-1',
    String petId = 'pet-1',
    String? clinicName,
    String? veterinarianName,
  }) => db.insert(DatabaseTables.vetVisits, {
    'id': id,
    'pet_id': petId,
    'visited_on': '2020-01-02',
    'reason': 'Checkup',
    'clinic_name': clinicName,
    'veterinarian_name': veterinarianName,
  });

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vaccination-source-');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await openAppDatabase();
    source = VaccinationLocalDataSourceImpl(db);
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

  test('returns empty records and suggestions before saving', () async {
    expect(await source.getVaccinations('pet-1'), isEmpty);
    expect(
      await source.getSuggestions(),
      const VaccinationSuggestions(
        vaccineNames: [],
        clinicNames: [],
        veterinarianNames: [],
      ),
    );
  });

  test(
    'groups and orders this pet records, keeping insertion order on edits',
    () async {
      final original = vaccination();
      final tie = vaccination(id: 'tie');
      final older = vaccination(id: 'older', date: DateTime(2020, 1, 1));
      final planned = vaccination(
        id: 'planned',
        status: VaccinationStatus.planned,
      );
      final plannedTie = vaccination(
        id: 'planned-tie',
        status: VaccinationStatus.planned,
      );
      final later = nextDose();
      final other = vaccination(id: 'other', petId: 'pet-2');
      for (final entry in [
        original,
        planned,
        other,
        later,
        older,
        tie,
        plannedTie,
      ]) {
        await source.createVaccination(entry);
      }
      expect(await source.getVaccinations('pet-1'), [
        plannedTie,
        planned,
        later,
        tie,
        original,
        older,
      ]);
      final corrected = vaccination(notes: 'Corrected');
      await source.updateVaccination(corrected);
      expect(await source.getVaccinations('pet-1'), [
        plannedTie,
        planned,
        later,
        tie,
        corrected,
        older,
      ]);
      await source.updateVaccination(
        vaccination(
          id: 'planned',
          status: VaccinationStatus.planned,
          date: DateTime(2019, 1, 1),
        ),
      );
      expect((await source.getVaccinations('pet-1')).first.id, 'planned');
      expect(await source.getVaccinations('pet-2'), [other]);
    },
  );

  test(
    'round-trips complete records, normalizes text and clears optional fields',
    () async {
      await addVisit();
      await source.createVaccination(
        vaccination(
          vaccineName: "  O'Brien's vaccine  ",
          clinicName: ' Clinic ',
          veterinarianName: ' Dr. Smith ',
          notes: ' No reaction ',
          vetVisitId: 'visit-1',
        ),
      );
      expect(
        await source.getVaccinationById('pet-1', 'vaccination-1'),
        vaccination(
          vaccineName: "O'Brien's vaccine",
          clinicName: 'Clinic',
          veterinarianName: 'Dr. Smith',
          notes: 'No reaction',
          vetVisitId: 'visit-1',
        ),
      );
      await source.updateVaccination(
        vaccination(clinicName: ' ', veterinarianName: '\n', notes: ''),
      );
      expect(
        await source.getVaccinationById('pet-1', 'vaccination-1'),
        vaccination(),
      );
    },
  );

  test(
    'missing or wrong-pet records cannot be read, changed or deleted',
    () async {
      final original = vaccination();
      await source.createVaccination(original);
      for (final ids in [('pet-2', original.id), ('pet-1', 'missing')]) {
        await expectLater(
          source.getVaccinationById(ids.$1, ids.$2),
          throwsA(isA<LocalDataNotFoundException>()),
        );
        await expectLater(
          source.updateVaccination(
            vaccination(id: ids.$2, petId: ids.$1),
            nextDose: nextDose(),
          ),
          throwsA(isA<LocalDataNotFoundException>()),
        );
        await expectLater(
          source.deleteVaccination(ids.$1, ids.$2),
          throwsA(isA<LocalDataNotFoundException>()),
        );
      }
      expect(await source.getVaccinations('pet-1'), [original]);
      expect(await source.getVaccinations('pet-2'), isEmpty);
    },
  );

  test(
    'duplicate IDs and missing pets do not overwrite existing records',
    () async {
      final original = vaccination();
      await source.createVaccination(original);
      for (final invalid in [
        vaccination(notes: 'Overwrite'),
        vaccination(id: 'orphan', petId: 'missing'),
      ]) {
        await expectLater(
          source.createVaccination(invalid),
          throwsA(isA<LocalDataSourceException>()),
        );
      }
      expect(await source.getVaccinations('pet-1'), [original]);
    },
  );

  test(
    'links only existing visits belonging to the same pet on create and update',
    () async {
      await addVisit(petId: 'pet-2');
      final original = vaccination();
      await source.createVaccination(original);
      for (final visitId in ['visit-1', 'missing']) {
        await expectLater(
          source.createVaccination(
            vaccination(id: 'invalid', vetVisitId: visitId),
          ),
          throwsA(isA<LocalDataSourceException>()),
        );
        await expectLater(
          source.updateVaccination(vaccination(vetVisitId: visitId)),
          throwsA(isA<LocalDataSourceException>()),
        );
      }
      expect(await source.getVaccinations('pet-1'), [original]);
    },
  );

  test(
    'allows past and future plans but rejects future administration',
    () async {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      await source.createVaccination(
        vaccination(id: 'past-plan', status: VaccinationStatus.planned),
      );
      await source.createVaccination(
        vaccination(
          id: 'future-plan',
          status: VaccinationStatus.planned,
          date: tomorrow,
        ),
      );
      await expectLater(
        source.createVaccination(vaccination(date: tomorrow)),
        throwsA(isA<LocalDataSourceException>()),
      );
      await source.createVaccination(
        vaccination(date: DateTime(now.year, now.month, now.day, 23, 59)),
      );
      await expectLater(
        source.updateVaccination(vaccination(date: tomorrow)),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(
        (await source.getVaccinationById('pet-1', 'vaccination-1')).date,
        DateTime(now.year, now.month, now.day),
      );
    },
  );

  test(
    'creates an administration and an independent next plan together',
    () async {
      final original = vaccination();
      final next = nextDose();
      await source.createVaccination(original, nextDose: next);
      expect(await source.getVaccinations('pet-1'), [next, original]);
      await source.updateVaccination(
        vaccination(vaccineName: 'Corrected', notes: 'Changed'),
      );
      expect(await source.getVaccinationById('pet-1', next.id), next);
      await source.deleteVaccination('pet-1', original.id);
      expect(await source.getVaccinations('pet-1'), [next]);
    },
  );

  test(
    'rolls back the administration if inserting its next dose fails',
    () async {
      final next = nextDose();
      await source.createVaccination(next);
      await expectLater(
        source.createVaccination(vaccination(), nextDose: next),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getVaccinations('pet-1'), [next]);
    },
  );

  test(
    'marks a plan administered and creates its next dose atomically',
    () async {
      await source.createVaccination(
        vaccination(status: VaccinationStatus.planned),
      );
      final administered = vaccination(notes: 'Administered');
      final next = nextDose();
      await source.updateVaccination(administered, nextDose: next);
      expect(await source.getVaccinations('pet-1'), [next, administered]);
      await expectLater(
        source.updateVaccination(
          administered,
          nextDose: vaccination(
            id: 'duplicate-plan',
            status: VaccinationStatus.planned,
            date: next.date,
          ),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getVaccinations('pet-1'), [next, administered]);
    },
  );

  test(
    'restores the original plan when next-dose insertion fails on update',
    () async {
      final planned = vaccination(status: VaccinationStatus.planned);
      final next = nextDose();
      await source.createVaccination(planned);
      await source.createVaccination(next);
      await expectLater(
        source.updateVaccination(vaccination(), nextDose: next),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getVaccinations('pet-1'), [planned, next]);
    },
  );

  test(
    'rejects mismatched next doses without partially creating or updating',
    () async {
      final original = vaccination(status: VaccinationStatus.planned);
      await source.createVaccination(original);
      final invalidDoses = [
        vaccination(),
        vaccination(
          id: 'next',
          petId: 'pet-2',
          status: VaccinationStatus.planned,
          date: DateTime(2021),
        ),
        vaccination(
          id: 'next',
          vaccineName: 'Different',
          status: VaccinationStatus.planned,
          date: DateTime(2021),
        ),
        vaccination(
          id: 'next',
          status: VaccinationStatus.administered,
          date: DateTime(2021),
        ),
        vaccination(
          id: 'next',
          status: VaccinationStatus.planned,
          date: DateTime(2020, 1, 1),
        ),
        vaccination(
          id: 'next',
          status: VaccinationStatus.planned,
          date: DateTime.utc(2020, 1, 2, 23, 59),
        ),
      ];
      for (final next in invalidDoses) {
        await expectLater(
          source.createVaccination(vaccination(id: 'new'), nextDose: next),
          throwsA(isA<LocalDataSourceException>()),
        );
        await expectLater(
          source.updateVaccination(vaccination(), nextDose: next),
          throwsA(isA<LocalDataSourceException>()),
        );
        expect(await source.getVaccinations('pet-1'), [original]);
      }
      await expectLater(
        source.createVaccination(
          vaccination(id: 'new', status: VaccinationStatus.planned),
          nextDose: nextDose(),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      await expectLater(
        source.updateVaccination(original, nextDose: nextDose()),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getVaccinations('pet-1'), [original]);
    },
  );

  test(
    'planned records cannot carry a visit and the schema rejects invalid states',
    () async {
      await addVisit();
      await expectLater(
        source.createVaccination(
          vaccination(status: VaccinationStatus.planned, vetVisitId: 'visit-1'),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      for (final invalid in <Map<String, Object?>>[
        {'vaccine_name': '   '},
        {'status': 'unknown'},
        {'status': 'planned', 'vet_visit_id': 'visit-1'},
      ]) {
        await expectLater(
          db.insert(DatabaseTables.vaccinations, {
            ...vaccination().toJson(),
            ...invalid,
          }),
          throwsA(isA<DatabaseException>()),
        );
      }
      expect(await source.getVaccinations('pet-1'), isEmpty);
    },
  );

  test(
    'visit edits and deletion preserve copied vaccination details',
    () async {
      await addVisit();
      await source.createVaccination(
        vaccination(
          clinicName: 'Clinic',
          veterinarianName: 'Dr. Smith',
          notes: 'Keep',
          vetVisitId: 'visit-1',
        ),
      );
      await db.update(
        DatabaseTables.vetVisits,
        {'clinic_name': 'Changed clinic', 'veterinarian_name': 'Another vet'},
        where: 'id = ?',
        whereArgs: ['visit-1'],
      );
      expect(
        await source.getVaccinationById('pet-1', 'vaccination-1'),
        vaccination(
          clinicName: 'Clinic',
          veterinarianName: 'Dr. Smith',
          notes: 'Keep',
          vetVisitId: 'visit-1',
        ),
      );
      await db.delete(
        DatabaseTables.vetVisits,
        where: 'id = ?',
        whereArgs: ['visit-1'],
      );
      expect(
        await source.getVaccinationById('pet-1', 'vaccination-1'),
        vaccination(
          clinicName: 'Clinic',
          veterinarianName: 'Dr. Smith',
          notes: 'Keep',
        ),
      );
    },
  );

  test(
    'correcting an administration back to a plan keeps its ID and next dose',
    () async {
      await addVisit();
      final next = nextDose();
      await source.createVaccination(
        vaccination(vetVisitId: 'visit-1'),
        nextDose: next,
      );
      final corrected = vaccination(status: VaccinationStatus.planned);
      await source.updateVaccination(corrected);
      expect(await source.getVaccinations('pet-1'), [corrected, next]);
      expect(await db.query(DatabaseTables.vetVisits), hasLength(1));
    },
  );

  test('deleting a pet cascades without affecting another pet', () async {
    await addVisit();
    final other = vaccination(id: 'other', petId: 'pet-2');
    await source.createVaccination(
      vaccination(vetVisitId: 'visit-1'),
      nextDose: nextDose(),
    );
    await source.createVaccination(other);
    await db.delete(DatabaseTables.pets, where: 'id = ?', whereArgs: ['pet-1']);
    expect(await source.getVaccinations('pet-1'), isEmpty);
    expect(await source.getVaccinations('pet-2'), [other]);
  });

  test(
    'suggests saved names across pets and visits, filtering only veterinarians',
    () async {
      await addVisit(clinicName: ' alpha ', veterinarianName: ' dr. smith ');
      await addVisit(
        id: 'other-visit',
        petId: 'pet-2',
        clinicName: 'Beta',
        veterinarianName: 'Dr. Adams',
      );
      await source.createVaccination(
        vaccination(
          vaccineName: 'rabies',
          clinicName: 'ALPHA',
          veterinarianName: 'Dr. Smith',
        ),
      );
      await source.createVaccination(
        vaccination(
          id: 'newer',
          petId: 'pet-2',
          vaccineName: ' Rabies ',
          status: VaccinationStatus.planned,
          clinicName: 'Gamma',
          veterinarianName: 'Dr. Jones',
        ),
      );
      await source.createVaccination(
        vaccination(id: 'other-vaccine', vaccineName: 'Booster'),
      );
      await source.createVaccination(
        vaccination(id: 'no-clinic', veterinarianName: 'Dr. No Clinic'),
      );
      const all = VaccinationSuggestions(
        vaccineNames: ['Booster', 'Rabies'],
        clinicNames: ['ALPHA', 'Beta', 'Gamma'],
        veterinarianNames: [
          'Dr. Adams',
          'Dr. Jones',
          'Dr. No Clinic',
          'Dr. Smith',
        ],
      );
      expect(await source.getSuggestions(), all);
      expect(await source.getSuggestions(clinicName: '  '), all);
      expect(
        await source.getSuggestions(clinicName: ' aLpHa '),
        const VaccinationSuggestions(
          vaccineNames: ['Booster', 'Rabies'],
          clinicNames: ['ALPHA', 'Beta', 'Gamma'],
          veterinarianNames: ['Dr. Smith'],
        ),
      );
      expect(
        (await source.getSuggestions(clinicName: 'Al')).veterinarianNames,
        isEmpty,
      );
    },
  );

  test(
    'edits and deletions remove suggestions when the last source disappears',
    () async {
      await addVisit(clinicName: 'Old', veterinarianName: 'Dr. Old');
      await source.createVaccination(
        vaccination(clinicName: 'Old', veterinarianName: 'Dr. Old'),
      );
      await source.updateVaccination(
        vaccination(
          vaccineName: 'Booster',
          clinicName: 'New',
          veterinarianName: 'Dr. New',
        ),
      );
      expect((await source.getSuggestions()).vaccineNames, ['Booster']);
      expect((await source.getSuggestions()).clinicNames, ['New', 'Old']);
      await db.delete(
        DatabaseTables.vetVisits,
        where: 'id = ?',
        whereArgs: ['visit-1'],
      );
      expect((await source.getSuggestions()).clinicNames, ['New']);
      await source.deleteVaccination('pet-1', 'vaccination-1');
      expect(
        await source.getSuggestions(),
        const VaccinationSuggestions(
          vaccineNames: [],
          clinicNames: [],
          veterinarianNames: [],
        ),
      );
    },
  );

  test(
    'hostile identifiers and clinic names cannot broaden SQL scope',
    () async {
      const injected = "' OR 1=1 --";
      await source.createVaccination(
        vaccination(clinicName: injected, veterinarianName: 'Dr. Smith'),
      );
      expect(await source.getVaccinations(injected), isEmpty);
      for (final ids in [(injected, 'vaccination-1'), ('pet-1', injected)]) {
        await expectLater(
          source.getVaccinationById(ids.$1, ids.$2),
          throwsA(isA<LocalDataNotFoundException>()),
        );
        await expectLater(
          source.updateVaccination(vaccination(petId: ids.$1, id: ids.$2)),
          throwsA(isA<LocalDataNotFoundException>()),
        );
        await expectLater(
          source.deleteVaccination(ids.$1, ids.$2),
          throwsA(isA<LocalDataNotFoundException>()),
        );
      }
      await expectLater(
        source.updateVaccination(vaccination(vetVisitId: injected)),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(
        (await source.getVaccinations('pet-1')).single.clinicName,
        injected,
      );
      expect(
        (await source.getSuggestions(clinicName: injected)).veterinarianNames,
        ['Dr. Smith'],
      );
    },
  );

  for (final operation in [
    'list',
    'read',
    'create',
    'update',
    'delete',
    'suggestions',
  ]) {
    test('maps SQLite errors for $operation', () async {
      await db.execute('DROP TABLE ${DatabaseTables.vaccinations}');
      final result = switch (operation) {
        'list' => source.getVaccinations('pet-1'),
        'read' => source.getVaccinationById('pet-1', 'vaccination-1'),
        'create' => source.createVaccination(vaccination()),
        'update' => source.updateVaccination(vaccination()),
        'delete' => source.deleteVaccination('pet-1', 'vaccination-1'),
        _ => source.getSuggestions(),
      };
      await expectLater(result, throwsA(isA<LocalDataSourceException>()));
    });
  }
}
