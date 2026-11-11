import 'package:equatable/equatable.dart';
import 'package:patilog/features/feeding/data/models/feeding_model_values.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';

final class FeedingEntryModel extends Equatable {
  final String id;
  final String petId;
  final double amountGrams;
  final DateTime givenAt;
  final String? foodName;
  final String? notes;
  final String? mealId;
  final DateTime? scheduledDate;

  const FeedingEntryModel({
    required this.id,
    required this.petId,
    required this.amountGrams,
    required this.givenAt,
    this.foodName,
    this.notes,
    this.mealId,
    this.scheduledDate,
  });

  factory FeedingEntryModel.fromJson(Map<String, dynamic> json) =>
      FeedingEntryModel(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        amountGrams: (json['amount_grams'] as num).toDouble(),
        givenAt: DateTime.parse(json['given_at'] as String).toUtc(),
        foodName: json['food_name'] as String?,
        notes: json['notes'] as String?,
        mealId: json['meal_id'] as String?,
        scheduledDate: json['scheduled_date'] == null
            ? null
            : DateTime.parse(json['scheduled_date'] as String),
      );

  factory FeedingEntryModel.fromEntity(FeedingEntry entry) => FeedingEntryModel(
    id: entry.id,
    petId: entry.petId,
    amountGrams: entry.amountGrams,
    givenAt: entry.givenAt,
    foodName: entry.foodName,
    notes: entry.notes,
    mealId: entry.mealId,
    scheduledDate: entry.scheduledDate,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pet_id': petId,
    'amount_grams': amountGrams,
    'given_at': instantKey(givenAt),
    'food_name': optionalText(foodName),
    'notes': optionalText(notes),
    'meal_id': mealId,
    'scheduled_date': scheduledDate == null
        ? null
        : calendarDateKey(scheduledDate!),
  };

  FeedingEntry toEntity() => FeedingEntry(
    id: id,
    petId: petId,
    amountGrams: amountGrams,
    givenAt: givenAt,
    foodName: foodName,
    notes: notes,
    mealId: mealId,
    scheduledDate: scheduledDate,
  );

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
