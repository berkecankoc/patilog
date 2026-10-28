import 'package:equatable/equatable.dart';

/// Scheduling permissions do not guarantee notification delivery timing.
final class NotificationPermissionStatus extends Equatable {
  final bool canShowNotifications;
  final bool canScheduleExactAlarms;
  final bool requiresExactAlarmPermission;

  const NotificationPermissionStatus({
    required this.canShowNotifications,
    required this.canScheduleExactAlarms,
    required this.requiresExactAlarmPermission,
  });

  @override
  List<Object?> get props => [
    canShowNotifications,
    canScheduleExactAlarms,
    requiresExactAlarmPermission,
  ];
}
