import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/medication/data/data_sources/medication_local_data_source.dart';
import 'package:petlytics/features/medication/data/models/medication_dose_log_model.dart';
import 'package:petlytics/features/medication/data/models/medication_model.dart';
import 'package:petlytics/features/medication/data/models/medication_model_values.dart';
import 'package:petlytics/features/medication/data/models/medication_period_model.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/vaccination/data/data_sources/vaccination_local_data_source.dart';
import 'package:petlytics/features/vet_visit/data/data_sources/vet_visit_local_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late Database db;
  late MedicationLocalDataSourceImpl source;
  late DateTime clock;
  DateTime day(int offset) => DateTime(2026, 10, 20 + offset);

  MedicationPeriodModel period({
    String id = 'period-1',
    String medicationId = 'med-1',
    DateTime? start,
    DateTime? end,
    int interval = 1,
    List<int> times = const [480, 1200],
    String? dosage,
    String? clinic,
    String? vet,
    String? notes,
    String? visitId,
  }) => MedicationPeriodModel(
    id: id,
    medicationId: medicationId,
    startDate: start ?? day(-4),
    endDate: end,
    intervalDays: interval,
    doseTimes: times,
    dosageInstructions: dosage,
    clinicName: clinic,
    veterinarianName: vet,
    notes: notes,
    vetVisitId: visitId,
  );

  MedicationModel medication({
    String id = 'med-1',
    String petId = 'pet-1',
    String name = 'Medicine',
    List<MedicationPeriodModel>? periods,
  }) => MedicationModel(
    id: id,
    petId: petId,
    name: name,
    periods: periods ?? [period(medicationId: id)],
  );

  MedicationDoseLogModel log({
    String periodId = 'period-1',
    DateTime? date,
    int minute = 480,
    MedicationDoseStatus status = MedicationDoseStatus.given,
    DateTime? givenAt,
  }) => MedicationDoseLogModel(
    periodId: periodId,
    scheduledDate: date ?? day(0),
    scheduledMinute: minute,
    status: status,
    givenAt: status == MedicationDoseStatus.given ? givenAt ?? clock : givenAt,
  );

  Future<List<MedicationDoseLogModel>> logs({
    String petId = 'pet-1',
    String? medicationId,
  }) => source.getDoseLogs(
    petId,
    medicationId: medicationId,
    fromDate: day(-20),
    toDate: day(20),
  );

  Future<void> visit(String id, String petId) async {
    await db.insert(DatabaseTables.vetVisits, {
      'id': id,
      'pet_id': petId,
      'visited_on': '2026-10-01',
      'reason': 'Checkup',
    });
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('medication-data-');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await openAppDatabase();
    clock = DateTime(2026, 10, 20, 15, 30);
    source = MedicationLocalDataSourceImpl(db, now: () => clock);
    for (final pet in ['pet-1', 'pet-2']) {
      await db.insert(DatabaseTables.pets, {
        'id': pet,
        'name': pet,
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
    'period lock checks only owned results, including skipped and cleared doses',
    () async {
      await source.createMedication(medication());
      await source.createMedication(
        medication(
          id: 'med-2',
          periods: [period(id: 'period-2', medicationId: 'med-2')],
        ),
      );
      expect(await source.hasDoseLogs('pet-1', 'med-1', 'period-1'), false);
      await source.saveDoseLog(
        'pet-1',
        'med-1',
        log(status: MedicationDoseStatus.skipped),
      );
      expect(await source.hasDoseLogs('pet-1', 'med-1', 'period-1'), true);
      for (final key in [
        ('pet-2', 'med-1', 'period-1'),
        ('pet-1', 'missing', 'period-1'),
        ('pet-1', 'med-2', 'period-1'),
        ('pet-1', 'med-1', 'missing'),
      ]) {
        await expectLater(
          source.hasDoseLogs(key.$1, key.$2, key.$3),
          throwsA(isA<LocalDataNotFoundException>()),
        );
      }
      await source.clearDoseLog(
        'pet-1',
        'med-1',
        periodId: 'period-1',
        scheduledDate: day(0),
        scheduledMinute: 480,
      );
      expect(await source.hasDoseLogs('pet-1', 'med-1', 'period-1'), false);
      await source.saveDoseLog('pet-1', 'med-1', log());
      expect(await source.hasDoseLogs('pet-1', 'med-1', 'period-1'), true);
    },
  );

  test(
    'all computed occurrences agree with transactional write validation',
    () async {
      await source.createMedication(medication(periods: [period(interval: 2)]));
      await source.createPeriod(
        'pet-1',
        period(id: 'next', start: day(1), interval: 2, times: [600]),
      );
      clock = DateTime(2026, 10, 23, 15);
      final loaded = (await source.getMedicationById(
        'pet-1',
        'med-1',
      )).toEntity();
      final doses = const CalculateMedicationDoses()(
        medications: [loaded],
        logs: [],
        fromDate: day(-4),
        toDate: day(3),
      );
      expect(doses.length, 8);
      for (final dose in doses) {
        await source.saveDoseLog(
          'pet-1',
          'med-1',
          MedicationDoseLogModel(
            periodId: dose.period.id,
            scheduledDate: dose.scheduledDate,
            scheduledMinute: dose.scheduledMinute,
            status: MedicationDoseStatus.given,
            givenAt: clock,
          ),
        );
      }
      expect((await logs()).length, doses.length);
    },
  );

  test('empty reads do not create planned doses', () async {
    expect(await source.getMedications('pet-1'), isEmpty);
    expect(await logs(), isEmpty);
    expect((await source.getSuggestions()).medicationNames, isEmpty);
    await source.createMedication(medication());
    expect(await db.query(DatabaseTables.medicationDoseLogs), isEmpty);
  });

  test(
    'creates, reopens and renames without reordering or losing periods',
    () async {
      await source.createMedication(
        medication(
          name: ' Medicine ',
          periods: [
            period(
              start: DateTime.utc(2026, 10, 16, 23),
              dosage: ' Half ',
              clinic: ' Clinic ',
              vet: ' ',
              notes: ' Note ',
            ),
          ],
        ),
      );
      await source.createMedication(
        medication(
          id: 'med-2',
          periods: [period(id: 'period-2', medicationId: 'med-2')],
        ),
      );
      await source.renameMedication('pet-1', 'med-1', ' Renamed ');
      await db.close();
      db = await openAppDatabase();
      source = MedicationLocalDataSourceImpl(db, now: () => clock);
      final values = await source.getMedications('pet-1');
      expect(values.map((value) => value.id), ['med-2', 'med-1']);
      expect(values.last.name, 'Renamed');
      expect(values.last.periods.single.startDate, day(-4));
      expect(values.last.periods.single.dosageInstructions, 'Half');
      expect(values.last.periods.single.clinicName, 'Clinic');
      expect(values.last.periods.single.veterinarianName, isNull);
      expect(values.last.periods.single.notes, 'Note');
    },
  );

  test('failed initial period insertion rolls back the parent', () async {
    await db.execute(
      '''CREATE TRIGGER fail_period BEFORE INSERT ON medication_periods
      BEGIN SELECT RAISE(ABORT, 'simulated'); END''',
    );
    await expectLater(
      source.createMedication(medication()),
      throwsA(isA<LocalDataSourceException>()),
    );
    expect(await db.query(DatabaseTables.medications), isEmpty);
    expect(await db.query(DatabaseTables.medicationPeriods), isEmpty);
  });

  for (final count in [0, 2]) {
    test('creation requires exactly one initial period: $count', () async {
      await expectLater(
        source.createMedication(
          medication(
            periods: [for (var i = 0; i < count; i++) period(id: 'period-$i')],
          ),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getMedications('pet-1'), isEmpty);
    });
  }

  test(
    'missing owner and mismatched initial parent do not create data',
    () async {
      await expectLater(
        source.createMedication(medication(petId: 'missing')),
        throwsA(isA<LocalDataNotFoundException>()),
      );
      await expectLater(
        source.createMedication(
          medication(periods: [period(medicationId: 'other')]),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(await source.getMedications('pet-1'), isEmpty);
    },
  );

  for (final invalid in <String, MedicationPeriodModel Function()>{
    'zero interval': () => period(interval: 0),
    'negative interval': () => period(interval: -1),
    'empty times': () => period(times: []),
    'duplicate times': () => period(times: [480, 480]),
    'negative minute': () => period(times: [-1]),
    'minute after day': () => period(times: [1440]),
    'end before start': () => period(end: DateTime(2020)),
    'long dosage': () => period(dosage: 'a' * 101),
    'long notes': () => period(notes: 'a' * 201),
  }.entries) {
    test('rejects ${invalid.key} on create and update', () async {
      await expectLater(
        source.createMedication(medication(periods: [invalid.value()])),
        throwsA(isA<LocalDataSourceException>()),
      );
      await source.createMedication(medication());
      await expectLater(
        source.updatePeriod('pet-1', invalid.value()),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(
        (await source.getMedicationById('pet-1', 'med-1')).periods.single,
        period(),
      );
    });
  }

  test('name limits count graphemes and apply to rename too', () async {
    final name = '🐕‍🦺' * 50;
    await source.createMedication(medication(name: name));
    expect((await source.getMedicationById('pet-1', 'med-1')).name, name);
    for (final invalid in ['   ', '🐕‍🦺' * 51]) {
      await expectLater(
        source.renameMedication('pet-1', 'med-1', invalid),
        throwsA(isA<LocalDataSourceException>()),
      );
      await expectLater(
        source.createMedication(medication(id: 'bad', name: invalid)),
        throwsA(isA<LocalDataSourceException>()),
      );
    }
  });

  test(
    'visit filters preserve all successor periods and keep pet scope',
    () async {
      await visit('visit-1', 'pet-1');
      await source.createMedication(
        medication(periods: [period(visitId: 'visit-1')]),
      );
      final successor = period(id: 'next', start: day(1));
      await source.createPeriod('pet-1', successor);
      final matches = await source.getMedications(
        'pet-1',
        vetVisitId: 'visit-1',
      );
      expect(matches.single.periods, [period(visitId: 'visit-1'), successor]);
      expect(
        await source.getMedications('pet-2', vetVisitId: 'visit-1'),
        isEmpty,
      );
      expect(
        await source.getMedications('pet-1', vetVisitId: "' OR 1=1 --"),
        isEmpty,
      );
    },
  );

  test('visit ownership applies on create and update', () async {
    await visit('other', 'pet-2');
    await expectLater(
      source.createMedication(medication(periods: [period(visitId: 'other')])),
      throwsA(isA<LocalDataNotFoundException>()),
    );
    await source.createMedication(medication());
    await expectLater(
      source.updatePeriod('pet-1', period(visitId: 'other')),
      throwsA(isA<LocalDataNotFoundException>()),
    );
    await expectLater(
      source.updatePeriod('pet-1', period(visitId: 'missing')),
      throwsA(isA<LocalDataNotFoundException>()),
    );
  });

  test('every existing-record operation rejects the wrong pet', () async {
    await source.createMedication(medication());
    await source.createPeriod('pet-1', period(id: 'next', start: day(1)));
    await source.saveDoseLog('pet-1', 'med-1', log());
    final operations = <Future<dynamic> Function()>[
      () => source.getMedicationById('pet-2', 'med-1'),
      () => source.renameMedication('pet-2', 'med-1', 'Other'),
      () => source.deleteMedication('pet-2', 'med-1'),
      () => source.createPeriod('pet-2', period(id: 'bad', start: day(2))),
      () => source.updatePeriod('pet-2', period(notes: 'Other')),
      () => source.deletePeriod('pet-2', 'med-1', 'next'),
      () => source.getDoseLogs(
        'pet-2',
        medicationId: 'med-1',
        fromDate: day(-1),
        toDate: day(0),
      ),
      () => source.saveDoseLog(
        'pet-2',
        'med-1',
        log(status: MedicationDoseStatus.skipped),
      ),
      () => source.clearDoseLog(
        'pet-2',
        'med-1',
        periodId: 'period-1',
        scheduledDate: day(0),
        scheduledMinute: 480,
      ),
    ];
    for (final action in operations) {
      await expectLater(action(), throwsA(isA<LocalDataNotFoundException>()));
    }
    expect((await source.getMedicationById('pet-1', 'med-1')).name, 'Medicine');
    expect((await logs()).single.status, MedicationDoseStatus.given);
  });

  test(
    'periods cannot be moved to another medication or used for its logs',
    () async {
      await source.createMedication(medication());
      await source.createMedication(
        medication(
          id: 'med-2',
          periods: [period(id: 'period-2', medicationId: 'med-2')],
        ),
      );
      await expectLater(
        source.updatePeriod('pet-1', period(medicationId: 'med-2')),
        throwsA(isA<LocalDataNotFoundException>()),
      );
      await expectLater(
        source.saveDoseLog('pet-1', 'med-1', log(periodId: 'period-2')),
        throwsA(isA<LocalDataNotFoundException>()),
      );
      await expectLater(
        source.clearDoseLog(
          'pet-1',
          'med-1',
          periodId: 'period-2',
          scheduledDate: day(0),
          scheduledMinute: 480,
        ),
        throwsA(isA<LocalDataNotFoundException>()),
      );
      expect(await logs(), isEmpty);
    },
  );

  test(
    'future period edits and removal retain old logs and resume the earlier plan',
    () async {
      await source.createMedication(medication());
      await source.saveDoseLog('pet-1', 'med-1', log(date: day(-1)));
      await source.createPeriod(
        'pet-1',
        period(id: 'next', start: day(1), dosage: 'One'),
      );
      await source.updatePeriod(
        'pet-1',
        period(id: 'next', start: day(2), interval: 2, times: [600]),
      );
      await source.deletePeriod('pet-1', 'med-1', 'next');
      expect((await source.getMedicationById('pet-1', 'med-1')).periods, [
        period(),
      ]);
      expect(
        await logs(),
        [
          log(date: day(-1)).toJson(),
        ].map(MedicationDoseLogModel.fromJson).toList(),
      );
      await source.saveDoseLog('pet-1', 'med-1', log());
    },
  );

  test('new periods reject today, past and duplicate starts', () async {
    await source.createMedication(medication());
    for (final start in [day(-2), day(0)]) {
      await expectLater(
        source.createPeriod('pet-1', period(id: 'bad', start: start)),
        throwsA(isA<LocalDataSourceException>()),
      );
    }
    await source.createPeriod('pet-1', period(id: 'next', start: day(1)));
    await expectLater(
      source.createPeriod('pet-1', period(id: 'duplicate', start: day(1))),
      throwsA(isA<LocalDataSourceException>()),
    );
    await expectLater(
      source.updatePeriod('pet-1', period(id: 'next', start: day(0))),
      throwsA(isA<LocalDataSourceException>()),
    );
    await expectLater(
      source.deletePeriod('pet-1', 'med-1', 'period-1'),
      throwsA(isA<LocalDataSourceException>()),
    );
  });

  test('the only future period cannot be removed', () async {
    await source.createMedication(medication(periods: [period(start: day(1))]));
    await expectLater(
      source.deletePeriod('pet-1', 'med-1', 'period-1'),
      throwsA(isA<LocalDataSourceException>()),
    );
  });

  test('recorded schedules lock while metadata remains editable', () async {
    await source.createMedication(medication());
    await source.saveDoseLog('pet-1', 'med-1', log());
    for (final changed in [
      period(start: day(-5)),
      period(interval: 2),
      period(times: [480]),
      period(dosage: 'Other'),
    ]) {
      await expectLater(
        source.updatePeriod('pet-1', changed),
        throwsA(isA<LocalDataSourceException>()),
      );
    }
    await source.updatePeriod(
      'pet-1',
      period(end: day(0), clinic: 'Updated', notes: 'Corrected'),
    );
    expect(
      (await source.getMedicationById('pet-1', 'med-1')).periods.single.notes,
      'Corrected',
    );
    expect((await logs()).length, 1);
  });

  test(
    'shortening a period past a saved result rolls back the update',
    () async {
      await source.createMedication(medication());
      await source.saveDoseLog('pet-1', 'med-1', log());
      await expectLater(
        source.updatePeriod(
          'pet-1',
          period(end: day(-1), notes: 'Must roll back'),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      expect(
        (await source.getMedicationById('pet-1', 'med-1')).periods.single,
        period(),
      );
      expect((await logs()).single.scheduledDate, day(0));
    },
  );

  test(
    'successor boundary and day intervals define the valid dose slots',
    () async {
      await source.createMedication(
        medication(periods: [period(start: day(-2), interval: 2)]),
      );
      await expectLater(
        source.saveDoseLog('pet-1', 'med-1', log(date: day(-1))),
        throwsA(isA<LocalDataSourceException>()),
      );
      await source.saveDoseLog('pet-1', 'med-1', log());
      await source.createPeriod(
        'pet-1',
        period(
          id: 'next',
          start: day(1),
          interval: 2,
          end: day(3),
          times: [600],
        ),
      );
      clock = DateTime(2026, 10, 24, 15);
      await expectLater(
        source.saveDoseLog('pet-1', 'med-1', log(date: day(2))),
        throwsA(isA<LocalDataSourceException>()),
      );
      await source.saveDoseLog(
        'pet-1',
        'med-1',
        log(periodId: 'next', date: day(1), minute: 600),
      );
      await expectLater(
        source.saveDoseLog(
          'pet-1',
          'med-1',
          log(periodId: 'next', date: day(2), minute: 600),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
      await source.saveDoseLog(
        'pet-1',
        'med-1',
        log(periodId: 'next', date: day(3), minute: 600),
      );
      await expectLater(
        source.saveDoseLog(
          'pet-1',
          'med-1',
          log(periodId: 'next', date: day(4), minute: 600),
        ),
        throwsA(isA<LocalDataSourceException>()),
      );
    },
  );

  test('one-day use is inclusive and next-day input is rejected', () async {
    await source.createMedication(
      medication(
        periods: [period(start: day(-1), end: day(-1))],
      ),
    );
    await source.saveDoseLog('pet-1', 'med-1', log(date: day(-1)));
    await expectLater(
      source.saveDoseLog('pet-1', 'med-1', log()),
      throwsA(isA<LocalDataSourceException>()),
    );
  });

  test('invalid dose day, time and outcome timestamps are rejected', () async {
    await source.createMedication(medication());
    for (final invalid in [
      log(date: day(-5)),
      log(date: day(1)),
      log(minute: 600),
      log(givenAt: clock.add(const Duration(seconds: 1))),
      log(status: MedicationDoseStatus.skipped, givenAt: clock),
      MedicationDoseLogModel(
        periodId: 'period-1',
        scheduledDate: day(0),
        scheduledMinute: 480,
        status: MedicationDoseStatus.given,
      ),
    ]) {
      await expectLater(
        source.saveDoseLog('pet-1', 'med-1', invalid),
        throwsA(isA<LocalDataSourceException>()),
      );
    }
    expect(await logs(), isEmpty);
  });

  test(
    'dose corrections and concurrent submissions keep a single result',
    () async {
      await source.createMedication(medication());
      await Future.wait([
        source.saveDoseLog('pet-1', 'med-1', log()),
        source.saveDoseLog('pet-1', 'med-1', log()),
      ]);
      final rowid = (await db.rawQuery(
        'SELECT rowid FROM medication_dose_logs',
      )).single['rowid'];
      await source.saveDoseLog(
        'pet-1',
        'med-1',
        log(status: MedicationDoseStatus.skipped),
      );
      expect((await logs()).single.status, MedicationDoseStatus.skipped);
      expect(
        (await db.rawQuery(
          'SELECT rowid FROM medication_dose_logs',
        )).single['rowid'],
        rowid,
      );
      await source.clearDoseLog(
        'pet-1',
        'med-1',
        periodId: 'period-1',
        scheduledDate: day(0),
        scheduledMinute: 480,
      );
      expect(await logs(), isEmpty);
      expect((await source.getMedicationById('pet-1', 'med-1')).periods, [
        period(),
      ]);
      await expectLater(
        source.clearDoseLog(
          'pet-1',
          'med-1',
          periodId: 'period-1',
          scheduledDate: day(0),
          scheduledMinute: 480,
        ),
        throwsA(isA<LocalDataNotFoundException>()),
      );
    },
  );

  test(
    'dose ranges are inclusive, scoped and ordered with calendar components',
    () async {
      await source.createMedication(medication());
      await source.createMedication(
        medication(
          id: 'med-2',
          petId: 'pet-2',
          periods: [period(id: 'period-2', medicationId: 'med-2')],
        ),
      );
      for (final entry in [log(minute: 1200), log(date: day(-1)), log()]) {
        await source.saveDoseLog('pet-1', 'med-1', entry);
      }
      await source.saveDoseLog('pet-2', 'med-2', log(periodId: 'period-2'));
      final result = await source.getDoseLogs(
        'pet-1',
        fromDate: day(-1),
        toDate: DateTime.utc(2026, 10, 20, 23),
      );
      expect(
        result.map(
          (entry) =>
              (calendarDateKey(entry.scheduledDate), entry.scheduledMinute),
        ),
        [('2026-10-19', 480), ('2026-10-20', 480), ('2026-10-20', 1200)],
      );
      await expectLater(
        source.getDoseLogs('pet-1', fromDate: day(1), toDate: day(0)),
        throwsA(isA<LocalDataSourceException>()),
      );
    },
  );

  test(
    'calendar intervals cross month/year boundaries without time-of-day drift',
    () async {
      await source.createMedication(
        medication(
          periods: [period(start: DateTime.utc(2025, 12, 31, 23), interval: 2)],
        ),
      );
      await source.saveDoseLog(
        'pet-1',
        'med-1',
        log(date: DateTime.utc(2026, 1, 2, 23)),
      );
      await expectLater(
        source.saveDoseLog('pet-1', 'med-1', log(date: DateTime(2026, 1, 1))),
        throwsA(isA<LocalDataSourceException>()),
      );
    },
  );

  test(
    'visit changes and deletion preserve dates, snapshots and dose history',
    () async {
      await visit('visit-1', 'pet-1');
      await source.createMedication(
        medication(
          periods: [period(visitId: 'visit-1', clinic: 'Snapshot')],
        ),
      );
      await source.saveDoseLog('pet-1', 'med-1', log());
      await db.update(
        DatabaseTables.vetVisits,
        {'visited_on': '2026-10-02'},
        where: 'id = ?',
        whereArgs: ['visit-1'],
      );
      expect(
        (await source.getMedicationById(
          'pet-1',
          'med-1',
        )).periods.single.startDate,
        day(-4),
      );
      await db.delete(
        DatabaseTables.vetVisits,
        where: 'id = ?',
        whereArgs: ['visit-1'],
      );
      final saved = (await source.getMedicationById(
        'pet-1',
        'med-1',
      )).periods.single;
      expect(saved.vetVisitId, isNull);
      expect(saved.clinicName, 'Snapshot');
      expect((await logs()).length, 1);
    },
  );

  test(
    'medication and pet deletion cascade only within their own records',
    () async {
      await source.createMedication(medication());
      await source.saveDoseLog('pet-1', 'med-1', log());
      await source.createMedication(
        medication(
          id: 'med-2',
          petId: 'pet-2',
          periods: [period(id: 'period-2', medicationId: 'med-2')],
        ),
      );
      await source.saveDoseLog('pet-2', 'med-2', log(periodId: 'period-2'));
      await source.deleteMedication('pet-1', 'med-1');
      expect(await logs(), isEmpty);
      expect((await logs(petId: 'pet-2')).length, 1);
      await db.delete(
        DatabaseTables.pets,
        where: 'id = ?',
        whereArgs: ['pet-2'],
      );
      expect(await db.query(DatabaseTables.medications), isEmpty);
      expect(await db.query(DatabaseTables.medicationPeriods), isEmpty);
      expect(await db.query(DatabaseTables.medicationDoseLogs), isEmpty);
    },
  );

  test(
    'all care forms share suggestions and remove names with their last saved source',
    () async {
      await visit('visit-1', 'pet-1');
      await db.update(DatabaseTables.vetVisits, {
        'clinic_name': ' Clinic   A ',
        'veterinarian_name': 'Dr. Visit',
      });
      await db.insert(DatabaseTables.vaccinations, {
        'id': 'vaccine',
        'pet_id': 'pet-1',
        'vaccine_name': 'Vaccine',
        'status': 'administered',
        'date': '2026-10-01',
        'clinic_name': 'clinic a',
        'veterinarian_name': 'Dr. Vaccine',
      });
      await source.createMedication(
        medication(
          periods: [period(clinic: 'Clinic A', vet: 'Dr. Medicine')],
        ),
      );
      await source.createMedication(
        medication(
          id: 'med-2',
          petId: 'pet-2',
          name: ' medicine ',
          periods: [
            period(
              id: 'period-2',
              medicationId: 'med-2',
              clinic: 'Other Clinic',
              vet: 'Dr. Other',
            ),
          ],
        ),
      );
      final scoped = await source.getSuggestions(clinicName: ' CLINIC  A ');
      expect(scoped.medicationNames, ['medicine']);
      expect(scoped.veterinarianNames, [
        'Dr. Medicine',
        'Dr. Vaccine',
        'Dr. Visit',
      ]);
      expect(
        (await VaccinationLocalDataSourceImpl(
          db,
        ).getSuggestions()).veterinarianNames,
        contains('Dr. Medicine'),
      );
      expect(
        (await VetVisitLocalDataSourceImpl(db).getSuggestions()).clinicNames,
        contains('Other Clinic'),
      );
      await source.deleteMedication('pet-1', 'med-1');
      expect(
        (await source.getSuggestions()).veterinarianNames,
        isNot(contains('Dr. Medicine')),
      );
      await source.deleteMedication('pet-2', 'med-2');
      expect((await source.getSuggestions()).medicationNames, isEmpty);
      await db.delete(DatabaseTables.vaccinations);
      await db.delete(DatabaseTables.vetVisits);
      expect((await source.getSuggestions()).clinicNames, isEmpty);
    },
  );

  test(
    'the database enforces the unique scheduled-dose key directly',
    () async {
      await source.createMedication(medication());
      await source.saveDoseLog('pet-1', 'med-1', log());
      await expectLater(
        db.insert(DatabaseTables.medicationDoseLogs, log().toJson()),
        throwsA(isA<DatabaseException>()),
      );
      expect((await logs()).length, 1);
    },
  );

  test(
    'SQL metacharacters are stored as data, never interpreted as queries',
    () async {
      const name = "O'Brien'); DROP TABLE pets; --";
      await source.createMedication(medication(name: name));
      expect((await source.getMedicationById('pet-1', 'med-1')).name, name);
      await expectLater(
        source.deleteMedication('pet-1', "' OR 1=1 --"),
        throwsA(isA<LocalDataNotFoundException>()),
      );
      expect((await db.query(DatabaseTables.pets)).length, 2);
      expect((await source.getMedications('pet-1')).length, 1);
    },
  );
}
