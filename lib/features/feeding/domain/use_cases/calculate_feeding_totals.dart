import 'package:patilog/features/feeding/domain/entities/feeding_daily_total.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/domain/utils/feeding_calendar.dart';

final class CalculateFeedingTotals {
  const CalculateFeedingTotals();

  List<FeedingDailyTotal> call({
    required String petId,
    required List<FeedingEntry> entries,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final amounts = <int, double>{};
    for (final entry in entries.where((entry) => entry.petId == petId)) {
      final day = feedingDayNumber(entry.givenAt.toLocal());
      amounts.update(
        day,
        (value) => value + entry.amountGrams,
        ifAbsent: () => entry.amountGrams,
      );
    }
    final totals = <FeedingDailyTotal>[];
    final last = DateTime.utc(toDate.year, toDate.month, toDate.day);
    for (
      var day = DateTime.utc(fromDate.year, fromDate.month, fromDate.day);
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      final amount = amounts[feedingDayNumber(day)];
      totals.add(
        FeedingDailyTotal(
          date: DateTime(day.year, day.month, day.day),
          amountGrams: amount == null
              ? null
              : double.parse(amount.toStringAsFixed(1)),
        ),
      );
    }
    return List.unmodifiable(totals);
  }
}
