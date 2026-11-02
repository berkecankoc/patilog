import 'package:characters/characters.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/feeding/data/models/feeding_entry_model.dart';
import 'package:petlytics/features/feeding/data/models/feeding_meal_model.dart';
import 'package:petlytics/features/feeding/data/models/feeding_model_values.dart';
import 'package:petlytics/features/feeding/data/models/feeding_plan_model.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class FeedingLocalDataSource {
  Future<List<FeedingPlanModel>> getFeedingPlans(String petId);
  Future<List<FeedingPlanModel>> getAllFeedingPlans();
  Future<FeedingPlanModel> getFeedingPlanById(String petId, String planId);
  Future<void> createFeedingPlan(FeedingPlanModel plan);
  Future<void> updateFeedingPlan(FeedingPlanModel plan);
  Future<void> deleteFeedingPlan(String petId, String planId);
  Future<List<FeedingEntryModel>> getFeedingEntries(
    String petId, {
    required DateTime from,
    required DateTime before,
  });
  Future<List<FeedingEntryModel>> getAllFeedingEntries({
    required DateTime from,
    required DateTime before,
  });
  Future<List<FeedingEntryModel>> getPlannedFeedingEntries(
    String petId, {
    required DateTime fromDate,
    required DateTime toDate,
  });
  Future<List<FeedingEntryModel>> getAllPlannedFeedingEntries({
    required DateTime fromDate,
    required DateTime toDate,
  });
  Future<void> createFeedingEntry(FeedingEntryModel entry);
  Future<void> updateFeedingEntry(FeedingEntryModel entry);
  Future<void> deleteFeedingEntry(String petId, String entryId);
}

final class FeedingLocalDataSourceImpl implements FeedingLocalDataSource {
  final Database db;
  final DateTime Function() now;

  FeedingLocalDataSourceImpl(this.db, {this.now = DateTime.now});

