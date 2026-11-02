import 'package:equatable/equatable.dart';
import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';

final class NotificationPreferences extends Equatable {
  final bool medicationRemindersEnabled;
  final bool vaccinationRemindersEnabled;
  final bool feedingRemindersEnabled;
  final VaccinationReminderSchedule vaccinationSchedule;

  NotificationPreferences({
    this.medicationRemindersEnabled = false,
    this.vaccinationRemindersEnabled = false,
    this.feedingRemindersEnabled = false,
    VaccinationReminderSchedule? vaccinationSchedule,
  }) : vaccinationSchedule =
           vaccinationSchedule ?? VaccinationReminderSchedule();

  @override
  List<Object?> get props => [
    medicationRemindersEnabled,
    vaccinationRemindersEnabled,
    feedingRemindersEnabled,
    vaccinationSchedule,
  ];
}
