import 'package:equatable/equatable.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_meal.dart';

/// One version of a pet's daily meal plan.
final class FeedingPlan extends Equatable {
  final String id;
  final String petId;

  /// Calendar dates without UTC conversion. End is inclusive; a successor
  /// takes over from its start even when this end is absent or later.
  final DateTime startDate;
  final DateTime? endDate;
  final List<FeedingMeal> meals;

  FeedingPlan({
    required this.id,
    required this.petId,
    required this.startDate,
    this.endDate,
    required List<FeedingMeal> meals,
  }) : meals = List.unmodifiable(
         List<FeedingMeal>.of(meals)
           ..sort((a, b) => a.scheduledMinute.compareTo(b.scheduledMinute)),
       );

  bool isActiveOn(DateTime date, {DateTime? nextPlanStart}) {
    final day = _calendarDay(date);
    return !day.isBefore(_calendarDay(startDate)) &&
        (endDate == null || !day.isAfter(_calendarDay(endDate!))) &&
        (nextPlanStart == null || day.isBefore(_calendarDay(nextPlanStart)));
  }

  static DateTime _calendarDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  List<Object?> get props => [id, petId, startDate, endDate, meals];
}
