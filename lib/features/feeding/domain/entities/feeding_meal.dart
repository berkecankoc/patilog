import 'package:equatable/equatable.dart';

final class FeedingMeal extends Equatable {
  final String id;
  final String planId;

  /// Local minutes since midnight (0–1439), independent of UTC offsets.
  final int scheduledMinute;
  final double amountGrams;
  final String? foodName;

  const FeedingMeal({
    required this.id,
    required this.planId,
    required this.scheduledMinute,
    required this.amountGrams,
    this.foodName,
  });

  @override
  List<Object?> get props => [
    id,
    planId,
    scheduledMinute,
    amountGrams,
    foodName,
  ];
}
