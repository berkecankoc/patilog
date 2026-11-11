import 'package:equatable/equatable.dart';
import 'package:patilog/features/feeding/data/models/feeding_model_values.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_meal.dart';

final class FeedingMealModel extends Equatable {
  final String id;
  final String planId;
  final int scheduledMinute;
  final double amountGrams;
  final String? foodName;

  const FeedingMealModel({
    required this.id,
    required this.planId,
    required this.scheduledMinute,
    required this.amountGrams,
    this.foodName,
  });

  factory FeedingMealModel.fromJson(Map<String, dynamic> json) =>
      FeedingMealModel(
        id: json['id'] as String,
        planId: json['plan_id'] as String,
        scheduledMinute: json['scheduled_minute'] as int,
        amountGrams: (json['amount_grams'] as num).toDouble(),
        foodName: json['food_name'] as String?,
      );

  factory FeedingMealModel.fromEntity(FeedingMeal meal) => FeedingMealModel(
    id: meal.id,
    planId: meal.planId,
    scheduledMinute: meal.scheduledMinute,
    amountGrams: meal.amountGrams,
    foodName: meal.foodName,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_id': planId,
    'scheduled_minute': scheduledMinute,
    'amount_grams': amountGrams,
    'food_name': optionalText(foodName),
  };

  FeedingMeal toEntity() => FeedingMeal(
    id: id,
    planId: planId,
    scheduledMinute: scheduledMinute,
    amountGrams: amountGrams,
    foodName: foodName,
  );

  @override
  List<Object?> get props => [
    id,
    planId,
    scheduledMinute,
    amountGrams,
    foodName,
  ];
}
