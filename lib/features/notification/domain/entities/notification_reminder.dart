import 'package:equatable/equatable.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';

typedef NotificationText = ({String title, String body});
typedef MedicationReminderText =
    NotificationText Function(
      String petName,
      String medicationName,
      int minute,
      String? instructions,
    );
typedef VaccinationReminderText =
    NotificationText Function(
      String petName,
      String vaccineName,
      DateTime date,
    );
typedef FeedingReminderText =
    NotificationText Function(
      String petName,
      int minute,
      double amountGrams,
      String? foodName,
    );

final class NotificationReminder extends Equatable {
  final NotificationTarget target;

  /// Local calendar day and minute, resolved in the device time zone on schedule.
  final DateTime scheduledDate;
  final int scheduledMinute;
  final String title;
  final String body;

  const NotificationReminder({
    required this.target,
    required this.scheduledDate,
    required this.scheduledMinute,
    required this.title,
    required this.body,
  });

  @override
  List<Object?> get props => [
    target,
    scheduledDate.year,
    scheduledDate.month,
    scheduledDate.day,
    scheduledMinute,
    title,
    body,
  ];
}
