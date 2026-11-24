import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/router/app_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/features/notification/domain/entities/notification_permission_status.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:patilog/features/notification/presentation/widgets/reminder_offer_prompt.dart';

import '../../../../helpers/settings_test_harness.dart';

void main() {
  late SettingsTestHarness app;
  const denied = NotificationPermissionStatus(
    canShowNotifications: false,
    canScheduleExactAlarms: false,
    requiresExactAlarmPermission: true,
  );
  const granted = NotificationPermissionStatus(
    canShowNotifications: true,
    canScheduleExactAlarms: false,
    requiresExactAlarmPermission: true,
  );
  setUpAll(SettingsTestHarness.initialize);
  setUp(() => app = SettingsTestHarness()..register());

  Future<NotificationCubit> pump(
    WidgetTester tester, {
    String location = AppRoutes.settings,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await app.pump(tester, location: location);
    return BlocProvider.of<NotificationCubit>(
      tester.element(find.byType(ReminderOfferPrompt)),
    );
  }

  Future<void> offer(
    WidgetTester tester,
    NotificationCubit cubit,
    ReminderCategory category,
  ) async {
    cubit.offerReminders(category);
    await tester.pumpAndSettle();
  }

  final medicationTitle = find.text('Turn on medication reminders?');

  testWidgets(
    'waits for the saving form to close, then Not now records the offer silently',
    (tester) async {
      final cubit = await pump(tester, location: AppRoutes.addEditPet);
      await offer(tester, cubit, ReminderCategory.medication);
      expect(medicationTitle, findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, AppRoutes.pets);
      expect(medicationTitle, findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(medicationTitle, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      final stored = app.notifications.preferences;
      expect(stored.medicationRemindersEnabled, isFalse);
      expect(stored.offeredCategories, {ReminderCategory.medication});
      verifyNever(app.notifications.repository.requestNotificationPermission);

      await offer(tester, cubit, ReminderCategory.medication);
      expect(medicationTitle, findsNothing);
    },
  );

  testWidgets('system Back on the offer declines it like Not now', (
    tester,
  ) async {
    final cubit = await pump(tester);
    await offer(tester, cubit, ReminderCategory.feeding);
    expect(find.text('Turn on feeding reminders?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Turn on feeding reminders?'), findsNothing);
    expect(appRouter.state.uri.path, AppRoutes.settings);
    expect(app.notifications.preferences.offeredCategories, {
      ReminderCategory.feeding,
    });
    expect(app.notifications.preferences.feedingRemindersEnabled, isFalse);
  });

  testWidgets(
    'Turn on asks for notification permission once and stays quiet when granted',
    (tester) async {
      app.notifications.permission = denied;
      when(app.notifications.repository.requestNotificationPermission)
          .thenAnswer((_) async {
            app.notifications.permission = granted;
            return const Success(granted);
          });
      final cubit = await pump(tester);
      await offer(tester, cubit, ReminderCategory.vaccination);
      expect(
        find.text(
          'Patilog can notify you before planned vaccinations. Choose the days and time in Settings → Notifications.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(app.notifications.preferences.vaccinationRemindersEnabled, isTrue);
      expect(find.byType(SnackBar), findsNothing);
      verify(app.notifications.repository.requestNotificationPermission)
          .called(1);
      verifyNever(app.notifications.repository.requestExactAlarmPermission);
    },
  );

  testWidgets(
    'blocked notifications after Turn on are explained on the care screen, not in a snackbar',
    (tester) async {
      app.notifications.permission = denied;
      app.care.medications = [app.care.sample()];
      final cubit = await pump(tester, location: AppRoutes.medications('pet'));
      final notice = find.text(
        "Medication reminders can't arrive: notifications are turned off in device settings.",
      );
      expect(notice, findsNothing);
      await offer(tester, cubit, ReminderCategory.medication);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(app.notifications.preferences.medicationRemindersEnabled, isTrue);
      expect(find.byType(SnackBar), findsNothing);
      expect(notice, findsOneWidget);
      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();
      verify(app.notifications.repository.openNotificationSettings).called(1);
      verifyNever(app.notifications.repository.requestExactAlarmPermission);
    },
  );

  testWidgets('a failed save after Turn on can be retried from the snackbar', (
    tester,
  ) async {
    final cubit = await pump(tester);
    app.notifications.failSave = true;
    await offer(tester, cubit, ReminderCategory.feeding);
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to save reminder settings'), findsOneWidget);
    expect(app.notifications.preferences.feedingRemindersEnabled, isFalse);

    app.notifications.failSave = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(app.notifications.preferences.feedingRemindersEnabled, isTrue);
    expect(app.notifications.preferences.offeredCategories, {
      ReminderCategory.feeding,
    });
    verifyNever(app.notifications.repository.requestExactAlarmPermission);
  });
}
