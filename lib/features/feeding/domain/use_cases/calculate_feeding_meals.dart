import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_occurrence.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';
import 'package:patilog/features/feeding/domain/utils/feeding_calendar.dart';

final class CalculateFeedingMeals {
  const CalculateFeedingMeals();

  List<FeedingOccurrence> call({
    required List<FeedingPlan> plans,
    required List<FeedingEntry> entries,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final versions = <String, List<FeedingPlan>>{};
    for (final plan in plans) {
      (versions[plan.petId] ??= []).add(plan);
    }
    for (final group in versions.values) {
      group.sort(
        (a, b) => feedingDayNumber(
          a.startDate,
        ).compareTo(feedingDayNumber(b.startDate)),
      );
    }
    final recorded = {
      for (final entry in entries)
        if (entry.mealId != null && entry.scheduledDate != null)
          (entry.petId, entry.mealId, feedingDayNumber(entry.scheduledDate!)):
              entry,
    };
    final meals = <FeedingOccurrence>[];
    final last = DateTime.utc(toDate.year, toDate.month, toDate.day);
    // Iterate only the requested days, even when plans have no end date.
    for (
      var day = DateTime.utc(fromDate.year, fromDate.month, fromDate.day);
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      final date = DateTime(day.year, day.month, day.day);
      for (final group in versions.values) {
        final plan = group
            .where(
              (p) => feedingDayNumber(p.startDate) <= feedingDayNumber(date),
            )
            .lastOrNull;
        if (plan == null || !plan.isActiveOn(date)) continue;
        for (final meal in plan.meals) {
          meals.add(
            FeedingOccurrence(
              plan: plan,
              meal: meal,
              date: date,
              entry: recorded[(plan.petId, meal.id, feedingDayNumber(date))],
            ),
          );
        }
      }
    }
    meals.sort((a, b) {
      final date = feedingDayNumber(a.date).compareTo(feedingDayNumber(b.date));
      if (date != 0) return date;
      final minute = a.meal.scheduledMinute.compareTo(b.meal.scheduledMinute);
      if (minute != 0) return minute;
      final pet = a.plan.petId.compareTo(b.plan.petId);
      return pet != 0 ? pet : a.meal.id.compareTo(b.meal.id);
    });
    return List.unmodifiable(meals);
  }
}
