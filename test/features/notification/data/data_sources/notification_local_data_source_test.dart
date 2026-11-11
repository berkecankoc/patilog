import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/exception.dart';
import 'package:patilog/features/notification/data/codecs/notification_target_codec.dart';
import 'package:patilog/features/notification/data/data_sources/notification_local_data_source.dart';
import 'package:patilog/features/notification/domain/entities/notification_reminder.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:patilog/features/notification/presentation/utils/notification_content.dart';
import 'package:patilog/core/l10n/app_locale.dart';
import 'package:patilog/l10n/generated/app_localizations_tr.dart';
import '../../../../helpers/notification_test_harness.dart'
    show englishNotificationContent;

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class MockAndroid extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class MockIOS extends Mock implements IOSFlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockPlugin plugin;
  late MockAndroid android;
  late MockIOS ios;
  late NotificationLocalDataSourceImpl source;
  late DidReceiveNotificationResponseCallback callback;
  late String zone;
  final dose = NotificationReminder(
    target: MedicationDoseNotificationTarget(
      petId: 'pet1',
      medicationId: 'med1',
      periodId: 'period1',
      scheduledDate: DateTime.utc(2035, 7, 2),
      scheduledMinute: 540,
    ),
    scheduledDate: DateTime.utc(2035, 7, 2),
    scheduledMinute: 540,
    title: 'Dose',
    body: 'Reminder',
  );

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime(tz.UTC, 2035));
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(
      const AndroidNotificationChannel('fallback', 'Fallback'),
    );
  });
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    plugin = MockPlugin();
    android = MockAndroid();
    ios = MockIOS();
    source = NotificationLocalDataSourceImpl(plugin);
    zone = 'Europe/Istanbul';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => {'identifier': zone},
        );
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((call) async {
      callback =
          call.namedArguments[#onDidReceiveNotificationResponse]
              as DidReceiveNotificationResponseCallback;
      return true;
    });
    when(
      plugin.getNotificationAppLaunchDetails,
    ).thenAnswer((_) async => const NotificationAppLaunchDetails(false));
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(android);
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(ios);
    when(android.areNotificationsEnabled).thenAnswer((_) async => true);
    when(
      () => android.createNotificationChannel(any()),
    ).thenAnswer((_) async {});
    when(android.canScheduleExactNotifications).thenAnswer((_) async => false);
    when(android.requestNotificationsPermission).thenAnswer((_) async => true);
    when(android.requestExactAlarmsPermission).thenAnswer((_) async => false);
    when(
      () => ios.requestPermissions(alert: true, sound: true, badge: false),
    ).thenAnswer((_) async => true);
    when(ios.checkPermissions).thenAnswer(
      (_) async => const NotificationsEnabledOptions(
        isEnabled: true,
        isSoundEnabled: true,
        isAlertEnabled: true,
        isBadgeEnabled: false,
        isProvisionalEnabled: false,
        isCriticalEnabled: false,
        isProvidesAppNotificationSettingsEnabled: false,
      ),
    );
    when(plugin.openAppNotificationSettings).thenAnswer((_) async => true);
    when(plugin.pendingNotificationRequests).thenAnswer((_) async => []);
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
  });
  tearDown(() async {
    await source.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        );
  });

  test('initializes once with all iOS permission prompts disabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => false);
    expect(await source.initialize(), isNull);
    expect(await source.initialize(), isNull);
    final settings =
        verify(
              () => plugin.initialize(
                settings: captureAny(named: 'settings'),
                onDidReceiveNotificationResponse: any(
                  named: 'onDidReceiveNotificationResponse',
                ),
              ),
            ).captured.single
            as InitializationSettings;
    expect(settings.iOS!.requestAlertPermission, isFalse);
    expect(settings.iOS!.requestBadgePermission, isFalse);
    expect(settings.iOS!.requestSoundPermission, isFalse);
    verifyNever(
      () => ios.requestPermissions(alert: true, sound: true, badge: false),
    );
    verifyNever(android.requestNotificationsPermission);
    verifyNever(android.requestExactAlarmsPermission);
  });

  test(
    'returns a valid cold-start target only once, including concurrent initialization',
    () async {
      when(plugin.getNotificationAppLaunchDetails).thenAnswer(
        (_) async => NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: NotificationTargetCodec.encode(dose.target),
          ),
        ),
      );
      expect(await Future.wait([source.initialize(), source.initialize()]), [
        dose.target,
        null,
      ]);
      expect(await source.initialize(), isNull);
      verify(plugin.getNotificationAppLaunchDetails).called(1);
    },
  );

  test(
    'ignores invalid launch payloads and forwards only valid foreground taps',
    () async {
      when(plugin.getNotificationAppLaunchDetails).thenAnswer(
        (_) async => const NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'patilog.reminder.v1:{',
          ),
        ),
      );
      expect(await source.initialize(), isNull);
      final received = <NotificationTarget>[];
      final subscription = source.openedNotifications.listen(received.add);
      callback(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'foreign',
        ),
      );
      callback(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: NotificationTargetCodec.encode(dose.target),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, [dose.target]);
      await subscription.cancel();
    },
  );

  for (final (platform, result) in [
    (TargetPlatform.android, false),
    (TargetPlatform.android, null),
    (TargetPlatform.iOS, null),
  ]) {
    test(
      'rejects $platform initialization result $result without reading launch data',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        when(
          () => plugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse: any(
              named: 'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => result);
        await expectLater(
          source.initialize(),
          throwsA(isA<NotificationPlatformException>()),
        );
        verifyNever(plugin.getNotificationAppLaunchDetails);
      },
    );
  }

  test(
    'real iOS Dart plugin accepts a false method-channel result without prompting',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      final native = NotificationLocalDataSourceImpl(
        FlutterLocalNotificationsPlugin(),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'initialize' => false,
              'getNotificationAppLaunchDetails' => {
                'notificationLaunchedApp': false,
              },
              _ => throw PlatformException(code: 'unexpected_call'),
            };
          });
      try {
        expect(await native.initialize(), isNull);
        expect(await native.initialize(), isNull);
        expect(calls.map((call) => call.method), [
          'initialize',
          'getNotificationAppLaunchDetails',
        ]);
        final arguments = calls.first.arguments as Map;
        expect(arguments['requestAlertPermission'], isFalse);
        expect(arguments['requestSoundPermission'], isFalse);
        expect(arguments['requestBadgePermission'], isFalse);
      } finally {
        await native.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        AndroidFlutterLocalNotificationsPlugin.registerWith();
      }
    },
  );

  test(
    'failed initialization can be retried instead of becoming permanently cached',
    () async {
      when(
        plugin.getNotificationAppLaunchDetails,
      ).thenThrow(PlatformException(code: 'init_failed'));
      await expectLater(source.initialize(), throwsA(isA<PlatformException>()));
      when(
        plugin.getNotificationAppLaunchDetails,
      ).thenAnswer((_) async => const NotificationAppLaunchDetails(false));
      expect(await source.initialize(), isNull);
      verify(plugin.getNotificationAppLaunchDetails).called(2);
    },
  );

  test(
    'reports Android capabilities and keeps exact permission denial distinct',
    () async {
      var status = await source.getPermissionStatus();
      expect(status.canShowNotifications, isTrue);
      expect(status.canScheduleExactAlarms, isFalse);
      expect(status.requiresExactAlarmPermission, isTrue);
      await source.requestNotificationPermission();
      status = await source.requestExactAlarmPermission();
      expect(status.canScheduleExactAlarms, isFalse);
      verify(android.requestNotificationsPermission).called(1);
      verify(android.requestExactAlarmsPermission).called(1);
    },
  );

  test(
    'iOS requests alerts/sound only and never asks for Android alarm permission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final status = await source.requestNotificationPermission();
      expect(status.canShowNotifications, isTrue);
      expect(status.requiresExactAlarmPermission, isFalse);
      await source.requestExactAlarmPermission();
      verify(
        () => ios.requestPermissions(alert: true, sound: true, badge: false),
      ).called(1);
      verifyNever(android.requestExactAlarmsPermission);
    },
  );

  for (final missing in ['display', 'exact', 'ios']) {
    test(
      'missing $missing permission state is an error rather than denial',
      () async {
        if (missing == 'display') {
          when(android.areNotificationsEnabled).thenAnswer((_) async => null);
        } else if (missing == 'exact') {
          when(
            android.canScheduleExactNotifications,
          ).thenAnswer((_) async => null);
        } else {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          when(ios.checkPermissions).thenAnswer((_) async => null);
        }
        await expectLater(
          source.getPermissionStatus(),
          throwsA(isA<NotificationPlatformException>()),
        );
        verifyNever(android.requestNotificationsPermission);
      },
    );
  }

  test('an unsuccessful settings launch is an actionable error', () async {
    when(plugin.openAppNotificationSettings).thenAnswer((_) async => false);
    await expectLater(
      source.openNotificationSettings(),
      throwsA(isA<NotificationPlatformException>()),
    );
  });

  test(
    'refreshes the device zone and constructs local calendar times without UTC conversion',
    () async {
      for (final identifier in ['Europe/Istanbul', 'America/New_York']) {
        zone = identifier;
        await source.refreshTimeZone();
        await source.scheduleReminder(
          12,
          dose,
          exact: true,
          channels: englishNotificationContent.channels,
        );
        final date =
            verify(
                  () => plugin.zonedSchedule(
                    id: 12,
                    scheduledDate: captureAny(named: 'scheduledDate'),
                    notificationDetails: any(named: 'notificationDetails'),
                    androidScheduleMode:
                        AndroidScheduleMode.exactAllowWhileIdle,
                    title: dose.title,
                    body: dose.body,
                    payload: NotificationTargetCodec.encode(dose.target),
                  ),
                ).captured.single
                as tz.TZDateTime;
        expect(
          (date.year, date.month, date.day, date.hour, date.minute),
          (2035, 7, 2, 9, 0),
        );
        expect(date.location.name, identifier);
      }
    },
  );

  test(
    'uses category channels and private Android lock-screen visibility',
    () async {
      await source.refreshTimeZone();
      await source.scheduleReminder(
        12,
        dose,
        exact: false,
        channels: englishNotificationContent.channels,
      );
      final details =
          verify(
                () => plugin.zonedSchedule(
                  id: 12,
                  scheduledDate: any(named: 'scheduledDate'),
                  notificationDetails: captureAny(named: 'notificationDetails'),
                  androidScheduleMode:
                      AndroidScheduleMode.inexactAllowWhileIdle,
                  title: dose.title,
                  body: dose.body,
                  payload: NotificationTargetCodec.encode(dose.target),
                ),
              ).captured.single
              as NotificationDetails;
      expect(details.android!.channelId, 'medication_reminders');
      expect(details.android!.visibility, NotificationVisibility.private);
      expect(details.iOS!.presentBadge, isFalse);
    },
  );

  test(
    'falls back if exact permission is revoked between checking and scheduling',
    () async {
      await source.refreshTimeZone();
      final modes = <AndroidScheduleMode>[];
      when(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((call) async {
        final mode =
            call.namedArguments[#androidScheduleMode] as AndroidScheduleMode;
        modes.add(mode);
        if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
          throw PlatformException(code: 'exact_alarms_not_permitted');
        }
      });
      await source.scheduleReminder(
        12,
        dose,
        exact: true,
        channels: englishNotificationContent.channels,
      );
      expect(modes, [
        AndroidScheduleMode.exactAllowWhileIdle,
        AndroidScheduleMode.inexactAllowWhileIdle,
      ]);
    },
  );

  test(
    'does not disguise other native scheduling failures as a successful fallback',
    () async {
      await source.refreshTimeZone();
      when(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      ).thenThrow(PlatformException(code: 'different_failure'));
      await expectLater(
        source.scheduleReminder(
          12,
          dose,
          exact: true,
          channels: englishNotificationContent.channels,
        ),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test('reads and cancels pending entries by their native ID', () async {
    const request = PendingNotificationRequest(77, 'Title', 'Body', 'payload');
    when(plugin.pendingNotificationRequests).thenAnswer((_) async => [request]);
    expect(await source.getPendingNotifications(), [request]);
    await source.cancelReminder(77);
    verify(() => plugin.cancel(id: 77)).called(1);
  });

  test(
    'updates localized channel metadata under the same IDs without deleting channels or requesting permission',
    () async {
      final translated = NotificationContent(
        AppLocalizationsTr('tr_TR'),
        turkishLocale,
      ).channels;
      await source.updateChannels(englishNotificationContent.channels);
      await source.updateChannels(translated);
      final channels = verify(
        () => android.createNotificationChannel(captureAny()),
      ).captured.cast<AndroidNotificationChannel>().toList();
      expect(channels.map((c) => c.id), [
        'medication_reminders',
        'vaccination_reminders',
        'feeding_reminders',
        'medication_reminders',
        'vaccination_reminders',
        'feeding_reminders',
      ]);
      expect(channels[3].name, 'İlaç hatırlatmaları');
      expect(channels[4].name, 'Aşı hatırlatmaları');
      expect(channels[4].description, translated.vaccinationDescription);
      expect(channels[5].name, 'Beslenme hatırlatmaları');
      expect(channels.map((c) => c.importance), everyElement(Importance.high));
      verifyNever(
        () => android.deleteNotificationChannel(
          channelId: any(named: 'channelId'),
        ),
      );
      verifyNever(android.requestNotificationsPermission);
      verifyNever(android.requestExactAlarmsPermission);
      verifyNever(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      );
    },
  );

  test(
    'iOS has no Android channel operation or permission side effect',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await source.updateChannels(englishNotificationContent.channels);
      verifyZeroInteractions(plugin);
      verifyZeroInteractions(android);
      verifyZeroInteractions(ios);
    },
  );

  test(
    'feeding uses its own channel and typed payload with private visibility',
    () async {
      final reminder = NotificationReminder(
        target: FeedingMealNotificationTarget(
          petId: 'pet1',
          planId: 'plan',
          mealId: 'meal',
          scheduledDate: DateTime(2035, 7, 2),
          scheduledMinute: 720,
        ),
        scheduledDate: DateTime(2035, 7, 2),
        scheduledMinute: 720,
        title: 'Meal',
        body: '40 g',
      );
      await source.refreshTimeZone();
      await source.scheduleReminder(
        15,
        reminder,
        exact: true,
        channels: englishNotificationContent.channels,
      );
      final details =
          verify(
                () => plugin.zonedSchedule(
                  id: 15,
                  scheduledDate: any(named: 'scheduledDate'),
                  notificationDetails: captureAny(named: 'notificationDetails'),
                  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                  title: reminder.title,
                  body: reminder.body,
                  payload: NotificationTargetCodec.encode(reminder.target),
                ),
              ).captured.single
              as NotificationDetails;
      expect(details.android!.channelId, 'feeding_reminders');
      expect(details.android!.channelName, 'Feeding reminders');
      expect(details.android!.visibility, NotificationVisibility.private);
    },
  );

  test(
    'scheduled reminders carry localized labels with the original channel IDs',
    () async {
      final labels = NotificationContent(
        AppLocalizationsTr('tr_TR'),
        turkishLocale,
      ).channels;
      await source.refreshTimeZone();
      await source.scheduleReminder(12, dose, exact: false, channels: labels);
      final details =
          verify(
                () => plugin.zonedSchedule(
                  id: 12,
                  scheduledDate: any(named: 'scheduledDate'),
                  notificationDetails: captureAny(named: 'notificationDetails'),
                  androidScheduleMode:
                      AndroidScheduleMode.inexactAllowWhileIdle,
                  title: dose.title,
                  body: dose.body,
                  payload: NotificationTargetCodec.encode(dose.target),
                ),
              ).captured.single
              as NotificationDetails;
      expect(details.android!.channelId, 'medication_reminders');
      expect(details.android!.channelName, labels.medicationName);
      expect(details.android!.channelDescription, labels.medicationDescription);
      expect(details.android!.visibility, NotificationVisibility.private);
    },
  );
}
