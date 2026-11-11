import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/feeding/data/models/feeding_meal_model.dart';
import 'package:patilog/features/feeding/data/models/feeding_plan_model.dart';

void main() {
  test('calendar storage drops time without converting the calendar day', () {
    final model = FeedingPlanModel(
      id: 'plan',
      petId: 'pet',
      startDate: DateTime.utc(2026, 12, 31, 23),
      endDate: DateTime(2027, 1, 1, 1),
      meals: const [],
    );
    expect(model.toJson(), {
      'id': 'plan',
      'pet_id': 'pet',
      'start_date': '2026-12-31',
      'end_date': '2027-01-01',
    });
    final restored = FeedingPlanModel.fromJson(model.toJson(), meals: []);
    expect(restored.startDate, DateTime(2026, 12, 31));
    expect(restored.endDate, DateTime(2027, 1, 1));
  });

  test('nested meals survive entity conversion in immutable time order', () {
    final meals = [
      const FeedingMealModel(
        id: 'late',
        planId: 'plan',
        scheduledMinute: 1000,
        amountGrams: 30,
      ),
      const FeedingMealModel(
        id: 'early',
        planId: 'plan',
        scheduledMinute: 500,
        amountGrams: 20.5,
      ),
    ];
    final model = FeedingPlanModel(
      id: 'plan',
      petId: 'pet',
      startDate: DateTime(2026, 11, 1),
      meals: meals,
    );
    meals.clear();
    expect(model.meals.map((meal) => meal.id), ['early', 'late']);
    expect(() => model.meals.clear(), throwsUnsupportedError);
    expect(FeedingPlanModel.fromEntity(model.toEntity()), model);
    expect(
      FeedingPlanModel.fromJson(model.toJson(), meals: model.meals),
      model,
    );
    expect(model.toJson()['end_date'], isNull);
  });
}
