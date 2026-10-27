import 'package:equatable/equatable.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';

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