  Future<T> _transaction<T>(Future<T> Function(Transaction) action) async {
    try {
      return await db.transaction(action);
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<List<FeedingPlanModel>> getFeedingPlans(String petId) =>
      _transaction((txn) => _readPlans(txn, petId: petId));

  @override
  Future<List<FeedingPlanModel>> getAllFeedingPlans() =>
      _transaction((txn) => _readPlans(txn));

  @override
  Future<FeedingPlanModel> getFeedingPlanById(String petId, String planId) =>
      _transaction((txn) async {
        final plans = await _readPlans(txn, petId: petId, planId: planId);
        if (plans.isEmpty) throw const LocalDataNotFoundException();
        return plans.single;
      });

  Future<List<FeedingPlanModel>> _readPlans(
    DatabaseExecutor txn, {
    String? petId,
    String? planId,
  }) async {
    final filters = [
      if (petId != null) 'p.pet_id = ?',
      if (planId != null) 'p.id = ?',
    ];
    final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    final args = [?petId, ?planId];
    final plans = await txn.rawQuery('''
      SELECT p.* FROM ${DatabaseTables.feedingPlans} p
      $where ORDER BY p.pet_id, p.start_date
    ''', args);
    if (plans.isEmpty) return [];
    final rows = await txn.rawQuery('''
      SELECT m.* FROM ${DatabaseTables.feedingMeals} m
      JOIN ${DatabaseTables.feedingPlans} p ON p.id = m.plan_id
      $where ORDER BY m.scheduled_minute
    ''', args);
    final meals = <String, List<FeedingMealModel>>{};
    for (final row in rows) {
      final meal = FeedingMealModel.fromJson(row);
      (meals[meal.planId] ??= []).add(meal);
    }
    return [
      for (final row in plans)
        FeedingPlanModel.fromJson(row, meals: meals[row['id']] ?? []),
    ];
  }

  @override
  Future<void> createFeedingPlan(FeedingPlanModel plan) =>
      _transaction((txn) async {
        final today = calendarDateKey(now());
        _validatePlan(plan);
        await _requirePet(txn, plan.petId);
        final existing = await txn.query(
          DatabaseTables.feedingPlans,
          columns: ['id'],
          where: 'pet_id = ?',
          whereArgs: [plan.petId],
          limit: 1,
        );
        final start = calendarDateKey(plan.startDate);
        if (start.compareTo(today) < 0 ||
            existing.isNotEmpty && start.compareTo(today) <= 0) {
          throw const LocalDataSourceException();
        }
        await txn.insert(DatabaseTables.feedingPlans, plan.toJson());
        for (final meal in plan.meals) {
          await txn.insert(DatabaseTables.feedingMeals, meal.toJson());
        }
        await _validatePreservedEntries(txn, plan.petId);
      });

  @override
  Future<void> updateFeedingPlan(FeedingPlanModel plan) => _transaction((
    txn,
  ) async {
    final current = now();
    final today = calendarDateKey(current);
    final plans = await _readPlans(txn, petId: plan.petId);
    final index = plans.indexWhere((value) => value.id == plan.id);
    if (index < 0) throw const LocalDataNotFoundException();
    final previous = plans[index];
    _validatePlan(plan);
    final recorded = await _hasEntries(txn, plan.id);
    final locked =
        calendarDateKey(previous.startDate).compareTo(today) <= 0 || recorded;
    if (locked) {
      if (calendarDateKey(previous.startDate) !=
              calendarDateKey(plan.startDate) ||
          !_sameMeals(previous.meals, plan.meals)) {
        throw const LocalDataSourceException();
      }
      final changedEnd = _endKey(previous) != _endKey(plan);
      if (changedEnd &&
          (!previous.toEntity().isActiveOn(
                current,
                nextPlanStart: index + 1 < plans.length
                    ? plans[index + 1].startDate
                    : null,
              ) ||
              plan.endDate != null &&
                  calendarDateKey(plan.endDate!).compareTo(today) < 0)) {
        throw const LocalDataSourceException();
      }
    } else {
      final start = calendarDateKey(plan.startDate);
      final startedOther = plans.any(
        (value) =>
            value.id != plan.id &&
            calendarDateKey(value.startDate).compareTo(today) <= 0,
      );
      if (start.compareTo(today) < 0 ||
          startedOther && start.compareTo(today) <= 0) {
        throw const LocalDataSourceException();
      }
    }
    await txn.update(
      DatabaseTables.feedingPlans,
      plan.toJson(),
      where: 'id = ? AND pet_id = ?',
      whereArgs: [plan.id, plan.petId],
    );
    if (!locked) {
      await txn.delete(
        DatabaseTables.feedingMeals,
        where: 'plan_id = ?',
        whereArgs: [plan.id],
      );
      for (final meal in plan.meals) {
        await txn.insert(DatabaseTables.feedingMeals, meal.toJson());
      }
    }
    await _validatePreservedEntries(txn, plan.petId);
  });

  @override
  Future<void> deleteFeedingPlan(String petId, String planId) =>
      _transaction((txn) async {
        final plans = await _readPlans(txn, petId: petId, planId: planId);
        if (plans.isEmpty) throw const LocalDataNotFoundException();
        if (calendarDateKey(
                  plans.single.startDate,
                ).compareTo(calendarDateKey(now())) <=
                0 ||
            await _hasEntries(txn, planId)) {
          throw const LocalDataSourceException();
        }
        await txn.delete(
          DatabaseTables.feedingPlans,
          where: 'id = ? AND pet_id = ?',
          whereArgs: [planId, petId],
        );
      });

  @override
  Future<List<FeedingEntryModel>> getFeedingEntries(
    String petId, {
    required DateTime from,
    required DateTime before,
  }) => _transaction(
    (txn) => _readActualEntries(txn, petId: petId, from: from, before: before),
  );

  @override
  Future<List<FeedingEntryModel>> getAllFeedingEntries({
    required DateTime from,
    required DateTime before,
  }) => _transaction(
    (txn) => _readActualEntries(txn, from: from, before: before),
  );

  Future<List<FeedingEntryModel>> _readActualEntries(
    DatabaseExecutor txn, {
    String? petId,
    required DateTime from,
    required DateTime before,
  }) {
    _validateInstant(from);
    _validateInstant(before);
    if (!from.isBefore(before)) throw const LocalDataSourceException();
    return _readEntries(
      txn,
      filters: [
        if (petId != null) 'pet_id = ?',
        'given_at >= ?',
        'given_at < ?',
      ],
      args: [?petId, instantKey(from), instantKey(before)],
    );
  }

  @override
  Future<List<FeedingEntryModel>> getPlannedFeedingEntries(
    String petId, {
    required DateTime fromDate,
    required DateTime toDate,
  }) => _transaction(
    (txn) => _readPlannedEntries(
      txn,
      petId: petId,
      fromDate: fromDate,
      toDate: toDate,
    ),
  );

  @override
  Future<List<FeedingEntryModel>> getAllPlannedFeedingEntries({
    required DateTime fromDate,
    required DateTime toDate,
  }) => _transaction(
    (txn) => _readPlannedEntries(txn, fromDate: fromDate, toDate: toDate),
  );

  Future<List<FeedingEntryModel>> _readPlannedEntries(
    DatabaseExecutor txn, {
    String? petId,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    _validateDate(fromDate);
    _validateDate(toDate);
    if (calendarDateKey(fromDate).compareTo(calendarDateKey(toDate)) > 0) {
      throw const LocalDataSourceException();
    }
    return _readEntries(
      txn,
      filters: [
        if (petId != null) 'pet_id = ?',
        'meal_id IS NOT NULL',
        'scheduled_date BETWEEN ? AND ?',
      ],
      args: [?petId, calendarDateKey(fromDate), calendarDateKey(toDate)],
    );
  }

  Future<List<FeedingEntryModel>> _readEntries(
    DatabaseExecutor txn, {
    required List<String> filters,
    required List<Object?> args,
  }) async => (await txn.query(
    DatabaseTables.feedingEntries,
    where: filters.join(' AND '),
    whereArgs: args,
    orderBy: 'given_at DESC, rowid DESC',
  )).map(FeedingEntryModel.fromJson).toList();

  @override
  Future<void> createFeedingEntry(FeedingEntryModel entry) =>
      _transaction((txn) async {
        await _validateEntry(txn, entry, now());
        await txn.insert(DatabaseTables.feedingEntries, entry.toJson());
      });

  @override
  Future<void> updateFeedingEntry(FeedingEntryModel entry) =>
      _transaction((txn) async {
        final current = now();
        final rows = await txn.query(
          DatabaseTables.feedingEntries,
          where: 'id = ? AND pet_id = ?',
          whereArgs: [entry.id, entry.petId],
          limit: 1,
        );
        if (rows.isEmpty) throw const LocalDataNotFoundException();
        final previous = FeedingEntryModel.fromJson(rows.single);
        if (previous.mealId != entry.mealId ||
            _scheduledKey(previous) != _scheduledKey(entry)) {
          throw const LocalDataSourceException();
        }
        await _validateEntry(txn, entry, current);
        await txn.update(
          DatabaseTables.feedingEntries,
          entry.toJson(),
          where: 'id = ? AND pet_id = ?',
          whereArgs: [entry.id, entry.petId],
        );
      });

  @override
  Future<void> deleteFeedingEntry(String petId, String entryId) =>
      _transaction((txn) async {
        final count = await txn.delete(
          DatabaseTables.feedingEntries,
          where: 'id = ? AND pet_id = ?',
          whereArgs: [entryId, petId],
        );
        if (count == 0) throw const LocalDataNotFoundException();
      });

  Future<void> _requirePet(DatabaseExecutor txn, String petId) async {
    final rows = await txn.query(
      DatabaseTables.pets,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [petId],
      limit: 1,
    );
    if (rows.isEmpty) throw const LocalDataNotFoundException();
  }

  void _validateAmount(double amount) {
    if (!amount.isFinite ||
        amount <= 0 ||
        amount != double.parse(amount.toStringAsFixed(1))) {
      throw const LocalDataSourceException();
    }
  }

  void _validateDate(DateTime value) {
    if (value.year < 1 || value.year > 9999) {
      throw const LocalDataSourceException();
    }
  }

  void _validateInstant(DateTime value) => _validateDate(value.toUtc());

  void _validateText(String? value, int limit) {
    if ((optionalText(value)?.characters.length ?? 0) > limit) {
      throw const LocalDataSourceException();
    }
  }

  void _validatePlan(FeedingPlanModel plan) {
    _validateDate(plan.startDate);
    if (plan.endDate != null) _validateDate(plan.endDate!);
    if (plan.id.trim().isEmpty ||
        plan.meals.isEmpty ||
        plan.endDate != null &&
            _endKey(plan)!.compareTo(calendarDateKey(plan.startDate)) < 0 ||
        plan.meals.map((meal) => meal.id).toSet().length != plan.meals.length ||
        plan.meals.map((meal) => meal.scheduledMinute).toSet().length !=
            plan.meals.length) {
      throw const LocalDataSourceException();
    }
    for (final meal in plan.meals) {
      if (meal.planId != plan.id) throw const LocalDataNotFoundException();
      if (meal.id.trim().isEmpty ||
          meal.scheduledMinute < 0 ||
          meal.scheduledMinute > 1439) {
        throw const LocalDataSourceException();
      }
      _validateAmount(meal.amountGrams);
      _validateText(meal.foodName, 50);
    }
  }

  Future<void> _validateEntry(
    DatabaseExecutor txn,
    FeedingEntryModel entry,
    DateTime current,
  ) async {
    _validateInstant(entry.givenAt);
    _validateAmount(entry.amountGrams);
    _validateText(entry.foodName, 50);
    _validateText(entry.notes, 200);
    if (entry.id.trim().isEmpty ||
        entry.givenAt.isAfter(current) ||
        (entry.mealId == null) != (entry.scheduledDate == null)) {
      throw const LocalDataSourceException();
    }
    await _requirePet(txn, entry.petId);
    if (entry.mealId == null) return;
    _validateDate(entry.scheduledDate!);
    final day = calendarDateKey(entry.scheduledDate!);
    if (day.compareTo(calendarDateKey(current)) > 0) {
      throw const LocalDataSourceException();
    }
    final rows = await txn.rawQuery(
      '''
      SELECT p.start_date, p.end_date,
        EXISTS (SELECT 1 FROM ${DatabaseTables.feedingPlans} successor
          WHERE successor.pet_id = p.pet_id AND successor.start_date > p.start_date
            AND successor.start_date <= ?) AS superseded
      FROM ${DatabaseTables.feedingMeals} m
      JOIN ${DatabaseTables.feedingPlans} p ON p.id = m.plan_id
      WHERE m.id = ? AND p.pet_id = ?
    ''',
      [day, entry.mealId, entry.petId],
    );
    if (rows.isEmpty) throw const LocalDataNotFoundException();
    final plan = rows.single;
    if (day.compareTo(plan['start_date'] as String) < 0 ||
        plan['end_date'] != null &&
            day.compareTo(plan['end_date'] as String) > 0 ||
        plan['superseded'] == 1) {
      throw const LocalDataSourceException();
    }
  }

  Future<bool> _hasEntries(DatabaseExecutor txn, String planId) async =>
      (await txn.rawQuery(
        '''
        SELECT 1 FROM ${DatabaseTables.feedingEntries} e
        JOIN ${DatabaseTables.feedingMeals} m ON m.id = e.meal_id
        WHERE m.plan_id = ? LIMIT 1
      ''',
        [planId],
      )).isNotEmpty;

  Future<void> _validatePreservedEntries(
    DatabaseExecutor txn,
    String petId,
  ) async {
    // Also protects recorded history if the device's clock has moved backwards.
    final invalid = await txn.rawQuery(
      '''
      SELECT 1 FROM ${DatabaseTables.feedingEntries} e
      JOIN ${DatabaseTables.feedingMeals} m ON m.id = e.meal_id
      JOIN ${DatabaseTables.feedingPlans} p ON p.id = m.plan_id
      WHERE e.pet_id = ? AND (
        p.pet_id != e.pet_id OR e.scheduled_date < p.start_date OR
        (p.end_date IS NOT NULL AND e.scheduled_date > p.end_date) OR
        EXISTS (SELECT 1 FROM ${DatabaseTables.feedingPlans} successor
          WHERE successor.pet_id = p.pet_id AND successor.start_date > p.start_date
            AND successor.start_date <= e.scheduled_date)
      ) LIMIT 1
    ''',
      [petId],
    );
    if (invalid.isNotEmpty) throw const LocalDataSourceException();
  }

  bool _sameMeals(List<FeedingMealModel> a, List<FeedingMealModel> b) =>
      a.length == b.length &&
      a.indexed.every((item) {
        final other = b[item.$1];
        final meal = item.$2;
        return meal.id == other.id &&
            meal.planId == other.planId &&
            meal.scheduledMinute == other.scheduledMinute &&
            meal.amountGrams == other.amountGrams &&
            optionalText(meal.foodName) == optionalText(other.foodName);
      });

  String? _endKey(FeedingPlanModel plan) =>
      plan.endDate == null ? null : calendarDateKey(plan.endDate!);
  String? _scheduledKey(FeedingEntryModel entry) => entry.scheduledDate == null
      ? null
      : calendarDateKey(entry.scheduledDate!);
}
