import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';

void main() {
  FeedingEntry entry({
    String petId = 'pet',
    String mealId = 'meal',
    DateTime? scheduledDate,
    double amountGrams = 30,
    DateTime? givenAt,
    String? foodName = 'Dry food',
    String? notes,
  }) => FeedingEntry(
    id: 'entry',
    petId: petId,
    mealId: mealId,
    scheduledDate: scheduledDate ?? DateTime(2026, 11, 1),
    amountGrams: amountGrams,
    givenAt: givenAt ?? DateTime.utc(2026, 11, 1, 5),
    foodName: foodName,
    notes: notes,
  );

  test(
    'correcting a record changes its value while retaining the planned occurrence',
    () {
      final original = entry();
      final corrected = entry(
        amountGrams: 25.5,
        givenAt: DateTime.utc(2026, 11, 1, 6),
      );
      expect(original, entry());
      expect(corrected, isNot(original));
      expect(corrected.id, original.id);
      expect(corrected.mealId, original.mealId);
      expect(corrected.scheduledDate, original.scheduledDate);
      expect(entry(foodName: 'Wet food'), isNot(original));
      expect(entry(notes: 'Extra portion'), isNot(original));
    },
  );

  test('pet, meal and scheduled day distinguish recorded occurrences', () {
    expect(entry(petId: 'other-pet'), isNot(entry()));
    expect(entry(mealId: 'other-meal'), isNot(entry()));
    expect(entry(scheduledDate: DateTime(2026, 11, 2)), isNot(entry()));
  });
}
