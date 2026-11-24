import 'package:equatable/equatable.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';
import 'package:patilog/features/notification/domain/entities/vaccination_reminder_schedule.dart';

final class NotificationPreferences extends Equatable {
  final bool medicationRemindersEnabled;
  final bool vaccinationRemindersEnabled;
  final bool feedingRemindersEnabled;
  final VaccinationReminderSchedule vaccinationSchedule;

  /// Categories already offered after saving a record, accepted or not; each
  /// category is offered at most once.
  final Set<ReminderCategory> offeredCategories;

  NotificationPreferences({
    this.medicationRemindersEnabled = false,
    this.vaccinationRemindersEnabled = false,
    this.feedingRemindersEnabled = false,
    VaccinationReminderSchedule? vaccinationSchedule,
    Set<ReminderCategory> offeredCategories = const {},
  }) : vaccinationSchedule =
           vaccinationSchedule ?? VaccinationReminderSchedule(),
       offeredCategories = Set.unmodifiable(offeredCategories);

  bool isEnabled(ReminderCategory category) => switch (category) {
    ReminderCategory.medication => medicationRemindersEnabled,
    ReminderCategory.vaccination => vaccinationRemindersEnabled,
    ReminderCategory.feeding => feedingRemindersEnabled,
  };

  /// Records the offer and, when accepted, enables only that category.
  NotificationPreferences answerOffer(
    ReminderCategory category, {
    required bool accepted,
  }) => NotificationPreferences(
    medicationRemindersEnabled:
        medicationRemindersEnabled ||
        accepted && category == ReminderCategory.medication,
    vaccinationRemindersEnabled:
        vaccinationRemindersEnabled ||
        accepted && category == ReminderCategory.vaccination,
    feedingRemindersEnabled:
        feedingRemindersEnabled ||
        accepted && category == ReminderCategory.feeding,
    vaccinationSchedule: vaccinationSchedule,
    offeredCategories: {...offeredCategories, category},
  );

  @override
  List<Object?> get props => [
    medicationRemindersEnabled,
    vaccinationRemindersEnabled,
    feedingRemindersEnabled,
    vaccinationSchedule,
    offeredCategories,
  ];
}
