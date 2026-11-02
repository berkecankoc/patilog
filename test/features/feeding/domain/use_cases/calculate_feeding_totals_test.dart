import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/use_cases/calculate_feeding_totals.dart';

void main() {
  const calculate = CalculateFeedingTotals();

  test(
    'actual local days determine totals; planned days and other pets do not',
    () {
      final totals = calculate(
        petId: 'pet',
        entries: [
          FeedingEntry(
            id: 'late',
            petId: 'pet',
            amountGrams: 20,
            givenAt: DateTime(2027, 1, 1, 0, 1).toUtc(),
            mealId: 'meal',
            scheduledDate: DateTime(2026, 12, 31),
          ),
          FeedingEntry(
            id: 'manual',
            petId: 'pet',
            amountGrams: 5.5,
            givenAt: DateTime(2027, 1, 1, 23, 59).toUtc(),
          ),
          FeedingEntry(
            id: 'other',
            petId: 'other',
            amountGrams: 100,
            givenAt: DateTime(2027, 1, 1, 12),
          ),
          FeedingEntry(
            id: 'outside',
            petId: 'pet',
            amountGrams: 100,
            givenAt: DateTime(2027, 1, 3),
          ),
        ],
        fromDate: DateTime(2026, 12, 31),
        toDate: DateTime(2027, 1, 2),
      );
      expect(totals.map((day) => day.amountGrams), [null, 25.5, null]);
      expect(totals.map((day) => day.date), [
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 1),
        DateTime(2027, 1, 2),
      ]);
      expect(() => totals.clear(), throwsUnsupportedError);
    },
  );

  test('totals retain one decimal and unknown is not zero', () {
    final date = DateTime(2026, 11, 1);
    final totals = calculate(
      petId: 'pet',
      entries: [
        FeedingEntry(id: 'a', petId: 'pet', amountGrams: 0.1, givenAt: date),
        FeedingEntry(id: 'b', petId: 'pet', amountGrams: 0.2, givenAt: date),
      ],
      fromDate: date,
      toDate: DateTime(2026, 11, 2),
    );
    expect(totals.first.amountGrams, 0.3);
    expect(totals.last.amountGrams, isNull);
  });

  test('finite gram amounts are not clamped by an integer conversion', () {
    final date = DateTime(2026, 11, 1);
    final total = calculate(
      petId: 'pet',
      entries: [
        FeedingEntry(
          id: 'large',
          petId: 'pet',
          amountGrams: 1e20,
          givenAt: date,
        ),
      ],
      fromDate: date,
      toDate: date,
    ).single;
    expect(total.amountGrams, 1e20);
  });

  test(
    'empty data still describes every requested day; reversed range is empty',
    () {
      final date = DateTime(2026, 11, 1);
      expect(
        calculate(
          petId: 'pet',
          entries: [],
          fromDate: date,
          toDate: DateTime(2026, 11, 30),
        ),
        hasLength(30),
      );
      expect(
        calculate(
          petId: 'pet',
          entries: [],
          fromDate: DateTime(2026, 11, 2),
          toDate: date,
        ),
        isEmpty,
      );
    },
  );
}
