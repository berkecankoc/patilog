import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/notification/data/codecs/notification_target_codec.dart';
import 'package:petlytics/features/notification/domain/entities/notification_permission_status.dart';
import 'package:petlytics/features/notification/domain/entities/notification_reminder.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class NotificationLocalDataSource {
  Future<NotificationTarget?> initialize();
  Stream<NotificationTarget> get openedNotifications;
  Future<NotificationPermissionStatus> getPermissionStatus();
  Future<NotificationPermissionStatus> requestNotificationPermission();
  Future<NotificationPermissionStatus> requestExactAlarmPermission();
  Future<void> openNotificationSettings();
  Future<void> refreshTimeZone();
  Future<List<PendingNotificationRequest>> getPendingNotifications();
  Future<void> scheduleReminder(
    int id,
    NotificationReminder reminder, {
    required bool exact,
  });
  Future<void> cancelReminder(int id);
  Future<void> dispose();
}

final class NotificationLocalDataSourceImpl
    implements NotificationLocalDataSource {
  final FlutterLocalNotificationsPlugin plugin;
  final _opened = StreamController<NotificationTarget>.broadcast();
  Future<void>? _initialization;
  NotificationTarget? _launchTarget;
  tz.Location? _location;
  bool _timeZonesLoaded = false;

  NotificationLocalDataSourceImpl(this.plugin);

  @override
  Stream<NotificationTarget> get openedNotifications => _opened.stream;

  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  AndroidFlutterLocalNotificationsPlugin get _androidPlugin => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()!;
  IOSFlutterLocalNotificationsPlugin get _iosPlugin => plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()!;

  Future<void> _ensureInitialized() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw const NotificationPlatformException();
    }
    try {
      await (_initialization ??= _initializePlugin());
    } on Exception {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initializePlugin() async {
    final initialized = await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final target = NotificationTargetCodec.decode(response.payload);
        if (target != null && !_opened.isClosed) _opened.add(target);
      },
    );
    if (initialized != true) throw const NotificationPlatformException();
    final launch = await plugin.getNotificationAppLaunchDetails();
    _launchTarget = launch?.didNotificationLaunchApp == true
        ? NotificationTargetCodec.decode(launch?.notificationResponse?.payload)
        : null;
  }

  @override
  Future<NotificationTarget?> initialize() async {
    await _ensureInitialized();
    final target = _launchTarget;
    _launchTarget = null;
    return target;
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    await _ensureInitialized();
    if (_android) {
      final enabled = await _androidPlugin.areNotificationsEnabled();
      final exact = await _androidPlugin.canScheduleExactNotifications();
      if (enabled == null || exact == null) {
        throw const NotificationPlatformException();
      }
      return NotificationPermissionStatus(
        canShowNotifications: enabled,
        canScheduleExactAlarms: exact,
        requiresExactAlarmPermission: true,
      );
    }
    final permissions = await _iosPlugin.checkPermissions();
    if (permissions == null) throw const NotificationPlatformException();
    return NotificationPermissionStatus(
      canShowNotifications: permissions.isEnabled,
      canScheduleExactAlarms: true,
      requiresExactAlarmPermission: false,
    );
  }

  @override
  Future<NotificationPermissionStatus> requestNotificationPermission() async {
    await _ensureInitialized();
    if (_android) {
      await _androidPlugin.requestNotificationsPermission();
    } else {
      await _iosPlugin.requestPermissions(
        alert: true,
        sound: true,
        badge: false,
      );
    }
    return getPermissionStatus();
  }

  @override
  Future<NotificationPermissionStatus> requestExactAlarmPermission() async {
    await _ensureInitialized();
    if (_android) await _androidPlugin.requestExactAlarmsPermission();
    return getPermissionStatus();
  }

  @override
  Future<void> openNotificationSettings() async {
    await _ensureInitialized();
    if (await plugin.openAppNotificationSettings() != true) {
      throw const NotificationPlatformException();
    }
  }

  @override
  Future<void> refreshTimeZone() async {
    if (!_timeZonesLoaded) {
      tz_data.initializeTimeZones();
      _timeZonesLoaded = true;
    }
    final zone = await FlutterTimezone.getLocalTimezone();
    _location = tz.getLocation(zone.identifier);
  }

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await _ensureInitialized();
    return plugin.pendingNotificationRequests();
  }

  @override
  Future<void> scheduleReminder(
    int id,
    NotificationReminder reminder, {
    required bool exact,
  }) async {
    await _ensureInitialized();
    final location = _location;
    if (location == null) throw const NotificationPlatformException();
    final medication = reminder.target is MedicationDoseNotificationTarget;
    Future<void> schedule(AndroidScheduleMode mode) => plugin.zonedSchedule(
      id: id,
      title: reminder.title,
      body: reminder.body,
      scheduledDate: tz.TZDateTime(
        location,
        reminder.scheduledDate.year,
        reminder.scheduledDate.month,
        reminder.scheduledDate.day,
        reminder.scheduledMinute ~/ 60,
        reminder.scheduledMinute % 60,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          medication ? 'medication_reminders' : 'vaccination_reminders',
          medication ? 'Medication reminders' : 'Vaccination reminders',
          channelDescription: medication
              ? 'Scheduled medication doses'
              : 'Planned vaccination reminders',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(presentBadge: false),
      ),
      androidScheduleMode: mode,
      payload: NotificationTargetCodec.encode(reminder.target),
    );
    try {
      await schedule(
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException catch (error) {
      // Permission can be revoked between the capability check and scheduling.
      if (!exact || error.code != 'exact_alarms_not_permitted') rethrow;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  @override
  Future<void> cancelReminder(int id) async {
    await _ensureInitialized();
    await plugin.cancel(id: id);
  }

  @override
  Future<void> dispose() => _opened.close();
}
