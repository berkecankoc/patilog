import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/features/notification/domain/entities/notification_permission_status.dart';
import 'package:petlytics/features/notification/presentation/pages/notification_settings_page.dart';
import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import '../../../../helpers/settings_test_harness.dart';

void main() {
  late SettingsTestHarness app;
  setUpAll(SettingsTestHarness.initialize);
  setUp(() => app = SettingsTestHarness()..register());
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) => app.pump(
    tester,
    location: AppRoutes.notificationSettings,
    size: size,
    scale: scale,
  );
  Finder toggle(String label) => find.widgetWithText(SwitchListTile, label);

  testWidgets('reminder controls follow live light and dark theme changes', (
    tester,
  ) async {
    app.stored = ThemePreference.light;
    app.notifications.preferences = NotificationPreferences(
      medicationRemindersEnabled: true,
    );
    app.notifications.permission = const NotificationPermissionStatus(
      canShowNotifications: false,
      canScheduleExactAlarms: false,
      requiresExactAlarmPermission: true,
    );
    await open(tester);
    Color selectedThumb() {
      final element = tester.element(toggle('Medication reminders'));
      return SwitchTheme.of(
        element,
      ).thumbColor!.resolve({WidgetState.selected})!;
    }

    final lightThumb = selectedThumb();
    expect(lightThumb, Colors.white);
    await tester.ensureVisible(find.text('Allow notifications'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Allow notifications');
    final lightButton = tester
        .widget<FilledButton>(button)
        .defaultStyleOf(tester.element(button));
    final lightBackground = lightButton.backgroundColor!.resolve({});
    final lightForeground = lightButton.foregroundColor!.resolve({});
    await app.cubit.setThemePreference(ThemePreference.dark);
    await tester.pumpAndSettle();
    expect(selectedThumb(), isNot(lightThumb));
    final darkButton = tester
        .widget<FilledButton>(button)
        .defaultStyleOf(tester.element(button));
    expect(darkButton.backgroundColor!.resolve({}), isNot(lightBackground));
    expect(darkButton.foregroundColor!.resolve({}), isNot(lightForeground));
    expect(app.notifications.preferences.medicationRemindersEnabled, isTrue);
    verifyNever(app.notifications.repository.requestNotificationPermission);
    verifyNever(() => app.notifications.repository.savePreferences(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'feeding has an independent explicit toggle preserved by other category changes',
    (tester) async {
      app.notifications.feedingPlans.add(app.notifications.feedingPlan());
      await open(tester);
      expect(
        tester.widget<SwitchListTile>(toggle('Feeding reminders')).value,
        isFalse,
      );
      verifyNever(app.notifications.repository.requestNotificationPermission);
      await tester.ensureVisible(toggle('Feeding reminders'));
      await tester.tap(toggle('Feeding reminders'));
      await tester.pumpAndSettle();
      expect(app.notifications.preferences.feedingRemindersEnabled, isTrue);
      expect(app.notifications.submissions.last, isNotEmpty);
      await tester.ensureVisible(toggle('Vaccination reminders'));
      await tester.tap(toggle('Vaccination reminders'));
      await tester.pumpAndSettle();
      expect(app.notifications.preferences.feedingRemindersEnabled, isTrue);
      expect(app.notifications.preferences.vaccinationRemindersEnabled, isTrue);
    },
  );
  Future<void> edit(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Days & time'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Days & time'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Settings entry opens notification preferences with disabled defaults and no permission prompts',
    (tester) async {
      await app.pump(tester);
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationSettingsPage), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(toggle('Medication reminders')).value,
        isFalse,
      );
      expect(
        tester.widget<SwitchListTile>(toggle('Vaccination reminders')).value,
        isFalse,
      );
      verifyNever(app.notifications.repository.requestNotificationPermission);
      verifyNever(app.notifications.repository.requestExactAlarmPermission);
      verifyNever(app.care.pets.getPets);
    },
  );
  testWidgets('unknown preferences stay disabled and retry the failed read', (
    tester,
  ) async {
    when(app.notifications.repository.getPreferences).thenAnswer(
      (_) async => const Error(PreferencesStorageFailure('Preferences failed')),
    );
    await open(tester);
    expect(find.text('Failed to initialize reminders'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(toggle('Medication reminders')).onChanged,
      isNull,
    );
    when(
      app.notifications.repository.getPreferences,
    ).thenAnswer((_) async => Success(app.notifications.preferences));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(toggle('Medication reminders')).onChanged,
      isNotNull,
    );
    expect(find.text('Failed to initialize reminders'), findsNothing);
    verifyNever(() => app.notifications.repository.savePreferences(any()));
  });

  testWidgets('enables categories and exposes nearest-queue coverage', (
    tester,
  ) async {
    app.notifications.medicines.add(app.notifications.medication());
    await open(tester);
    await tester.tap(toggle('Medication reminders'));
    await tester.pumpAndSettle();
    expect(app.notifications.preferences.medicationRemindersEnabled, isTrue);
    await tester.ensureVisible(find.text('Upcoming reminders'));
    await tester.pumpAndSettle();
    final date = MaterialLocalizations.of(
      tester.element(find.byType(NotificationSettingsPage)),
    ).formatShortDate(DateTime(2030, 1, 1));
    expect(find.text('Next: $date, 12:00'), findsOneWidget);
    expect(find.textContaining('64 reminders queued through'), findsOneWidget);
    expect(
      find.text('Open the app regularly to prepare later reminders.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'denial stays visible and explicit actions retry permissions or open device settings',
    (tester) async {
      app.notifications.permission = const NotificationPermissionStatus(
        canShowNotifications: false,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      await open(tester);
      await tester.tap(toggle('Vaccination reminders'));
      await tester.pumpAndSettle();
      expect(app.notifications.preferences.vaccinationRemindersEnabled, isTrue);
      await tester.ensureVisible(find.text('Open device settings'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications are blocked'), findsOneWidget);
      await tester.tap(find.text('Open device settings'));
      await tester.pumpAndSettle();
      verify(app.notifications.repository.openNotificationSettings).called(1);
      app.notifications.permission = const NotificationPermissionStatus(
        canShowNotifications: true,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      await tester.ensureVisible(find.text('Allow notifications'));
      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications are blocked'), findsNothing);
      verify(
        app.notifications.repository.requestNotificationPermission,
      ).called(2);
    },
  );
  testWidgets(
    'normal medication scheduling remains enabled when exact access is denied',
    (tester) async {
      app.notifications.permission = const NotificationPermissionStatus(
        canShowNotifications: true,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      await open(tester);
      await tester.tap(toggle('Medication reminders'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Allow precise reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Precise timing is off'), findsOneWidget);
      await tester.tap(find.text('Allow precise reminders'));
      await tester.pumpAndSettle();
      verify(
        app.notifications.repository.requestExactAlarmPermission,
      ).called(2);
      expect(app.notifications.preferences.medicationRemindersEnabled, isTrue);
    },
  );
  testWidgets(
    'editing the schedule preserves selected days and time through a failed write and retry',
    (tester) async {
      await open(tester);
      await edit(tester);
      await tester.tap(find.byKey(const ValueKey('reminder-day-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reminder-day-7')));
      await tester.enterText(find.byKey(const Key('reminder-time')), '1234');
      app.notifications.failSave = true;
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to save reminder settings'), findsOneWidget);
      expect(
        app.notifications.preferences.vaccinationSchedule,
        VaccinationReminderSchedule(),
      );
      app.notifications.failSave = false;
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      expect(
        app.notifications.preferences.vaccinationSchedule,
        VaccinationReminderSchedule(daysBefore: [7, 3, 0], minuteOfDay: 754),
      );
      expect(
        app.notifications.preferences.vaccinationRemindersEnabled,
        isFalse,
      );
      verifyNever(app.notifications.repository.requestNotificationPermission);
    },
  );
  testWidgets(
    'cancel and system back protect defaults drafts without persisting them',
    (tester) async {
      await open(tester);
      await edit(tester);
      await tester.tap(find.byKey(const ValueKey('reminder-day-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reminder-day-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('reminder-day-7')))
            .selected,
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      verifyNever(() => app.notifications.repository.savePreferences(any()));
      expect(find.text('Save changes'), findsNothing);
    },
  );
  testWidgets('a pending save blocks repeated changes and both Back paths', (
    tester,
  ) async {
    await open(tester);
    final gate = Completer<Result<void>>();
    when(
      () => app.notifications.repository.savePreferences(any()),
    ).thenAnswer((_) => gate.future);
    await tester.tap(toggle('Vaccination reminders'));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(toggle('Medication reminders')).onChanged,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.icon is BackButtonIcon,
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(NotificationSettingsPage), findsOneWidget);
    gate.complete(const Success(null));
    await tester.pumpAndSettle();
    verify(() => app.notifications.repository.savePreferences(any())).called(1);
  });
  testWidgets(
    'short narrow screens and large text keep fields and fixed save reachable above keyboard',
    (tester) async {
      await open(tester, size: const Size(320, 568), scale: 1.8);
      final title = find.text('Medication reminders');
      final element = tester.element(title);
      final text = tester.widget<Text>(title);
      final word = TextPainter(
        text: TextSpan(
          text: 'Medication',
          style: DefaultTextStyle.of(element).style.merge(text.style),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(element),
      )..layout();
      expect(tester.getSize(title).width, greaterThanOrEqualTo(word.width));
      word.dispose();
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(app.notifications.preferences.medicationRemindersEnabled, isTrue);
      await edit(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('reminder-time')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Save changes'),
      );
      expect(button.bottom, lessThanOrEqualTo(348));
      expect(button.top, greaterThanOrEqualTo(0));
    },
  );

  for (final theme in [ThemePreference.light, ThemePreference.dark]) {
    testWidgets(
      'schedule errors are visible without truncation in $theme on a narrow large-text screen',
      (tester) async {
        app.stored = theme;
        await open(tester, size: const Size(320, 568), scale: 1.8);
        await edit(tester);
        for (final day in [0, 1, 3]) {
          final chip = find.byKey(ValueKey('reminder-day-$day'));
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        final error = find.text('Select at least one day');
        expect(error.hitTestable(), findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
          isFalse,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('reminder-day-7')),
        );
        await tester.tap(find.byKey(const ValueKey('reminder-day-7')));
        final time = find.byKey(const Key('reminder-time'));
        await tester.ensureVisible(time);
        await tester.enterText(time, '9960');
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        final timeError = find.text('Use 00:00–23:59');
        expect(timeError.hitTestable(), findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(timeError).didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        verifyNever(() => app.notifications.repository.savePreferences(any()));
      },
    );
  }

  testWidgets(
    'preset choices and time stay usable with large text and keyboard bounds',
    (tester) async {
      await open(tester, size: const Size(320, 568), scale: 1.8);
      await edit(tester);
      final three = find.byKey(const ValueKey('reminder-day-3'));
      await tester.ensureVisible(three);
      await tester.tap(three);
      await tester.pump();
      final seven = find.byKey(const ValueKey('reminder-day-7'));
      await tester.ensureVisible(seven);
      await tester.tap(seven);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final time = find.byKey(const Key('reminder-time'));
      await tester.ensureVisible(time);
      await tester.enterText(time, '1030');
      final save = find.widgetWithText(ElevatedButton, 'Save changes');
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(348));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        app.notifications.preferences.vaccinationSchedule,
        VaccinationReminderSchedule(daysBefore: [7, 1, 0], minuteOfDay: 630),
      );
      expect(find.text('Add day'), findsNothing);
      expect(tester.takeException(), isNull);
      verifyNever(app.notifications.repository.requestNotificationPermission);
    },
  );
}
