import 'package:equatable/equatable.dart';
import 'package:petlytics/features/notification/domain/entities/notification_reminder.dart';

final class NotificationPlan extends Equatable {
  final List<NotificationReminder> reminders;

  /// The native queue covers only this prefix; reopening/resync fills it again.
  final bool hasMore;

  NotificationPlan({
    required List<NotificationReminder> reminders,
    required this.hasMore,
  }) : reminders = List.unmodifiable(reminders);

  DateTime? get nextRefreshAt =>
      reminders.isEmpty ? null : _time(reminders.first);
  DateTime? get scheduledThrough =>
      reminders.isEmpty ? null : _time(reminders.last);

  static DateTime _time(NotificationReminder reminder) => DateTime(
    reminder.scheduledDate.year,
    reminder.scheduledDate.month,
    reminder.scheduledDate.day,
    reminder.scheduledMinute ~/ 60,
    reminder.scheduledMinute % 60,
  );

  @override
  List<Object?> get props => [reminders, hasMore];
}
