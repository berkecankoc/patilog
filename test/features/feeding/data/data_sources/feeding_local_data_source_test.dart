import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/database/app_database.dart';
import 'package:patilog/core/database/database_tables.dart';
import 'package:patilog/core/error/exception.dart';
import 'package:patilog/features/feeding/data/data_sources/feeding_local_data_source.dart';
import 'package:patilog/features/feeding/data/models/feeding_entry_model.dart';
import 'package:patilog/features/feeding/data/models/feeding_meal_model.dart';
import 'package:patilog/features/feeding/data/models/feeding_plan_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late Database db;
  late FeedingLocalDataSourceImpl source;
  late DateTime clock;
  final invalid = throwsA(isA<LocalDataSourceException>());
  final missing = throwsA(isA<LocalDataNotFoundException>());
  DateTime day([int offset = 0]) => DateTime(2026, 11, 1 + offset);

  FeedingMealModel meal({
    String id = 'meal',
    String planId = 'plan',
    int minute = 540,
    double amount = 30.5,
    String? foodName = 'Dry food',
  }) => FeedingMealModel(
    id: id,
    planId: planId,
    scheduledMinute: minute,
    amountGrams: amount,
    foodName: foodName,
  );

  FeedingPlanModel plan({
    String id = 'plan',
    String petId = 'pet-1',
    DateTime? start,
    DateTime? end,
    List<FeedingMealModel>? meals,
  }) => FeedingPlanModel(
    id: id,
    petId: petId,
    startDate: start ?? day(),
    endDate: end,
    meals: meals ?? [meal(id: '$id-meal', planId: id)],
  );

  FeedingEntryModel entry({
    String id = 'entry',
    String petId = 'pet-1',
    double amount = 20.5,
    DateTime? givenAt,
    String? foodName = ' Food ',
    String? notes = ' Note ',
    String? mealId,
    DateTime? scheduledDate,
  }) => FeedingEntryModel(
    id: id,
    petId: petId,
    amountGrams: amount,
    givenAt: givenAt ?? clock,
    foodName: foodName,
    notes: notes,
    mealId: mealId,
    scheduledDate: scheduledDate,
  );

  Future<List<FeedingEntryModel>> entries([String petId = 'pet-1']) =>
      source.getFeedingEntries(petId, from: day(-30), before: day(100));

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('feeding-data-');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await openAppDatabase();
    clock = DateTime(2026, 11, 1, 15, 30);
    source = FeedingLocalDataSourceImpl(db, now: () => clock);
    for (final id in ['pet-1', 'pet-2']) {
      await db.insert(DatabaseTables.pets, {
        'id': id,
        'name': id,
        'species': 'cat',
        'sex': 'unknown',
        'reproductive_status': 'unknown',
      });
    }
  });

  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test('empty reads succeed, missing single plans do not', () async {
    expect(await source.getFeedingPlans('pet-1'), isEmpty);
    expect(await source.getAllFeedingPlans(), isEmpty);
    expect(await entries(), isEmpty);
    expect(
      await source.getAllFeedingEntries(from: day(), before: day(1)),
      isEmpty,
    );
    expect(
      await source.getPlannedFeedingEntries(
        'pet-1',
        fromDate: day(),
        toDate: day(),
      ),
      isEmpty,
    );
    expect(
      await source.getAllPlannedFeedingEntries(fromDate: day(), toDate: day()),
      isEmpty,
    );
    await expectLater(source.getFeedingPlanById('pet-1', 'missing'), missing);
  });

  test(
    'plans persist all versions, sorted meals and isolated pet ownership',
    () async {
      await source.createFeedingPlan(plan(id: 'other', petId: 'pet-2'));
      await source.createFeedingPlan(
        plan(
          start: DateTime.utc(2026, 11, 1, 23),
          meals: [
            meal(id: 'late', minute: 1200, foodName: ' '),
            meal(id: 'early', minute: 480, foodName: '  Dry food  '),
          ],
        ),
      );
      await source.createFeedingPlan(plan(id: 'next', start: day(1)));
      final saved = await source.getFeedingPlans('pet-1');
      expect(saved.map((value) => value.id), ['plan', 'next']);
      expect(saved.first.meals.map((value) => value.id), ['early', 'late']);
      expect(saved.first.meals.map((value) => value.foodName), [
        'Dry food',
        null,
      ]);
      expect((await source.getAllFeedingPlans()).map((value) => value.id), [
        'plan',
        'next',
        'other',
      ]);
      expect(await source.getFeedingPlanById('pet-1', 'plan'), saved.first);
      await expectLater(source.getFeedingPlanById('pet-2', 'plan'), missing);
      await expectLater(
        source.createFeedingPlan(plan(id: 'foreign', petId: 'missing')),
        missing,
      );
    },
  );

  test(
    'initial plans cannot backdate and successors must start after today',
    () async {
      await expectLater(
        source.createFeedingPlan(plan(start: day(-1))),
        invalid,
      );
      await source.createFeedingPlan(plan());
      await expectLater(
        source.createFeedingPlan(plan(id: 'same-day')),
        invalid,
      );
      await source.createFeedingPlan(plan(id: 'next', start: day(1)));
      await expectLater(
        source.createFeedingPlan(plan(id: 'duplicate-start', start: day(1))),
        invalid,
      );
      expect((await source.getFeedingPlans('pet-1')).length, 2);
    },
  );

  test(
    'plans reject empty/duplicate meals, invalid times and mismatched ownership',
    () async {
      for (final meals in [
        <FeedingMealModel>[],
        [meal(), meal(minute: 600)],
        [meal(), meal(id: 'second')],
        [meal(minute: -1)],
        [meal(minute: 1440)],
      ]) {
        await expectLater(
          source.createFeedingPlan(plan(meals: meals)),
          invalid,
        );
      }
      await expectLater(
        source.createFeedingPlan(plan(meals: [meal(planId: 'foreign')])),
        missing,
      );
      await expectLater(source.createFeedingPlan(plan(end: day(-1))), invalid);
      expect(await source.getAllFeedingPlans(), isEmpty);
    },
  );

  for (final amount in [0.0, -1.0, double.nan, double.infinity, 0.01, 12.55]) {
    test(
      'rejects invalid gram amount $amount in plans and actual entries',
      () async {
        await expectLater(
          source.createFeedingPlan(plan(meals: [meal(amount: amount)])),
          invalid,
        );
        await expectLater(
          source.createFeedingEntry(entry(amount: amount)),
          invalid,
        );
        expect(await source.getAllFeedingPlans(), isEmpty);
        expect(await entries(), isEmpty);
      },
    );
  }

  test(
    'text limits count trimmed graphemes and empty snapshots become null',
    () async {
      final name = List.filled(50, '🐈‍⬛').join();
      final notes = List.filled(200, 'e\u0301').join();
      await source.createFeedingPlan(plan(meals: [meal(foodName: ' $name ')]));
      await source.createFeedingEntry(
        entry(amount: 0.1, foodName: ' $name ', notes: ' $notes '),
      );
      expect((await entries()).single.foodName, name);
      expect((await entries()).single.notes, notes);
      await expectLater(
        source.createFeedingPlan(
          plan(
            id: 'long-name',
            start: day(1),
            meals: [meal(planId: 'long-name', foodName: '${name}x')],
          ),
        ),
        invalid,
      );
      await expectLater(
        source.createFeedingEntry(entry(id: 'long-name', foodName: '${name}x')),
        invalid,
      );
      await expectLater(
        source.createFeedingEntry(entry(id: 'long-notes', notes: '${notes}x')),
        invalid,
      );
      await source.createFeedingEntry(
        entry(id: 'blank', foodName: '  ', notes: '\n'),
      );
      expect((await entries()).first.foodName, isNull);
      expect((await entries()).first.notes, isNull);
    },
  );

  test(
    'started schedules retain start and meals but may end today or later',
    () async {
      await source.createFeedingPlan(plan());
      await expectLater(source.updateFeedingPlan(plan(start: day(1))), invalid);
      await expectLater(
        source.updateFeedingPlan(
          plan(meals: [meal(id: 'plan-meal', minute: 600)]),
        ),
        invalid,
      );
      await expectLater(
        source.updateFeedingPlan(
          plan(meals: [meal(id: 'plan-meal', amount: 40)]),
        ),
        invalid,
      );
      await expectLater(
        source.updateFeedingPlan(
          plan(
            meals: [meal(id: 'plan-meal', foodName: 'Changed')],
          ),
        ),
        invalid,
      );
      await expectLater(source.updateFeedingPlan(plan(end: day(-1))), invalid);
      await source.updateFeedingPlan(plan(end: day(2)));
      await source.updateFeedingPlan(plan());
      await source.updateFeedingPlan(plan(end: day()));
      expect((await source.getFeedingPlanById('pet-1', 'plan')).endDate, day());
      await expectLater(source.deleteFeedingPlan('pet-1', 'plan'), invalid);
      clock = day(1);
      await expectLater(source.updateFeedingPlan(plan()), invalid);
    },
  );

  test(
    'unstarted plan replacement/cancellation retains older plans and entries',
    () async {
      await source.createFeedingPlan(plan());
      await source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day()),
      );
      await source.createFeedingPlan(plan(id: 'next', start: day(1)));
      await source.updateFeedingPlan(
        plan(
          id: 'next',
          start: day(2),
          meals: [
            meal(id: 'replacement', planId: 'next', minute: 600, amount: 50),
          ],
        ),
      );
      expect(
        (await source.getFeedingPlanById('pet-1', 'next')).meals.single.id,
        'replacement',
      );
      await expectLater(
        source.updateFeedingPlan(plan(id: 'next', start: day())),
        invalid,
      );
      await expectLater(source.deleteFeedingPlan('pet-2', 'next'), missing);
      await source.deleteFeedingPlan('pet-1', 'next');
      final remaining = (await source.getFeedingPlans('pet-1')).single;
      expect(remaining.toEntity().isActiveOn(day(10)), isTrue);
      expect((await entries()).single.id, 'entry');
      expect(
        (await db.query(DatabaseTables.feedingMeals)).single['id'],
        'plan-meal',
      );
    },
  );

  test('the initial future plan can move to today', () async {
    await source.createFeedingPlan(plan(start: day(3)));
    await source.updateFeedingPlan(plan());
    expect((await source.getFeedingPlanById('pet-1', 'plan')).startDate, day());
  });

  test('a superseded plan cannot resume after its successor ends', () async {
    await source.createFeedingPlan(plan());
    await source.createFeedingPlan(
      plan(id: 'next', start: day(1), end: day(1)),
    );
    clock = day(2);
    await expectLater(
      source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day(2)),
      ),
      invalid,
    );
    await expectLater(
      source.createFeedingEntry(
        entry(mealId: 'next-meal', scheduledDate: day(2)),
      ),
      invalid,
    );
    await expectLater(source.updateFeedingPlan(plan(end: day(5))), invalid);
    await source.createFeedingEntry(
      entry(mealId: 'next-meal', scheduledDate: day(1)),
    );
    expect((await entries()).single.scheduledDate, day(1));
  });

  test(
    'planned records require a paired, owned meal in its effective calendar window',
    () async {
      await source.createFeedingPlan(plan());
      await source.createFeedingPlan(plan(id: 'other', petId: 'pet-2'));
      await expectLater(
        source.createFeedingEntry(entry(petId: 'missing')),
        missing,
      );
      await expectLater(
        source.createFeedingEntry(
          entry(mealId: 'missing', scheduledDate: day()),
        ),
        missing,
      );
      await expectLater(
        source.createFeedingEntry(
          entry(mealId: 'other-meal', scheduledDate: day()),
        ),
        missing,
      );
      await expectLater(
        source.createFeedingEntry(entry(mealId: 'plan-meal')),
        invalid,
      );
      await expectLater(
        source.createFeedingEntry(entry(scheduledDate: day())),
        invalid,
      );
      await expectLater(
        source.createFeedingEntry(
          entry(mealId: 'plan-meal', scheduledDate: day(-1)),
        ),
        invalid,
      );
      await expectLater(
        source.createFeedingEntry(
          entry(mealId: 'plan-meal', scheduledDate: day(1)),
        ),
        invalid,
      );
      await expectLater(
        source.createFeedingEntry(
          entry(givenAt: clock.add(const Duration(microseconds: 1))),
        ),
        invalid,
      );
      await source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day()),
      );
      await expectLater(
        source.createFeedingEntry(
          entry(id: 'duplicate', mealId: 'plan-meal', scheduledDate: day()),
        ),
        invalid,
      );
      expect((await entries()).single.id, 'entry');
    },
  );

  test(
    'actual ranges are half-open instants, planned ranges inclusive calendar days',
    () async {
      await source.createFeedingPlan(plan());
      clock = day(2);
      final boundary = DateTime.utc(2026, 11, 2, 0, 0, 0, 123);
      await source.createFeedingEntry(
        entry(
          id: 'before',
          givenAt: boundary.subtract(const Duration(microseconds: 1)),
        ),
      );
      await source.createFeedingEntry(
        entry(
          id: 'late',
          givenAt: boundary,
          mealId: 'plan-meal',
          scheduledDate: DateTime.utc(2026, 11, 1, 23),
        ),
      );
      await source.createFeedingEntry(
        entry(
          id: 'after',
          givenAt: boundary.add(const Duration(microseconds: 1)),
        ),
      );
      await source.createFeedingEntry(
        entry(id: 'other', petId: 'pet-2', givenAt: boundary),
      );
      expect(
        (await source.getFeedingEntries(
          'pet-1',
          from: boundary,
          before: boundary.add(const Duration(microseconds: 1)),
        )).map((e) => e.id),
        ['late'],
      );
      expect(
        (await source.getAllFeedingEntries(
          from: boundary,
          before: boundary.add(const Duration(microseconds: 1)),
        )).map((e) => e.id),
        ['other', 'late'],
      );
      expect(
        (await source.getPlannedFeedingEntries(
          'pet-1',
          fromDate: day(),
          toDate: day(),
        )).map((e) => e.id),
        ['late'],
      );
      expect(
        await source.getPlannedFeedingEntries(
          'pet-2',
          fromDate: day(),
          toDate: day(),
        ),
        isEmpty,
      );
      expect(
        (await source.getAllPlannedFeedingEntries(
          fromDate: day(),
          toDate: day(),
        )).single.id,
        'late',
      );
      expect(
        await source.getAllPlannedFeedingEntries(
          fromDate: day(1),
          toDate: day(2),
        ),
        isEmpty,
      );
    },
  );

  test(
    'equal timestamps retain insertion ties when snapshots are corrected',
    () async {
      await source.createFeedingPlan(plan());
      await source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day()),
      );
      await source.createFeedingEntry(entry(id: 'manual'));
      final before = await db.rawQuery(
        'SELECT rowid FROM feeding_entries WHERE id = ?',
        ['entry'],
      );
      await source.updateFeedingEntry(
        entry(
          amount: 15,
          foodName: ' New food ',
          notes: '  ',
          mealId: 'plan-meal',
          scheduledDate: day(),
        ),
      );
      expect((await entries()).map((e) => e.id), ['manual', 'entry']);
      final saved = (await entries()).last;
      expect(saved.amountGrams, 15);
      expect(saved.foodName, 'New food');
      expect(saved.notes, isNull);
      expect(
        (await source.getFeedingPlanById(
          'pet-1',
          'plan',
        )).meals.single.amountGrams,
        30.5,
      );
      expect(
        await db.rawQuery('SELECT rowid FROM feeding_entries WHERE id = ?', [
          'entry',
        ]),
        before,
      );
      await source.updateFeedingEntry(
        entry(
          givenAt: clock.subtract(const Duration(hours: 1)),
          mealId: 'plan-meal',
          scheduledDate: day(),
        ),
      );
      expect(
        (await entries()).last.givenAt,
        clock.subtract(const Duration(hours: 1)).toUtc(),
      );
    },
  );

  test(
    'corrections cannot move owner or occurrence; deletion targets only its known ID',
    () async {
      await source.createFeedingPlan(plan());
      await source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day()),
      );
      await expectLater(
        source.updateFeedingEntry(entry(petId: 'pet-2')),
        missing,
      );
      await expectLater(
        source.updateFeedingEntry(entry(id: 'missing')),
        missing,
      );
      await expectLater(source.updateFeedingEntry(entry()), invalid);
      await expectLater(
        source.updateFeedingEntry(
          entry(mealId: 'plan-meal', scheduledDate: day(-1)),
        ),
        invalid,
      );
      await expectLater(source.deleteFeedingEntry('pet-2', 'entry'), missing);
      await expectLater(source.deleteFeedingEntry('pet-1', 'missing'), missing);
      expect((await entries()).single.id, 'entry');
      await source.deleteFeedingEntry('pet-1', 'entry');
      expect(await entries(), isEmpty);
      await source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day()),
      );
      expect((await entries()).length, 1);
    },
  );

  test(
    'invalid ranges and unsupported years fail without broadening queries',
    () async {
      await expectLater(
        source.getFeedingEntries('pet-1', from: day(), before: day()),
        invalid,
      );
      await expectLater(
        source.getAllFeedingEntries(from: day(1), before: day()),
        invalid,
      );
      await expectLater(
        source.getPlannedFeedingEntries(
          'pet-1',
          fromDate: day(1),
          toDate: day(),
        ),
        invalid,
      );
      await expectLater(
        source.getAllPlannedFeedingEntries(
          fromDate: DateTime(0),
          toDate: day(),
        ),
        invalid,
      );
      await expectLater(
        source.createFeedingPlan(plan(start: DateTime(10000))),
        invalid,
      );
      await expectLater(
        source.createFeedingEntry(entry(givenAt: DateTime.utc(0))),
        invalid,
      );
    },
  );

  test(
    'failed child inserts roll back creation and pending replacement',
    () async {
      await db.execute('''
      CREATE TRIGGER reject_meal BEFORE INSERT ON feeding_meals
      WHEN NEW.id = 'fail' BEGIN SELECT RAISE(ABORT, 'test failure'); END
    ''');
      final broken = [meal(id: 'first'), meal(id: 'fail', minute: 600)];
      await expectLater(source.createFeedingPlan(plan(meals: broken)), invalid);
      expect(await source.getAllFeedingPlans(), isEmpty);
      expect(await db.query(DatabaseTables.feedingMeals), isEmpty);
      await source.createFeedingPlan(plan(start: day(1)));
      await expectLater(
        source.updateFeedingPlan(plan(start: day(2), meals: broken)),
        invalid,
      );
      final saved = await source.getFeedingPlanById('pet-1', 'plan');
      expect(saved.startDate, day(1));
      expect(saved.meals.single.id, 'plan-meal');
    },
  );

  test(
    'foreign meal ID conflicts never steal another pet plan or its meals',
    () async {
      await source.createFeedingPlan(plan(id: 'other', petId: 'pet-2'));
      await expectLater(
        source.createFeedingPlan(plan(meals: [meal(id: 'other-meal')])),
        invalid,
      );
      expect(await source.getFeedingPlans('pet-1'), isEmpty);
      expect(
        (await source.getFeedingPlanById('pet-2', 'other')).meals.single.id,
        'other-meal',
      );
      await expectLater(source.updateFeedingPlan(plan(id: 'other')), missing);
    },
  );

  test(
    'clock rollback cannot let later changes orphan recorded calendar days',
    () async {
      await source.createFeedingPlan(plan());
      clock = day(3);
      await source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day(3)),
      );
      clock = day();
      await expectLater(
        source.createFeedingPlan(plan(id: 'next', start: day(1))),
        invalid,
      );
      await expectLater(source.updateFeedingPlan(plan(end: day(1))), invalid);
      expect((await source.getFeedingPlans('pet-1')).single.endDate, isNull);
      expect((await entries()).single.scheduledDate, day(3));
    },
  );

  test('results lock even unstarted plans after a clock rollback', () async {
    await source.createFeedingPlan(plan(start: day(1)));
    clock = day(1);
    await source.createFeedingEntry(
      entry(mealId: 'plan-meal', scheduledDate: day(1)),
    );
    clock = day();
    await expectLater(source.updateFeedingPlan(plan(start: day(2))), invalid);
    await expectLater(source.deleteFeedingPlan('pet-1', 'plan'), invalid);
    expect((await entries()).single.id, 'entry');
  });

  test(
    'schema protects linked history, while pet cascade removes only that pet',
    () async {
      await source.createFeedingPlan(plan());
      await source.createFeedingPlan(plan(id: 'other', petId: 'pet-2'));
      await source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day()),
      );
      await source.createFeedingEntry(
        entry(
          id: 'other',
          petId: 'pet-2',
          mealId: 'other-meal',
          scheduledDate: day(),
        ),
      );
      await source.createFeedingEntry(entry(id: 'manual'));
      await expectLater(
        db.delete(
          DatabaseTables.feedingMeals,
          where: 'id = ?',
          whereArgs: ['plan-meal'],
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.delete(
          DatabaseTables.feedingPlans,
          where: 'id = ?',
          whereArgs: ['plan'],
        ),
        throwsA(isA<DatabaseException>()),
      );
      await db.delete(
        DatabaseTables.pets,
        where: 'id = ?',
        whereArgs: ['pet-1'],
      );
      expect(await source.getFeedingPlans('pet-1'), isEmpty);
      expect(await entries(), isEmpty);
      expect((await source.getAllFeedingPlans()).single.id, 'other');
      expect(
        (await db.query(DatabaseTables.feedingMeals)).single['id'],
        'other-meal',
      );
      expect((await entries('pet-2')).single.id, 'other');
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'schema rejects broken links, paired columns and duplicate occurrences',
    () async {
      await source.createFeedingPlan(plan());
      final saved = entry(mealId: 'plan-meal', scheduledDate: day());
      await source.createFeedingEntry(saved);
      for (final row in [
        {...saved.toJson(), 'id': 'duplicate'},
        {...saved.toJson(), 'id': 'unpaired', 'meal_id': null},
        {...saved.toJson(), 'id': 'foreign-key', 'meal_id': 'missing'},
      ]) {
        await expectLater(
          db.insert(DatabaseTables.feedingEntries, row),
          throwsA(isA<DatabaseException>()),
        );
      }
      expect((await entries()).length, 1);
    },
  );

  test(
    'reopening retains plans, snapshots, links and insertion order',
    () async {
      await source.createFeedingPlan(plan());
      await source.createFeedingEntry(
        entry(mealId: 'plan-meal', scheduledDate: day()),
      );
      await source.createFeedingEntry(entry(id: 'second'));
      final before = await db.rawQuery(
        'SELECT rowid, * FROM feeding_entries ORDER BY rowid',
      );
      await db.close();
      db = await openAppDatabase();
      source = FeedingLocalDataSourceImpl(db, now: () => clock);
      expect(
        await db.rawQuery(
          'SELECT rowid, * FROM feeding_entries ORDER BY rowid',
        ),
        before,
      );
      expect((await entries()).map((e) => e.id), ['second', 'entry']);
      expect(
        (await source.getFeedingPlans('pet-1')).single.meals.single.id,
        'plan-meal',
      );
    },
  );

  test(
    'closed database errors use the local-data exception boundary',
    () async {
      await db.close();
      await expectLater(source.getAllFeedingPlans(), invalid);
      await expectLater(source.createFeedingEntry(entry()), invalid);
      await expectLater(source.deleteFeedingEntry('pet-1', 'entry'), invalid);
    },
  );
}
