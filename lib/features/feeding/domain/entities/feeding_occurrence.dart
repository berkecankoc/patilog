import 'package:equatable/equatable.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_meal.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';

/// A calculated meal/day, not a persisted row. A null entry means no record
/// only after the caller has successfully loaded that day's results.
final class FeedingOccurrence extends Equatable {
  final FeedingPlan plan;
  final FeedingMeal meal;
  final DateTime date;
  final FeedingEntry? entry;

  const FeedingOccurrence({
    required this.plan,
    required this.meal,
    required this.date,
    this.entry,
  });

  @override
  List<Object?> get props => [plan, meal, date, entry];
}
