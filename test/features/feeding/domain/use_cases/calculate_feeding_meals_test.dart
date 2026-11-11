import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_meal.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';
import 'package:patilog/features/feeding/domain/use_cases/calculate_feeding_meals.dart';

void main() {
  const calculate = CalculateFeedingMeals();
  FeedingPlan plan(
    String id,
    String pet,
    DateTime start, {
    DateTime? end,
    int minute = 540,
  }) => FeedingPlan(
    id: id,
    petId: pet,
    startDate: start,
    endDate: end,
    meals: [
      FeedingMeal(
        id: '$id-meal',
        planId: id,
        scheduledMinute: minute,
        amountGrams: 20,
      ),
    ],
  );

  test(
    'bounded calendar range handles month/year/leap boundaries and open plans',
    () {
      for (final (start, end, count) in [
        (DateTime(2026, 12, 31), DateTime(2027, 1, 2), 3),
        (DateTime(2028, 2, 28), DateTime(2028, 3, 1), 3),
        (DateTime(2026, 3, 7), DateTime(2026, 3, 10), 4),
        (DateTime(2026, 10, 31), DateTime(2026, 11, 2), 3),
      ]) {
        final meals = calculate(
          plans: [plan('p', 'pet', start)],
          entries: [],
          fromDate: start,
          toDate: end,
        );
        expect(meals, hasLength(count));
        expect(meals.first.date, start);
        expect(meals.last.date, end);
        expect(meals.every((meal) => meal.entry == null), isTrue);
      }
    },
  );

  test(
    'a successor permanently replaces the previous schedule even after ending',
    () {
      final meals = calculate(
        plans: [
          plan(
            'next',
            'pet',
            DateTime(2026, 11, 2),
            end: DateTime(2026, 11, 2),
          ),
          plan('old', 'pet', DateTime(2026, 11, 1)),
        ],
        entries: [],
        fromDate: DateTime(2026, 10, 31),
        toDate: DateTime(2026, 11, 4),
      );
      expect(meals.map((meal) => meal.plan.id), ['old', 'next']);
      expect(meals.map((meal) => meal.date.day), [1, 2]);
      expect(() => meals.clear(), throwsUnsupportedError);
    },
  );

  test(
    'matching uses pet/meal/planned day, independent of actual time and snapshots',
    () {
      final date = DateTime(2026, 11, 1);
      final recorded = FeedingEntry(
        id: 'entry',
        petId: 'pet',
        amountGrams: 35.5,
        foodName: 'Changed food',
        givenAt: DateTime(2026, 11, 2, 1),
        mealId: 'p-meal',
        scheduledDate: date,
      );
      final meals = calculate(
        plans: [plan('p', 'pet', date)],
        entries: [
          recorded,
          FeedingEntry(
            id: 'manual',
            petId: 'pet',
            amountGrams: 10,
            givenAt: date,
          ),
          FeedingEntry(
            id: 'foreign',
            petId: 'other',
            amountGrams: 10,
            givenAt: date,
            mealId: 'p-meal',
            scheduledDate: date,
          ),
        ],
        fromDate: date,
        toDate: DateTime(2026, 11, 2),
      );
      expect(meals.first.entry, recorded);
      expect(meals.first.meal.amountGrams, 20);
      expect(meals.last.entry, isNull);
    },
  );

  test('all-pets occurrences sort by day/time with stable owner ties', () {
    final date = DateTime(2026, 11, 1);
    final meals = calculate(
      plans: [
        plan('b', 'pet-b', date),
        plan('a', 'pet-a', date),
        plan('early', 'pet-c', date, minute: 480),
      ],
      entries: [],
      fromDate: date,
      toDate: DateTime(2026, 11, 2),
    );
    expect(meals.map((meal) => (meal.date.day, meal.plan.petId)), [
      (1, 'pet-c'),
      (1, 'pet-a'),
      (1, 'pet-b'),
      (2, 'pet-c'),
      (2, 'pet-a'),
      (2, 'pet-b'),
    ]);
  });

  test('empty/reversed ranges produce no occurrences', () {
    final date = DateTime(2026, 11, 1);
    expect(
      calculate(plans: [], entries: [], fromDate: date, toDate: date),
      isEmpty,
    );
    expect(
      calculate(
        plans: [plan('p', 'pet', date)],
        entries: [],
        fromDate: DateTime(2026, 11, 2),
        toDate: date,
      ),
      isEmpty,
    );
  });
}
