import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/features/notification/domain/entities/notification_permission_status.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:patilog/features/notification/presentation/widgets/reminder_blocked_notice.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

import '../../../../helpers/notification_test_harness.dart';

void main() {
  late NotificationTestHarness h;
  const denied = NotificationPermissionStatus(
    canShowNotifications: false,
    canScheduleExactAlarms: true,
    requiresExactAlarmPermission: true,
  );
  const medicationMessage =
      "Medication reminders can't arrive: notifications are turned off in device settings.";
  setUp(() => h = NotificationTestHarness());
  tearDown(() => h.dispose());

  Future<NotificationCubit> pump(
    WidgetTester tester, {
    ReminderCategory category = ReminderCategory.medication,
    bool hasReminders = true,
    bool provide = true,
    double textScale = 1,
  }) async {
    final cubit = h.createCubit();
    await cubit.initialize();
    final notice = Builder(
      builder: (context) => Column(
        children: [
          if (ReminderBlockedNotice.shows(
            context,
            category,
            hasReminders: hasReminders,
          ))
            ReminderBlockedNotice(category: category),
          const Expanded(child: SizedBox(key: Key('content'))),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: provide
              ? BlocProvider<NotificationCubit>.value(
                  value: cubit,
                  child: notice,
                )
              : notice,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets(
    'an enabled category blocked by the device shows one settings action',
    (tester) async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      h.permission = denied;
      await pump(tester);
      expect(find.text(medicationMessage), findsOneWidget);
      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();
      // A decided denial cannot prompt again, so settings open instead.
      verify(h.repository.requestNotificationPermission).called(1);
      verify(h.repository.openNotificationSettings).called(1);
    },
  );

  testWidgets('a disabled category or a screen without reminders stays quiet', (
    tester,
  ) async {
    h.preferences = NotificationPreferences(feedingRemindersEnabled: true);
    h.permission = denied;
    await pump(tester);
    expect(find.text(medicationMessage), findsNothing);
    await pump(tester, category: ReminderCategory.feeding, hasReminders: false);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('only the Android category turned off in system settings warns', (
    tester,
  ) async {
    h.preferences = NotificationPreferences(
      medicationRemindersEnabled: true,
      vaccinationRemindersEnabled: true,
    );
    h.permission = const NotificationPermissionStatus(
      canShowNotifications: true,
      canScheduleExactAlarms: true,
      requiresExactAlarmPermission: true,
      vaccinationRemindersBlocked: true,
    );
    await pump(tester);
    expect(find.text(medicationMessage), findsNothing);
    await pump(tester, category: ReminderCategory.vaccination);
    expect(
      find.text(
        "Vaccination reminders can't arrive: notifications are turned off in device settings.",
      ),
      findsOneWidget,
    );
    // Permission is granted, so only the channel settings can help.
    await tester.tap(find.text('Open device settings'));
    await tester.pumpAndSettle();
    verify(h.repository.openNotificationSettings).called(1);
    verifyNever(h.repository.requestNotificationPermission);
  });

  testWidgets('the warning disappears once a refresh reads the permission', (
    tester,
  ) async {
    h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
    h.permission = denied;
    final cubit = await pump(tester);
    expect(find.text(medicationMessage), findsOneWidget);
    h.permission = const NotificationPermissionStatus(
      canShowNotifications: true,
      canScheduleExactAlarms: true,
      requiresExactAlarmPermission: true,
    );
    cubit.refresh();
    await tester.pumpAndSettle();
    expect(find.text(medicationMessage), findsNothing);
  });

  testWidgets('screens without the notification runtime render nothing', (
    tester,
  ) async {
    h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
    h.permission = denied;
    await pump(tester, provide: false);
    expect(find.text(medicationMessage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hidden notice leaves the full height to the content', (
    tester,
  ) async {
    h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
    await pump(tester);
    final content = tester.getSize(find.byKey(const Key('content')));
    final body = tester.getSize(find.byType(Column).first);
    expect(content.height, body.height);
  });

  testWidgets('a shown notice leaves all remaining height to the content', (
    tester,
  ) async {
    h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
    h.permission = denied;
    await pump(tester);
    final notice = tester.getSize(find.byType(ReminderBlockedNotice));
    final content = tester.getSize(find.byKey(const Key('content')));
    final body = tester.getSize(find.byType(Column).first);
    expect(notice.height, greaterThan(0));
    expect(content.height, body.height - notice.height);
  });

  testWidgets('large text keeps the notice capped and its action reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
    h.permission = denied;
    await pump(tester, textScale: 3);
    final notice = tester.getSize(find.byType(ReminderBlockedNotice));
    expect(
      notice.height,
      lessThanOrEqualTo(568 * ReminderBlockedNotice.maxHeightFraction),
    );
    expect(
      tester.getSize(find.byKey(const Key('content'))).height,
      greaterThanOrEqualTo(568 / 2),
    );
    expect(find.text('Allow notifications').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
