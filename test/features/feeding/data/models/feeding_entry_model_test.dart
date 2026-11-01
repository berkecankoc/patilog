import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/feeding/data/models/feeding_entry_model.dart';

void main() {
  test(
    'actual instants serialize at fixed UTC precision for lexical ranges',
    () {
      final instant = DateTime.parse('2026-11-01T09:00:00.123456+03:00');
      final model = FeedingEntryModel(
        id: 'entry',
        petId: 'pet',
        amountGrams: 25.5,
        givenAt: instant,
        mealId: 'meal',
        scheduledDate: DateTime.utc(2026, 10, 31, 23),
        foodName: ' Food ',
        notes: ' Note ',
      );
      final json = model.toJson();
      expect(json['given_at'], '2026-11-01T06:00:00.123456Z');
      expect(json['scheduled_date'], '2026-10-31');
      expect(json['food_name'], 'Food');
      expect(json['notes'], 'Note');
      final restored = FeedingEntryModel.fromJson(json);
      expect(restored.givenAt, instant);
      expect(restored.givenAt.isUtc, isTrue);
      expect(restored.scheduledDate, DateTime(2026, 10, 31));
      expect(FeedingEntryModel.fromEntity(restored.toEntity()), restored);
    },
  );

  test('manual entries keep null links/text and six fractional digits', () {
    final model = FeedingEntryModel(
      id: 'entry',
      petId: 'pet',
      amountGrams: 10,
      givenAt: DateTime.utc(2026, 11, 1, 6, 0, 0, 123),
      notes: '  ',
    );
    final json = model.toJson();
    expect(json['given_at'], '2026-11-01T06:00:00.123000Z');
    expect(json['meal_id'], isNull);
    expect(json['scheduled_date'], isNull);
    expect(json['notes'], isNull);
    final restored = FeedingEntryModel.fromJson(json);
    expect(restored.givenAt, model.givenAt);
    expect(restored.notes, isNull);
    expect(restored.mealId, isNull);
    expect(
      FeedingEntryModel.fromJson({...json, 'amount_grams': 10}).amountGrams,
      10.0,
    );
  });
}
