import 'package:equatable/equatable.dart';

/// Scheduling permissions do not guarantee notification delivery timing.
final class NotificationPermissionStatus extends Equatable {
  final bool canShowNotifications;
  final bool canScheduleExactAlarms;
  final bool requiresExactAlarmPermission;

  /// Categories the user turned off in system settings (Android channels),
  /// independently of the app's own reminder preferences.
  final bool medicationRemindersBlocked;
  final bool vaccinationRemindersBlocked;
  final bool feedingRemindersBlocked;

  const NotificationPermissionStatus({
    required this.canShowNotifications,
    required this.canScheduleExactAlarms,
    required this.requiresExactAlarmPermission,
    this.medicationRemindersBlocked = false,
    this.vaccinationRemindersBlocked = false,
    this.feedingRemindersBlocked = false,
  });

  @override
  List<Object?> get props => [
    canShowNotifications,
    canScheduleExactAlarms,
    requiresExactAlarmPermission,
    medicationRemindersBlocked,
    vaccinationRemindersBlocked,
    feedingRemindersBlocked,
  ];
}
