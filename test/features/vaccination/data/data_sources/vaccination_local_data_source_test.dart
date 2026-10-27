import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/vaccination/data/data_sources/vaccination_local_data_source.dart';
import 'package:petlytics/features/vaccination/data/models/vaccination_model.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late Database db;
  late VaccinationLocalDataSourceImpl source;

  DateTime day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset);
  }

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
    VaccinationReminderSettings? reminderSettings,
  }) => VaccinationModel(
    id: id,
    petId: petId,
    vaccineName: vaccineName,
    status: status,
    date:
        date ??
        (status == VaccinationStatus.planned ? day(1) : DateTime(2020, 1, 2)),
    clinicName: clinicName,
    veterinarianName: veterinarianName,
    notes: notes,
    vetVisitId: vetVisitId,
    reminderSettings: reminderSettings,
  );

  VaccinationModel nextDose() => vaccination(
    id: 'next-dose',
    status: VaccinationStatus.planned,
    date: day(2),
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
    expect(await source.getAllVaccinations(), isEmpty);
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
    'persists and clears per-record settings without affecting peers or order',
    () async {
      final custom = VaccinationReminderSettings.custom(
        VaccinationReminderSchedule(daysBefore: [5, 0], minuteOfDay: 600),
      );
      final original = vaccination(reminderSettings: custom);
      final tied = vaccination(
        id: 'tied',
        reminderSettings: const VaccinationReminderSettings.off(),
      );
      final other = vaccination(
        id: 'other',
        petId: 'pet-2',
        reminderSettings: custom,
      );
      for (final record in [original, tied, other]) {
        await source.createVaccination(record);
      }
      await db.close();
      db = await openAppDatabase();
      source = VaccinationLocalDataSourceImpl(db);
      expect(await source.getVaccinations('pet-1'), [tied, original]);
      expect(await source.getVaccinations('pet-2'), [other]);
      final off = vaccination(
        reminderSettings: const VaccinationReminderSettings.off(),
      );
      await source.updateVaccination(off);
      expect(await source.getVaccinations('pet-1'), [tied, off]);
      await source.updateVaccination(vaccination());
      expect(await source.getVaccinations('pet-1'), [tied, vaccination()]);
      expect(await source.getVaccinations('pet-2'), [other]);
      expect(
        (await db.query(
          DatabaseTables.vaccinations,
          where: 'id = ?',
          whereArgs: ['vaccination-1'],
        )).single['reminder_settings'],
        isNull,
      );
    },
  );

  test('invalid reminder schedules reject the complete atomic write', () async {
    for (final schedule in [
      VaccinationReminderSchedule(daysBefore: []),
      VaccinationReminderSchedule(daysBefore: [-1]),
      VaccinationReminderSchedule(daysBefore: [1, 1]),
      VaccinationReminderSchedule(minuteOfDay: -1),
      VaccinationReminderSchedule(minuteOfDay: 1440),
    ]) {
      await expectLater(
        source.createVaccination(
          vaccination(
            reminderSettings: VaccinationReminderSettings.custom(schedule),
          ),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
    }
    expect(await source.getVaccinations('pet-1'), isEmpty);
    final original = vaccination(
      status: VaccinationStatus.planned,
      reminderSettings: const VaccinationReminderSettings.off(),
    );
    await source.createVaccination(original);
    final invalidNext = vaccination(
      id: 'next',
      status: VaccinationStatus.planned,
      date: day(2),
      reminderSettings: VaccinationReminderSettings.custom(
        VaccinationReminderSchedule(daysBefore: [1, 1]),
      ),
    );
    await expectLater(
      source.updateVaccination(vaccination(), nextDose: invalidNext),
      throwsA(isA<LocalDataSourceException>()),
    );
    expect(await source.getVaccinations('pet-1'), [original]);
    await expectLater(
      source.updateVaccination(
        vaccination(
          notes: 'Do not keep',
          reminderSettings: invalidNext.reminderSettings,
        ),
      ),
      throwsA(isA<LocalDataSourceException>()),
    );
    expect(await source.getVaccinations('pet-1'), [original]);
    await expectLater(
      source.createVaccination(vaccination(id: 'new'), nextDose: invalidNext),
      throwsA(isA<LocalDataSourceException>()),
    );
    expect(await source.getVaccinations('pet-1'), [original]);
  });

  test(
    'a failed next-dose insert rolls back record details and reminder settings',
    () async {
      final original = vaccination(
        status: VaccinationStatus.planned,
        reminderSettings: const VaccinationReminderSettings.off(),
      );
      final next = nextDose();
      await source.createVaccination(original);
      await source.createVaccination(next);
      await expectLater(
        source.updateVaccination(
          vaccination(
            notes: 'Do not keep',
            reminderSettings: VaccinationReminderSettings.custom(
              VaccinationReminderSchedule(),
            ),
          ),
          nextDose: next,
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getVaccinations('pet-1'), [original, next]);
    },
  );

  test(
    'invalid stored settings produce a source error for scoped and global reads',
    () async {
      await source.createVaccination(vaccination());
      await db.update(DatabaseTables.vaccinations, {
        'reminder_settings': '{"mode":"custom"}',
      });
      for (final read in <Future<Object> Function()>[
        () => source.getAllVaccinations(),
        () => source.getVaccinations('pet-1'),
        () => source.getVaccinationById('pet-1', 'vaccination-1'),
      ]) {
        await expectLater(read(), throwsA(isA<LocalDataSourceException>()));
      }
    },
  );

  for (final updating in [false, true]) {
    test(
      'linked ${updating ? 'update' : 'create'} rejects a different calendar day',
      () async {
        await addVisit();
        final original = vaccination(vetVisitId: 'visit-1', notes: 'Original');
        if (updating) await source.createVaccination(original);
        final mismatch = vaccination(
          vetVisitId: 'visit-1',
          date: DateTime(2020, 1, 3),
          notes: 'Changed',
        );
        await expectLater(
          updating
              ? source.updateVaccination(mismatch)
              : source.createVaccination(mismatch),
          throwsA(isA<LocalDataSourceException>()),
        );
        expect(
          await source.getVaccinations('pet-1'),
          updating ? [original] : isEmpty,
        );
      },
    );
  }

  test(
    'linked dates compare calendar components without timezone conversion',
    () async {
      await addVisit();
      await source.createVaccination(
        vaccination(
          vetVisitId: 'visit-1',
          date: DateTime.utc(2020, 1, 2, 23, 59),
        ),
      );
      expect(
        (await source.getVaccinationById('pet-1', 'vaccination-1')).date,
        DateTime(2020, 1, 2),
      );
    },
  );

  test(
    'linked reads match pet and visit, retaining order and live links',
    () async {
      await addVisit();
      await addVisit(id: 'visit-2');
      await addVisit(id: 'other-visit', petId: 'pet-2');
      final first = vaccination(vetVisitId: 'visit-1');
      final tie = vaccination(id: 'tie', vetVisitId: 'visit-1');
      for (final value in [
        first,
        tie,
        vaccination(id: 'other-link', vetVisitId: 'visit-2'),
        vaccination(id: 'unlinked'),
        vaccination(id: 'other-pet', petId: 'pet-2', vetVisitId: 'other-visit'),
      ]) {
        await source.createVaccination(value);
      }
      expect(await source.getVaccinations('pet-1', vetVisitId: 'visit-1'), [
        tie,
        first,
      ]);
      expect(
        await source.getVaccinations('pet-2', vetVisitId: 'visit-1'),
        isEmpty,
      );
      expect(
        await source.getVaccinations('pet-1', vetVisitId: "visit-1' OR 1=1 --"),
        isEmpty,
      );
      await source.updateVaccination(
        vaccination(id: 'tie', vetVisitId: 'visit-2'),
      );
      expect(await source.getVaccinations('pet-1', vetVisitId: 'visit-1'), [
        first,
      ]);
      await db.delete(
        DatabaseTables.vetVisits,
        where: 'id = ?',
        whereArgs: ['visit-1'],
      );
      expect(
        await source.getVaccinations('pet-1', vetVisitId: 'visit-1'),
        isEmpty,
      );
      expect(
        (await source.getVaccinationById('pet-1', first.id)).vetVisitId,
        isNull,
      );
    },
  );

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
          date: day(0),
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
    'allows only current or future plans and rejects future administration',
    () async {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      await expectLater(
        source.createVaccination(
          vaccination(status: VaccinationStatus.planned, date: day(-1)),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      await source.createVaccination(
        vaccination(
          id: 'today-plan',
          status: VaccinationStatus.planned,
          date: day(0),
        ),
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
    'overdue plans remain readable but must be rescheduled when edited',
    () async {
      final overdue = vaccination(
        status: VaccinationStatus.planned,
        date: day(-1),
      );
      // Simulate a plan that has naturally become overdue since it was saved.
      await db.insert(DatabaseTables.vaccinations, overdue.toJson());
      expect(await source.getVaccinationById('pet-1', overdue.id), overdue);
      await expectLater(
        source.updateVaccination(
          vaccination(
            status: VaccinationStatus.planned,
            date: day(-1),
            notes: 'Changed',
          ),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getVaccinationById('pet-1', overdue.id), overdue);
      final rescheduled = vaccination(
        status: VaccinationStatus.planned,
        date: day(0),
      );
      await source.updateVaccination(rescheduled);
      expect(await source.getVaccinationById('pet-1', overdue.id), rescheduled);
    },
  );

  test(
    'a historical administration cannot create a past next-dose plan',
    () async {
      await expectLater(
        source.createVaccination(
          vaccination(),
          nextDose: vaccination(
            id: 'next',
            status: VaccinationStatus.planned,
            date: day(-1),
          ),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getVaccinations('pet-1'), isEmpty);
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
          date: day(2),
        ),
        vaccination(
          id: 'next',
          vaccineName: 'Different',
          status: VaccinationStatus.planned,
          date: day(2),
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

  test(
    'all-pet vaccinations retain planned/history and insertion order',
    () async {
      final later = vaccination(
        id: 'later',
        petId: 'pet-2',
        status: VaccinationStatus.planned,
        date: day(2),
      );
      final planned = vaccination(
        id: 'planned',
        status: VaccinationStatus.planned,
        date: day(1),
      );
      final tied = vaccination(
        id: 'tied',
        petId: 'pet-2',
        status: VaccinationStatus.planned,
        date: day(1),
      );
      final recent = vaccination(id: 'recent', petId: 'pet-2', date: day(0));
      final older = vaccination(id: 'older', date: day(-2));
      for (final entry in [older, recent, later, planned, tied]) {
        await source.createVaccination(entry);
      }
      expect(await source.getAllVaccinations(), [
        tied,
        planned,
        later,
        recent,
        older,
      ]);
      final updated = vaccination(
        id: 'planned',
        status: VaccinationStatus.planned,
        date: day(1),
        notes: 'Updated',
      );
      await source.updateVaccination(updated);
      expect(await source.getAllVaccinations(), [
        tied,
        updated,
        later,
        recent,
        older,
      ]);
      expect(await source.getVaccinations('pet-1'), [updated, older]);
      expect(await source.getVaccinations('pet-2'), [tied, later, recent]);
    },
  );

  test(
    'all-pet vaccinations include overdue plans and omit deleted records',
    () async {
      final overdue = vaccination(
        id: 'overdue',
        status: VaccinationStatus.planned,
        date: day(-1),
      );
      // A once-valid plan becomes overdue as the calendar advances.
      await db.insert(DatabaseTables.vaccinations, overdue.toJson());
      await source.createVaccination(vaccination(id: 'other', petId: 'pet-2'));
      expect((await source.getAllVaccinations()).map((v) => v.id), [
        'overdue',
        'other',
      ]);
      await source.deleteVaccination('pet-1', 'overdue');
      await db.delete(
        DatabaseTables.pets,
        where: 'id = ?',
        whereArgs: ['pet-2'],
      );
      expect(await source.getAllVaccinations(), isEmpty);
    },
  );

  for (final operation in [
    'list',
    'all vaccinations',
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
        'all vaccinations' => source.getAllVaccinations(),
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
