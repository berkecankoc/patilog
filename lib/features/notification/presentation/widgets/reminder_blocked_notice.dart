import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_state.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

/// Explains that an enabled reminder category cannot be delivered because the
/// device blocks notifications. Add it to the screen's AppFeedbackArea when
/// [shows] is true.
class ReminderBlockedNotice extends StatelessWidget {
  final ReminderCategory category;
  const ReminderBlockedNotice({super.key, required this.category});

  /// [hasReminders] is true when the screen shows records that can still
  /// remind. Screens without the app-level runtime (isolated tests) never show
  /// the notice.
  static bool shows(
    BuildContext context,
    ReminderCategory category, {
    required bool hasReminders,
  }) {
    final blocked = context.select<NotificationCubit?, bool>(
      (cubit) => cubit != null && _blocked(cubit.state, category),
    );
    return blocked && hasReminders;
  }

  static bool _blocked(NotificationState state, ReminderCategory category) {
    final permissions = state.permissions;
    if (state.preferences?.isEnabled(category) != true || permissions == null) {
      return false;
    }
    return !permissions.canShowNotifications ||
        switch (category) {
          ReminderCategory.medication => permissions.medicationRemindersBlocked,
          ReminderCategory.vaccination =>
            permissions.vaccinationRemindersBlocked,
          ReminderCategory.feeding => permissions.feedingRemindersBlocked,
        };
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final cubit = context.read<NotificationCubit>();
    // Only an Android category channel can be off while notifications are on.
    final appWide = context.select<NotificationCubit, bool>(
      (cubit) => cubit.state.permissions?.canShowNotifications == false,
    );
    return AppErrorFeedback(
      message: switch (category) {
        ReminderCategory.medication => s.medicationRemindersBlockedNotice,
        ReminderCategory.vaccination => s.vaccinationRemindersBlockedNotice,
        ReminderCategory.feeding => s.feedingRemindersBlockedNotice,
      },
      retryLabel: appWide ? s.allowNotifications : s.openDeviceSettings,
      onRetry: () => cubit.perform(
        appWide
            ? NotificationAction.notificationPermission
            : NotificationAction.openSettings,
      ),
    );
  }
}
