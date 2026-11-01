import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_meal.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';

void main() {
  const morning = FeedingMeal(
    id: 'morning',
    planId: 'plan',
    scheduledMinute: 480,
    amountGrams: 30,
    foodName: 'Dry food',
  );
  const evening = FeedingMeal(
    id: 'evening',
    planId: 'plan',
    scheduledMinute: 1200,
    amountGrams: 40,
  );

  FeedingPlan plan({
    List<FeedingMeal> meals = const [morning, evening],
    DateTime? endDate,
  }) => FeedingPlan(
    id: 'plan',
    petId: 'pet',
    startDate: DateTime(2026, 11, 1),
    endDate: endDate,
    meals: meals,
  );

  test(
    'meal ordering is canonical without mutating or sharing the caller list',
    () {
      final meals = [evening, morning];
      final loaded = plan(meals: meals);
      expect(loaded.meals, [morning, evening]);
      expect(meals, [evening, morning]);
      meals.clear();
      expect(loaded.meals, [morning, evening]);
      expect(() => loaded.meals.clear(), throwsUnsupportedError);
    },
  );

  test(
    'duplicate times are retained for write validation rather than discarded',
    () {
      const duplicate = FeedingMeal(
        id: 'other-meal',
        planId: 'plan',
        scheduledMinute: 480,
        amountGrams: 20,
      );
      expect(plan(meals: [morning, duplicate]).meals, hasLength(2));
    },
  );

  test(
    'the active window uses inclusive calendar days without time conversion',
    () {
      final loaded = plan(endDate: DateTime(2026, 11, 3));
      expect(loaded.isActiveOn(DateTime(2026, 10, 31)), isFalse);
      expect(loaded.isActiveOn(DateTime.utc(2026, 11, 1, 23)), isTrue);
      expect(loaded.isActiveOn(DateTime(2026, 11, 3, 23, 59)), isTrue);
      expect(loaded.isActiveOn(DateTime(2026, 11, 4)), isFalse);
    },
  );

  test('the successor truncates an earlier plan across a year boundary', () {
    final first = FeedingPlan(
      id: 'old',
      petId: 'pet',
      startDate: DateTime(2026, 12, 1),
      meals: const [
        FeedingMeal(
          id: 'old-meal',
          planId: 'old',
          scheduledMinute: 480,
          amountGrams: 30,
        ),
      ],
    );
    final next = DateTime(2027, 1, 1);
    expect(
      first.isActiveOn(DateTime(2026, 12, 31), nextPlanStart: next),
      isTrue,
    );
    expect(first.isActiveOn(next, nextPlanStart: next), isFalse);
    expect(first.isActiveOn(DateTime(2027, 2), nextPlanStart: next), isFalse);
    expect(
      plan(endDate: DateTime(2027, 2, 1)).isActiveOn(next, nextPlanStart: next),
      isFalse,
    );
  });

  test('same-ID plan revisions detect changed meal amounts and food names', () {
    expect(plan(), plan());
    for (final changed in [
      const FeedingMeal(
        id: 'morning',
        planId: 'plan',
        scheduledMinute: 480,
        amountGrams: 30.5,
        foodName: 'Dry food',
      ),
      const FeedingMeal(
        id: 'morning',
        planId: 'plan',
        scheduledMinute: 480,
        amountGrams: 30,
        foodName: 'Wet food',
      ),
    ]) {
      expect(plan(meals: [changed, evening]), isNot(plan()));
    }
  });
}
