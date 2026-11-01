import 'package:equatable/equatable.dart';

final class FeedingDailyTotal extends Equatable {
  final DateTime date;

  /// Null means no recorded feeding, not zero grams offered.
  final double? amountGrams;

  const FeedingDailyTotal({required this.date, this.amountGrams});

  @override
  List<Object?> get props => [date, amountGrams];
}
