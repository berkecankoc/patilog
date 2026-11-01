import 'package:equatable/equatable.dart';

final class FeedingEntry extends Equatable {
  final String id;
  final String petId;

  /// Food offered, in grams. This and foodName are independent record snapshots.
  final double amountGrams;

  /// Actual nonfuture instant, independent of the planned meal's calendar day.
  final DateTime givenAt;
  final String? foodName;
  final String? notes;

  /// Both present for a planned meal; both null for a manual entry.
  /// Together they identify the occurrence and survive amount/time corrections.
  /// scheduledDate preserves calendar components without UTC conversion.
  final String? mealId;
  final DateTime? scheduledDate;

  const FeedingEntry({
    required this.id,
    required this.petId,
    required this.amountGrams,
    required this.givenAt,
    this.foodName,
    this.notes,
    this.mealId,
    this.scheduledDate,
  });

  @override
  List<Object?> get props => [
    id,
    petId,
    amountGrams,
    givenAt,
    foodName,
    notes,
    mealId,
    scheduledDate,
  ];
}
