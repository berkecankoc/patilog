import 'dart:convert';

import 'package:equatable/equatable.dart';

sealed class NotificationTarget extends Equatable {
  final String petId;

  const NotificationTarget({required this.petId});

  /// Stable source identity, independent of display text and native integer IDs.
  String get identityKey;
}

final class MedicationDoseNotificationTarget extends NotificationTarget {
  final String medicationId;
  final String periodId;

  /// Calendar components identify the dose; do not convert the date to UTC.
  final DateTime scheduledDate;
  final int scheduledMinute;

  const MedicationDoseNotificationTarget({
    required super.petId,
    required this.medicationId,
    required this.periodId,
    required this.scheduledDate,
    required this.scheduledMinute,
  });

  @override
  String get identityKey => jsonEncode(['dose', ...props]);

  @override
  List<Object?> get props => [
    petId,
    medicationId,
    periodId,
    scheduledDate.year,
    scheduledDate.month,
    scheduledDate.day,
    scheduledMinute,
  ];
}

final class VaccinationNotificationTarget extends NotificationTarget {
  final String vaccinationId;
  final int daysBefore;

  const VaccinationNotificationTarget({
    required super.petId,
    required this.vaccinationId,
    required this.daysBefore,
  });

  @override
  String get identityKey => jsonEncode(['vaccination', ...props]);

  @override
  List<Object?> get props => [petId, vaccinationId, daysBefore];
}

final class FeedingMealNotificationTarget extends NotificationTarget {
  final String planId;
  final String mealId;
  final DateTime scheduledDate;
  final int scheduledMinute;

  const FeedingMealNotificationTarget({
    required super.petId,
    required this.planId,
    required this.mealId,
    required this.scheduledDate,
    required this.scheduledMinute,
  });

  @override
  String get identityKey => jsonEncode(['feeding', ...props]);

  @override
  List<Object?> get props => [
    petId,
    planId,
    mealId,
    scheduledDate.year,
    scheduledDate.month,
    scheduledDate.day,
    scheduledMinute,
  ];
}
