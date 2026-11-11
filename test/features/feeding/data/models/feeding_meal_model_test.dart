import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/feeding/data/models/feeding_meal_model.dart';

void main() {
  test(
    'SQLite numeric amounts and entity conversions retain meal identity',
    () {
      final model = FeedingMealModel.fromJson({
        'id': 'meal',
        'plan_id': 'plan',
        'scheduled_minute': 540,
        'amount_grams': 25,
        'food_name': 'Dry food',
      });
      expect(model.amountGrams, 25.0);
      expect(FeedingMealModel.fromEntity(model.toEntity()), model);
      expect(model.toJson()['scheduled_minute'], 540);
    },
  );

  test('storage trims optional names without rounding unvalidated amounts', () {
    const model = FeedingMealModel(
      id: 'meal',
      planId: 'plan',
      scheduledMinute: 540,
      amountGrams: 25.55,
      foodName: '  Dry food  ',
    );
    expect(model.toJson()['food_name'], 'Dry food');
    expect(model.toJson()['amount_grams'], 25.55);
    expect(
      const FeedingMealModel(
        id: 'meal',
        planId: 'plan',
        scheduledMinute: 0,
        amountGrams: 1,
        foodName: ' \n ',
      ).toJson()['food_name'],
      isNull,
    );
  });
}
