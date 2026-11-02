import 'package:equatable/equatable.dart';
import 'package:petlytics/features/feeding/data/models/feeding_meal_model.dart';
import 'package:petlytics/features/feeding/data/models/feeding_model_values.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';

final class FeedingPlanModel extends Equatable {
  final String id;
  final String petId;
  final DateTime startDate;
  final DateTime? endDate;
  final List<FeedingMealModel> meals;

  FeedingPlanModel({
    required this.id,
    required this.petId,
    required this.startDate,
    this.endDate,
    required List<FeedingMealModel> meals,
  }) : meals = List.unmodifiable(
         List<FeedingMealModel>.of(meals)
           ..sort((a, b) => a.scheduledMinute.compareTo(b.scheduledMinute)),
       );

  factory FeedingPlanModel.fromJson(
    Map<String, dynamic> json, {
    required List<FeedingMealModel> meals,
  }) => FeedingPlanModel(
    id: json['id'] as String,
    petId: json['pet_id'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'] as String),
    meals: meals,
  );

  factory FeedingPlanModel.fromEntity(FeedingPlan plan) => FeedingPlanModel(
    id: plan.id,
    petId: plan.petId,
    startDate: plan.startDate,
    endDate: plan.endDate,
    meals: plan.meals.map(FeedingMealModel.fromEntity).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pet_id': petId,
    'start_date': calendarDateKey(startDate),
    'end_date': endDate == null ? null : calendarDateKey(endDate!),
  };

  FeedingPlan toEntity() => FeedingPlan(
    id: id,
    petId: petId,
    startDate: startDate,
    endDate: endDate,
    meals: meals.map((meal) => meal.toEntity()).toList(),
  );

  @override
  List<Object?> get props => [id, petId, startDate, endDate, meals];
}
