import 'dart:convert';

import 'package:patilog/features/notification/domain/entities/notification_target.dart';

abstract final class NotificationTargetCodec {
  static const _prefix = 'patilog.reminder.v1:';

  static bool isOwned(String? payload) => payload?.startsWith(_prefix) ?? false;

  static String encode(NotificationTarget target) {
    final payload = '$_prefix${target.identityKey}';
    if (decode(payload) == null) {
      throw const FormatException('Invalid notification target');
    }
    return payload;
  }

  static NotificationTarget? decode(String? payload) {
    if (!isOwned(payload)) return null;
    try {
      return switch (jsonDecode(payload!.substring(_prefix.length))) {
        [
          'dose',
          String pet,
          String medication,
          String period,
          int year,
          int month,
          int day,
          int minute,
        ]
            when _id(pet) &&
                _id(medication) &&
                _id(period) &&
                _date(year, month, day) &&
                minute >= 0 &&
                minute < 1440 =>
          MedicationDoseNotificationTarget(
            petId: pet,
            medicationId: medication,
            periodId: period,
            scheduledDate: DateTime(year, month, day),
            scheduledMinute: minute,
          ),
        ['vaccination', String pet, String vaccination, int days]
            when _id(pet) && _id(vaccination) && days >= 0 =>
          VaccinationNotificationTarget(
            petId: pet,
            vaccinationId: vaccination,
            daysBefore: days,
          ),
        [
          'feeding',
          String pet,
          String plan,
          String meal,
          int year,
          int month,
          int day,
          int minute,
        ]
            when _id(pet) &&
                _id(plan) &&
                _id(meal) &&
                _date(year, month, day) &&
                minute >= 0 &&
                minute < 1440 =>
          FeedingMealNotificationTarget(
            petId: pet,
            planId: plan,
            mealId: meal,
            scheduledDate: DateTime(year, month, day),
            scheduledMinute: minute,
          ),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  static bool _id(String id) => id.trim().isNotEmpty;

  static bool _date(int year, int month, int day) {
    if (year < 1 ||
        year > 9999 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return false;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }
}
