import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/notification/domain/entities/notification_channel_labels.dart';
import 'package:patilog/features/notification/domain/entities/notification_permission_status.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/notification_reminder.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';

abstract interface class NotificationRepository {
  /// Shared application budget across pets and reminder categories.
  static const maxPendingReminders = 64;

  /// Initializes without permission prompts; returns a cold-start tap once.
  Future<Result<NotificationTarget?>> initialize();

  Stream<NotificationTarget> get openedNotifications;

  /// Missing preferences use NotificationPreferences defaults.
  Future<Result<NotificationPreferences>> getPreferences();
  Future<Result<void>> savePreferences(NotificationPreferences preferences);

  Future<Result<NotificationPermissionStatus>> getPermissionStatus();
  Future<Result<NotificationPermissionStatus>> requestNotificationPermission();
  Future<Result<NotificationPermissionStatus>> requestExactAlarmPermission();
  Future<Result<void>> openNotificationSettings();

  /// Reconciles only owned reminders, retaining native IDs for stable targets.
  /// Accepts at most maxPendingReminders, with unique identities and future
  /// local dates/minutes; failures are returned without writing health records.
  /// Invalid batches are rejected before changing the native queue.
  /// Localized channel labels are updated even when the queue is empty.
  Future<Result<void>> synchronizeReminders(
    List<NotificationReminder> reminders, {
    required NotificationChannelLabels channels,
  });

  /// Cancellation matches pending metadata by pet/record IDs, without rereading
  /// deleted clinical records.
  Future<Result<void>> cancelPetReminders(String petId);
  Future<Result<void>> cancelMedicationReminders(
    String petId,
    String medicationId,
  );
  Future<Result<void>> cancelVaccinationReminders(
    String petId,
    String vaccinationId,
  );
}
