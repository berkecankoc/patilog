import 'dart:math' as math;

import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';
import 'package:petlytics/features/notification/domain/entities/notification_data.dart';
import 'package:petlytics/features/notification/domain/entities/notification_plan.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/domain/entities/notification_reminder.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/notification/domain/repositories/notification_repository.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';

final class PlanNotificationReminders {
  const PlanNotificationReminders();

  // Text comes from the locale boundary; scheduling and identity stay pure Dart.
  NotificationPlan call(
    NotificationData data,
    NotificationPreferences preferences,
    DateTime now, {
    required MedicationReminderText medicationText,
    required VaccinationReminderText vaccinationText,
    required FeedingReminderText feedingText,
  }) {
    const limit = NotificationRepository.maxPendingReminders;
    final lastDay = calendarDayNumber(DateTime(9999, 12, 31));
    final pets = {for (final pet in data.pets) pet.id: pet.name};
    final candidates = <NotificationReminder>[];
    if (preferences.medicationRemindersEnabled) {
      final recorded = {
        for (final log in data.logs)
          (
            log.periodId,
            calendarDayNumber(log.scheduledDate),
            log.scheduledMinute,
          ),
      };
      for (final medication in data.medications) {
        final petName = pets[medication.petId];
        if (petName == null) continue;
        final upcoming = <NotificationReminder>[];
        for (var index = 0; index < medication.periods.length; index++) {
          final period = medication.periods[index];
          if (period.intervalDays <= 0 || period.doseTimes.isEmpty) continue;
          final start = calendarDayNumber(period.startDate);
          var day = math.max(start, calendarDayNumber(now));
          if (day > lastDay) continue;
          final remainder = (day - start) % period.intervalDays;
          if (remainder != 0) {
            final jump = period.intervalDays - remainder;
            if (jump > lastDay - day) continue;
            day += jump;
          }
          final nextStart = index + 1 < medication.periods.length
              ? calendarDayNumber(medication.periods[index + 1].startDate)
              : null;
          final end = period.endDate == null
              ? null
              : calendarDayNumber(period.endDate!);
          while (day <= lastDay &&
              (end == null || day <= end) &&
              (nextStart == null || day < nextStart)) {
            final date = _day(day);
            for (final minute in period.doseTimes) {
              if (!_time(date, minute).isAfter(now) ||
                  recorded.contains((period.id, day, minute))) {
                continue;
              }
              final text = medicationText(
                petName,
                medication.name,
                minute,
                period.dosageInstructions?.trim(),
              );
              upcoming.add(
                NotificationReminder(
                  target: MedicationDoseNotificationTarget(
                    petId: medication.petId,
                    medicationId: medication.id,
                    periodId: period.id,
                    scheduledDate: date,
                    scheduledMinute: minute,
                  ),
                  scheduledDate: date,
                  scheduledMinute: minute,
                  title: text.title,
                  body: text.body,
                ),
              );
            }
            // Finish the calendar day before bounding, including DST-normalized times.
            if (upcoming.length > limit) break;
            if (period.intervalDays > lastDay - day) break;
            day += period.intervalDays;
          }
          if (upcoming.length > limit) break;
        }
        upcoming.sort(_compare);
        candidates.addAll(upcoming.take(limit + 1));
      }
    }
    if (preferences.vaccinationRemindersEnabled) {
      for (final vaccination in data.vaccinations) {
        final petName = pets[vaccination.petId];
        if (petName == null ||
            vaccination.status != VaccinationStatus.planned) {
          continue;
        }
        final schedule = preferences.vaccinationSchedule;
        for (final offset in schedule.daysBefore) {
          final day = calendarDayNumber(vaccination.date) - offset;
          if (day < calendarDayNumber(now) || day > lastDay) continue;
          final date = _day(day);
          if (!_time(date, schedule.minuteOfDay).isAfter(now)) continue;
          final text = vaccinationText(
            petName,
            vaccination.vaccineName,
            vaccination.date,
          );
          candidates.add(
            NotificationReminder(
              target: VaccinationNotificationTarget(
                petId: vaccination.petId,
                vaccinationId: vaccination.id,
                daysBefore: offset,
              ),
              scheduledDate: date,
              scheduledMinute: schedule.minuteOfDay,
              title: text.title,
              body: text.body,
            ),
          );
        }
      }
    }
    if (preferences.feedingRemindersEnabled) {
      final recorded = {
        for (final entry in data.feedingEntries)
          if (entry.mealId != null && entry.scheduledDate != null)
            (
              entry.petId,
              entry.mealId,
              calendarDayNumber(entry.scheduledDate!),
            ),
      };
      for (final petId in pets.keys) {
        final plans = data.feedingPlans.where((p) => p.petId == petId).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
        for (final (index, plan) in plans.indexed) {
          final start = math.max(
            calendarDayNumber(now),
            calendarDayNumber(plan.startDate),
          );
          var end = plan.endDate == null
              ? lastDay
              : calendarDayNumber(plan.endDate!);
          if (index + 1 < plans.length) {
            end = math.min(
              end,
              calendarDayNumber(plans[index + 1].startDate) - 1,
            );
          }
          final upcoming = <NotificationReminder>[];
          for (var day = start; day <= end && upcoming.length <= limit; day++) {
            final date = _day(day);
            for (final meal in plan.meals) {
              if (!_time(date, meal.scheduledMinute).isAfter(now) ||
                  recorded.contains((petId, meal.id, day))) {
                continue;
              }
              final text = feedingText(
                pets[petId]!,
                meal.scheduledMinute,
                meal.amountGrams,
                meal.foodName,
              );
              upcoming.add(
                NotificationReminder(
                  target: FeedingMealNotificationTarget(
                    petId: petId,
                    planId: plan.id,
                    mealId: meal.id,
                    scheduledDate: date,
                    scheduledMinute: meal.scheduledMinute,
                  ),
                  scheduledDate: date,
                  scheduledMinute: meal.scheduledMinute,
                  title: text.title,
                  body: text.body,
                ),
              );
            }
            if (plan.meals.isEmpty) break;
          }
          upcoming.sort(_compare);
          candidates.addAll(upcoming.take(limit + 1));
        }
      }
    }
    candidates.sort(_compare);
    return NotificationPlan(
      reminders: candidates.take(limit).toList(),
      hasMore: candidates.length > limit,
    );
  }

  static DateTime _day(int number) {
    final utc = DateTime.fromMillisecondsSinceEpoch(
      number * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return DateTime(utc.year, utc.month, utc.day);
  }

  static DateTime _time(DateTime date, int minute) =>
      DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);

  static int _compare(NotificationReminder a, NotificationReminder b) {
    final time = _time(
      a.scheduledDate,
      a.scheduledMinute,
    ).compareTo(_time(b.scheduledDate, b.scheduledMinute));
    return time != 0
        ? time
        : a.target.identityKey.compareTo(b.target.identityKey);
  }
}
