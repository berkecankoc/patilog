import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/notification/data/codecs/notification_target_codec.dart';
import 'package:petlytics/features/notification/data/data_sources/notification_local_data_source.dart';
import 'package:petlytics/features/notification/data/data_sources/notification_preferences_local_data_source.dart';
import 'package:petlytics/features/notification/domain/entities/notification_permission_status.dart';
import 'package:petlytics/features/notification/domain/entities/notification_channel_labels.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/domain/entities/notification_reminder.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/notification/domain/repositories/notification_repository.dart';

final class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationPreferencesLocalDataSource preferences;
  final NotificationLocalDataSource notifications;
  final DateTime Function() now;
  Future<void> _queue = Future.value();

  NotificationRepositoryImpl(
    this.preferences,
    this.notifications, {
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  @override
  Stream<NotificationTarget> get openedNotifications =>
      notifications.openedNotifications;

  @override
  Future<Result<NotificationTarget?>> initialize() =>
      _native(notifications.initialize, 'Failed to initialize reminders');

  @override
  Future<Result<NotificationPreferences>> getPreferences() async {
    try {
      return Success(await preferences.getPreferences());
    } on PreferencesStorageException {
      return const Error(
        PreferencesStorageFailure('Failed to load notification preferences'),
      );
    }
  }

  @override
  Future<Result<void>> savePreferences(NotificationPreferences value) async {
    try {
      await preferences.savePreferences(value);
      return const Success(null);
    } on PreferencesStorageException {
      return const Error(
        PreferencesStorageFailure('Failed to save notification preferences'),
      );
    }
  }

  @override
  Future<Result<NotificationPermissionStatus>> getPermissionStatus() => _native(
    notifications.getPermissionStatus,
    'Failed to check notification permissions',
  );

  @override
  Future<Result<NotificationPermissionStatus>>
  requestNotificationPermission() => _native(
    notifications.requestNotificationPermission,
    'Failed to request notification permission',
  );

  @override
  Future<Result<NotificationPermissionStatus>> requestExactAlarmPermission() =>
      _native(
        notifications.requestExactAlarmPermission,
        'Failed to request precise reminder permission',
      );

  @override
  Future<Result<void>> openNotificationSettings() => _native(
    notifications.openNotificationSettings,
    'Failed to open notification settings',
  );

  @override
  Future<Result<void>> synchronizeReminders(
    List<NotificationReminder> reminders, {
    required NotificationChannelLabels channels,
  }) {
    final snapshot = List<NotificationReminder>.unmodifiable(reminders);
    return _mutate(() async {
      _validate(snapshot);
      final pending = await notifications.getPendingNotifications();
      final foreign = pending.where(
        (item) => !NotificationTargetCodec.isOwned(item.payload),
      );
      if (foreign.length + snapshot.length >
          NotificationRepository.maxPendingReminders) {
        throw const FormatException('Reminder capacity exceeded');
      }
      var exact = false;
      if (snapshot.isNotEmpty) {
        await notifications.refreshTimeZone();
        final permission = await notifications.getPermissionStatus();
        if (!permission.canShowNotifications) {
          throw const NotificationPlatformException();
        }
        exact = permission.canScheduleExactAlarms;
      }
      // Rename existing channels even when the queue is empty; keep their IDs.
      await notifications.updateChannels(channels);
      final desired = snapshot.map((item) => item.target.identityKey).toSet();
      final retainedIds = <String, int>{};
      final usedIds = pending.map((item) => item.id).toSet();
      // Cancel stale/duplicate owned entries before adding, respecting iOS capacity.
      for (final item in pending) {
        if (!NotificationTargetCodec.isOwned(item.payload)) continue;
        final key = NotificationTargetCodec.decode(item.payload)?.identityKey;
        if (key != null &&
            desired.contains(key) &&
            !retainedIds.containsKey(key)) {
          retainedIds[key] = item.id;
        } else {
          await notifications.cancelReminder(item.id);
        }
      }
      var nextId = 1;
      for (final reminder in snapshot) {
        final retained = retainedIds[reminder.target.identityKey];
        while (usedIds.contains(nextId)) {
          nextId++;
        }
        final id = retained ?? nextId;
        usedIds.add(id);
        // Reusing an ID also replaces changed text, time and device time zone.
        await notifications.scheduleReminder(
          id,
          reminder,
          channels: channels,
          exact: exact && reminder.target is! VaccinationNotificationTarget,
        );
      }
    }, 'Failed to synchronize reminders');
  }

  void _validate(List<NotificationReminder> reminders) {
    if (reminders.length > NotificationRepository.maxPendingReminders) {
      throw const FormatException('Reminder capacity exceeded');
    }
    final identities = <String>{};
    final current = now();
    for (final reminder in reminders) {
      final encoded = NotificationTargetCodec.encode(reminder.target);
      final date = reminder.scheduledDate;
      if (date.year < 1 ||
          date.year > 9999 ||
          reminder.scheduledMinute < 0 ||
          reminder.scheduledMinute >= 1440 ||
          !DateTime(
            date.year,
            date.month,
            date.day,
            reminder.scheduledMinute ~/ 60,
            reminder.scheduledMinute % 60,
          ).isAfter(current) ||
          !identities.add(encoded)) {
        throw const FormatException('Invalid reminder schedule');
      }
      if (reminder.target case MedicationDoseNotificationTarget target) {
        if (target.scheduledDate.year != date.year ||
            target.scheduledDate.month != date.month ||
            target.scheduledDate.day != date.day ||
            target.scheduledMinute != reminder.scheduledMinute) {
          throw const FormatException('Reminder does not match its dose');
        }
      }
      if (reminder.target case FeedingMealNotificationTarget target) {
        if (target.scheduledDate.year != date.year ||
            target.scheduledDate.month != date.month ||
            target.scheduledDate.day != date.day ||
            target.scheduledMinute != reminder.scheduledMinute) {
          throw const FormatException('Reminder does not match its meal');
        }
      }
    }
  }

  @override
  Future<Result<void>> cancelPetReminders(String petId) =>
      _cancel((target) => target.petId == petId);

  @override
  Future<Result<void>> cancelMedicationReminders(
    String petId,
    String medicationId,
  ) => _cancel(
    (target) =>
        target is MedicationDoseNotificationTarget &&
        target.petId == petId &&
        target.medicationId == medicationId,
  );

  @override
  Future<Result<void>> cancelVaccinationReminders(
    String petId,
    String vaccinationId,
  ) => _cancel(
    (target) =>
        target is VaccinationNotificationTarget &&
        target.petId == petId &&
        target.vaccinationId == vaccinationId,
  );

  Future<Result<void>> _cancel(bool Function(NotificationTarget) matches) =>
      _mutate(() async {
        for (final item in await notifications.getPendingNotifications()) {
          final target = NotificationTargetCodec.decode(item.payload);
          if (target != null && matches(target)) {
            await notifications.cancelReminder(item.id);
          }
        }
      }, 'Failed to cancel reminders');

  Future<Result<void>> _mutate(
    Future<void> Function() operation,
    String message,
  ) {
    final result = _queue.then((_) => _native(operation, message));
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Result<T>> _native<T>(
    Future<T> Function() operation,
    String message,
  ) async {
    try {
      return Success(await operation());
    } on Exception {
      return Error(NotificationFailure(message));
    } on ArgumentError {
      // Native plugin date/zone validation can reject a request before dispatch.
      return Error(NotificationFailure(message));
    }
  }
}
