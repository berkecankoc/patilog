import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/vaccination/data/data_sources/vaccination_local_data_source.dart';
import 'package:petlytics/features/vaccination/data/models/vaccination_model.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vet_visit/data/data_sources/vet_visit_local_data_source.dart';
import 'package:petlytics/features/vet_visit/data/models/vet_visit_model.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late Database db;
  late VetVisitLocalDataSourceImpl source;

  VetVisitModel visit({
    String id = 'visit-1',
    String petId = 'pet-1',
    int day = 15,
    String reason = 'Checkup',
    String? clinicName,
    String? veterinarianName,
    String? diagnosis,
    String? notes,
    int? costMinorUnits,
    VetVisitCurrency? currency,
  }) => VetVisitModel(
    id: id,
    petId: petId,
    visitedOn: DateTime(2026, 10, day),
    reason: reason,
    clinicName: clinicName,
    veterinarianName: veterinarianName,
    diagnosis: diagnosis,
    notes: notes,
    costMinorUnits: costMinorUnits,
    currency: currency,
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vet-visit-source-');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await openAppDatabase();
    source = VetVisitLocalDataSourceImpl(db);
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

  test(
    'returns empty visits and suggestions before any visit is saved',
    () async {
      expect(await source.getVetVisits('pet-1'), isEmpty);
      expect(await source.getAllVetVisits(), isEmpty);
      expect(
        await source.getSuggestions(),
        const VetVisitSuggestions(clinicNames: [], veterinarianNames: []),
      );
    },
  );

  test(
    'all-pet visits retain date and insertion order after content edits',
    () async {
      final older = visit(id: 'older', day: 13);
      final other = visit(id: 'other', petId: 'pet-2');
      final latest = visit(id: 'latest');
      for (final entry in [older, other, latest]) {
        await source.createVetVisit(entry);
      }
      expect(await source.getAllVetVisits(), [latest, other, older]);
      final updated = visit(id: 'other', petId: 'pet-2', reason: 'Updated');
      await source.updateVetVisit(updated);
      expect(await source.getAllVetVisits(), [latest, updated, older]);
      expect(await source.getVetVisits('pet-1'), [latest, older]);
      expect(await source.getVetVisits('pet-2'), [updated]);
    },
  );

  test('all-pet visits reflect record and pet deletions', () async {
    await source.createVetVisit(visit());
    await source.createVetVisit(visit(id: 'other', petId: 'pet-2'));
    await source.deleteVetVisit('pet-1', 'visit-1');
    expect((await source.getAllVetVisits()).map((v) => v.id), ['other']);
    await db.delete(DatabaseTables.pets, where: 'id = ?', whereArgs: ['pet-2']);
    expect(await source.getAllVetVisits(), isEmpty);
  });

  for (final updating in [false, true]) {
    test(
      'rejects a future visit during ${updating ? 'update' : 'create'}',
      () async {
        final original = visit();
        if (updating) await source.createVetVisit(original);
        final now = DateTime.now();
        final future = VetVisitModel(
          id: original.id,
          petId: original.petId,
          visitedOn: DateTime(now.year, now.month, now.day + 1),
          reason: 'Future',
        );
        await expectLater(
          updating
              ? source.updateVetVisit(future)
              : source.createVetVisit(future),
          throwsA(isA<LocalDataSourceException>()),
        );
        expect(
          await source.getVetVisits(original.petId),
          updating ? [original] : isEmpty,
        );
      },
    );
  }

  test(
    'date correction changes only linked vaccination dates and preserves row order',
    () async {
      final vaccines = VaccinationLocalDataSourceImpl(db);
      await source.createVetVisit(visit());
      await source.createVetVisit(visit(id: 'other-visit'));
      await source.createVetVisit(visit(id: 'other-pet-visit', petId: 'pet-2'));
      final now = DateTime.now();
      final entries = [
        for (final id in ['linked-a', 'linked-b'])
          VaccinationModel(
            id: id,
            petId: 'pet-1',
            vaccineName: id,
            status: VaccinationStatus.administered,
            date: visit().visitedOn,
            vetVisitId: 'visit-1',
            clinicName: 'Original clinic',
            veterinarianName: 'Original vet',
            notes: 'Original note',
          ),
        VaccinationModel(
          id: 'unlinked',
          petId: 'pet-1',
          vaccineName: 'Unlinked',
          status: VaccinationStatus.administered,
          date: visit().visitedOn,
        ),
        VaccinationModel(
          id: 'other-link',
          petId: 'pet-1',
          vaccineName: 'Other link',
          status: VaccinationStatus.administered,
          date: visit().visitedOn,
          vetVisitId: 'other-visit',
        ),
        VaccinationModel(
          id: 'other-pet',
          petId: 'pet-2',
          vaccineName: 'Other pet',
          status: VaccinationStatus.administered,
          date: visit().visitedOn,
          vetVisitId: 'other-pet-visit',
        ),
        VaccinationModel(
          id: 'next-dose',
          petId: 'pet-1',
          vaccineName: 'linked-a',
          status: VaccinationStatus.planned,
          date: DateTime(now.year, now.month, now.day + 1),
        ),
      ];
      for (final entry in entries) {
        await vaccines.createVaccination(entry);
      }
      final before = await db.rawQuery(
        'SELECT id, rowid AS insertion_order FROM vaccinations ORDER BY rowid',
      );
      await source.updateVetVisit(
        visit(
          day: 16,
          clinicName: 'Changed visit clinic',
          veterinarianName: 'Changed visit vet',
        ),
      );
      for (final entry in entries) {
        final stored = await vaccines.getVaccinationById(entry.petId, entry.id);
        expect(stored.toJson(), {
          ...entry.toJson(),
          if (entry.vetVisitId == 'visit-1') 'date': '2026-10-16',
        });
      }
      expect(
        await db.rawQuery(
          'SELECT id, rowid AS insertion_order FROM vaccinations ORDER BY rowid',
        ),
        before,
      );
      expect(
        (await vaccines.getVaccinations(
          'pet-1',
          vetVisitId: 'visit-1',
        )).map((v) => v.id),
        ['linked-b', 'linked-a'],
      );
    },
  );

  test(
    'failed linked date correction rolls back visit and every vaccination',
    () async {
      await source.createVetVisit(visit());
      final vaccines = VaccinationLocalDataSourceImpl(db);
      for (final id in ['linked-a', 'linked-b']) {
        await vaccines.createVaccination(
          VaccinationModel(
            id: id,
            petId: 'pet-1',
            vaccineName: id,
            status: VaccinationStatus.administered,
            date: visit().visitedOn,
            vetVisitId: 'visit-1',
          ),
        );
      }
      final before = await vaccines.getVaccinations('pet-1');
      await db.execute(
        "CREATE TRIGGER reject_linked_date BEFORE UPDATE OF date ON vaccinations WHEN OLD.id = 'linked-b' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        source.updateVetVisit(visit(day: 16, reason: 'Changed')),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getVetVisitById('pet-1', 'visit-1'), visit());
      expect(await vaccines.getVaccinations('pet-1'), before);
      await source.updateVetVisit(visit(reason: 'Reason only'));
      expect(
        (await source.getVetVisitById('pet-1', 'visit-1')).reason,
        'Reason only',
      );
      expect(await vaccines.getVaccinations('pet-1'), before);
    },
  );

  test('lists only this pet by calendar date then insertion order', () async {
    final original = visit();
    final older = visit(id: 'older', day: 14);
    final newerTie = visit(id: 'tie');
    final otherPet = visit(id: 'other', petId: 'pet-2', day: 16);
    for (final entry in [original, otherPet, older, newerTie]) {
      await source.createVetVisit(entry);
    }
    expect(await source.getVetVisits('pet-1'), [newerTie, original, older]);
    expect(await source.getVetVisits('pet-2'), [otherPet]);
  });

  test('reads a complete saved visit by pet and visit IDs', () async {
    final entry = visit(
      clinicName: 'Clinic',
      veterinarianName: 'Dr. Smith',
      diagnosis: 'Healthy',
      notes: 'Routine visit',
      costMinorUnits: 125050,
      currency: VetVisitCurrency.turkishLira,
    );
    await source.createVetVisit(entry);
    expect(await source.getVetVisitById(entry.petId, entry.id), entry);
  });

  test(
    'edits all fields and clears optional data without reordering ties',
    () async {
      await source.createVetVisit(visit(clinicName: 'Clinic'));
      final later = visit(id: 'later');
      await source.createVetVisit(later);
      final updated = visit(
        reason: 'Follow-up',
        veterinarianName: 'Dr. Smith',
        diagnosis: 'Healthy',
        notes: 'Review',
        costMinorUnits: 0,
        currency: VetVisitCurrency.euro,
      );
      await source.updateVetVisit(updated);
      expect(await source.getVetVisits('pet-1'), [later, updated]);
      final changedDate = visit(day: 16);
      await source.updateVetVisit(changedDate);
      expect(await source.getVetVisits('pet-1'), [changedDate, later]);
    },
  );

  test('normalizes saved text and treats punctuation as data', () async {
    await source.createVetVisit(
      visit(
        reason: "  O'Brien's checkup  ",
        clinicName: '  Clinic  ',
        veterinarianName: '  Dr. Smith  ',
        diagnosis: ' \n ',
        notes: ' ',
      ),
    );
    expect(
      await source.getVetVisitById('pet-1', 'visit-1'),
      visit(
        reason: "O'Brien's checkup",
        clinicName: 'Clinic',
        veterinarianName: 'Dr. Smith',
      ),
    );
  });

  test(
    'missing or wrong-pet IDs cannot read, update or delete a visit',
    () async {
      final entry = visit();
      await source.createVetVisit(entry);
      for (final ids in [('pet-2', entry.id), ('pet-1', 'missing')]) {
        await expectLater(
          source.getVetVisitById(ids.$1, ids.$2),
          throwsA(isA<LocalDataNotFoundException>()),
        );
        await expectLater(
          source.updateVetVisit(visit(id: ids.$2, petId: ids.$1)),
          throwsA(isA<LocalDataNotFoundException>()),
        );
        await expectLater(
          source.deleteVetVisit(ids.$1, ids.$2),
          throwsA(isA<LocalDataNotFoundException>()),
        );
      }
      expect(await source.getVetVisits('pet-1'), [entry]);
      expect(await source.getVetVisits('pet-2'), isEmpty);
    },
  );

  test(
    'duplicate IDs and missing pet references cannot overwrite data',
    () async {
      final entry = visit();
      await source.createVetVisit(entry);
      for (final invalid in [
        visit(reason: 'Overwrite'),
        visit(petId: 'missing'),
      ]) {
        await expectLater(
          source.createVetVisit(invalid),
          throwsA(isA<LocalDataSourceException>()),
        );
      }
      expect(await source.getVetVisits('pet-1'), [entry]);
      await expectLater(
        source.createVetVisit(visit(id: 'orphan', petId: 'missing')),
        throwsA(isA<LocalDataSourceException>()),
      );
    },
  );

  test(
    'deletes only the selected visit and cascades when its pet is deleted',
    () async {
      final other = visit(id: 'other', petId: 'pet-2');
      await source.createVetVisit(visit());
      await source.createVetVisit(visit(id: 'keep'));
      await source.createVetVisit(other);
      await source.deleteVetVisit('pet-1', 'visit-1');
      expect((await source.getVetVisits('pet-1')).single.id, 'keep');
      await db.delete('pets', where: 'id = ?', whereArgs: ['pet-1']);
      expect(await source.getVetVisits('pet-1'), isEmpty);
      expect(await source.getVetVisits('pet-2'), [other]);
    },
  );

  test(
    'schema rejects blank reasons and inconsistent or fractional costs',
    () async {
      for (final invalid in <Map<String, Object?>>[
        {'reason': '   '},
        {'cost_minor_units': -1, 'currency': 'TRY'},
        {'cost_minor_units': 100, 'currency': null},
        {'cost_minor_units': null, 'currency': 'USD'},
        {'cost_minor_units': 100, 'currency': 'GBP'},
        {'cost_minor_units': 12.5, 'currency': 'EUR'},
      ]) {
        await expectLater(
          db.insert(DatabaseTables.vetVisits, {
            ...visit().toJson(),
            ...invalid,
          }),
          throwsA(isA<DatabaseException>()),
        );
      }
      expect(await source.getVetVisits('pet-1'), isEmpty);
    },
  );

  test(
    'suggests names across pets, deduplicating and keeping latest spelling',
    () async {
      await source.createVetVisit(
        visit(clinicName: ' alpha ', veterinarianName: ' dr. smith '),
      );
      await source.createVetVisit(
        visit(id: 'beta', clinicName: 'Beta', veterinarianName: 'Dr. Adams'),
      );
      await source.createVetVisit(
        visit(
          id: 'latest',
          petId: 'pet-2',
          day: 14,
          clinicName: 'ALPHA',
          veterinarianName: 'Dr. Smith',
        ),
      );
      await source.createVetVisit(visit(id: 'blank', clinicName: ' '));
      await source.createVetVisit(
        visit(id: 'no-clinic', veterinarianName: 'Dr. Jones'),
      );
      expect(
        await source.getSuggestions(),
        const VetVisitSuggestions(
          clinicNames: ['ALPHA', 'Beta'],
          veterinarianNames: ['Dr. Adams', 'Dr. Jones', 'Dr. Smith'],
        ),
      );
      expect(
        await source.getSuggestions(clinicName: '  '),
        await source.getSuggestions(),
      );
      expect(
        await source.getSuggestions(clinicName: '  aLpHa  '),
        const VetVisitSuggestions(
          clinicNames: ['ALPHA', 'Beta'],
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
    'updates and deletes suggestion sources without a separate saved catalog',
    () async {
      await source.createVetVisit(
        visit(clinicName: 'Old', veterinarianName: 'Dr. A'),
      );
      await source.createVetVisit(visit(id: 'other', clinicName: 'Old'));
      await source.updateVetVisit(
        visit(clinicName: 'New', veterinarianName: 'Dr. B'),
      );
      expect((await source.getSuggestions()).clinicNames, ['New', 'Old']);
      expect((await source.getSuggestions()).veterinarianNames, ['Dr. B']);
      await source.deleteVetVisit('pet-1', 'other');
      expect((await source.getSuggestions()).clinicNames, ['New']);
      await source.deleteVetVisit('pet-1', 'visit-1');
      expect(
        await source.getSuggestions(),
        const VetVisitSuggestions(clinicNames: [], veterinarianNames: []),
      );
    },
  );

  test(
    'both features share names, clinic filters and removal of the last source',
    () async {
      final vaccinations = VaccinationLocalDataSourceImpl(db);
      await source.createVetVisit(
        visit(clinicName: ' Clinic   A ', veterinarianName: 'Dr. Smith'),
      );
      await vaccinations.createVaccination(
        VaccinationModel(
          id: 'vaccination-1',
          petId: 'pet-2',
          vaccineName: 'Rabies',
          status: VaccinationStatus.administered,
          date: DateTime(2020),
          clinicName: 'clinic a',
          veterinarianName: ' Dr.  Jones ',
        ),
      );
      await vaccinations.createVaccination(
        VaccinationModel(
          id: 'vaccination-2',
          petId: 'pet-1',
          vaccineName: 'Booster',
          status: VaccinationStatus.administered,
          date: DateTime(2020),
          clinicName: 'Clinic B',
          veterinarianName: 'Dr. Brown',
        ),
      );
      for (final clinic in [null, ' CLINIC   A ', 'Clinic B', "' OR 1=1 --"]) {
        final visits = await source.getSuggestions(clinicName: clinic);
        final vaccines = await vaccinations.getSuggestions(clinicName: clinic);
        expect(visits.clinicNames, vaccines.clinicNames);
        expect(visits.veterinarianNames, vaccines.veterinarianNames);
      }
      expect(
        await source.getSuggestions(clinicName: ' Clinic A '),
        const VetVisitSuggestions(
          clinicNames: ['clinic a', 'Clinic B'],
          veterinarianNames: ['Dr. Jones', 'Dr. Smith'],
        ),
      );
      await vaccinations.deleteVaccination('pet-1', 'vaccination-2');
      expect((await source.getSuggestions()).clinicNames, ['clinic a']);
      await vaccinations.deleteVaccination('pet-2', 'vaccination-1');
      expect((await source.getSuggestions()).clinicNames, ['Clinic A']);
      expect((await source.getSuggestions()).veterinarianNames, ['Dr. Smith']);
      await source.deleteVetVisit('pet-1', 'visit-1');
      expect((await vaccinations.getSuggestions()).clinicNames, isEmpty);
      expect((await vaccinations.getSuggestions()).veterinarianNames, isEmpty);
    },
  );

  test('identifier and clinic strings cannot change SQL query scope', () async {
    const injected = "' OR 1=1 --";
    final entry = visit(clinicName: injected, veterinarianName: 'Dr. Smith');
    await source.createVetVisit(entry);
    expect(await source.getVetVisits(injected), isEmpty);
    for (final ids in [(injected, entry.id), (entry.petId, injected)]) {
      await expectLater(
        source.getVetVisitById(ids.$1, ids.$2),
        throwsA(isA<LocalDataNotFoundException>()),
      );
      await expectLater(
        source.updateVetVisit(visit(petId: ids.$1, id: ids.$2)),
        throwsA(isA<LocalDataNotFoundException>()),
      );
      await expectLater(
        source.deleteVetVisit(ids.$1, ids.$2),
        throwsA(isA<LocalDataNotFoundException>()),
      );
    }
    expect(await source.getVetVisits('pet-1'), [entry]);
    expect(
      (await source.getSuggestions(clinicName: injected)).veterinarianNames,
      ['Dr. Smith'],
    );
  });

  for (final operation in [
    'list',
    'all visits',
    'read',
    'create',
    'update',
    'delete',
    'suggestions',
  ]) {
    test('maps SQLite errors for $operation', () async {
      await db.execute('DROP TABLE ${DatabaseTables.vetVisits}');
      final result = switch (operation) {
        'list' => source.getVetVisits('pet-1'),
        'all visits' => source.getAllVetVisits(),
        'read' => source.getVetVisitById('pet-1', 'visit-1'),
        'create' => source.createVetVisit(visit()),
        'update' => source.updateVetVisit(visit()),
        'delete' => source.deleteVetVisit('pet-1', 'visit-1'),
        _ => source.getSuggestions(),
      };
      await expectLater(result, throwsA(isA<LocalDataSourceException>()));
    });
  }
}
