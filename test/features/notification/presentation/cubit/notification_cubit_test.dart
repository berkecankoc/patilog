import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/notification/domain/entities/notification_permission_status.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_state.dart';
import '../../../../helpers/notification_test_harness.dart';

void main() {
  late NotificationTestHarness h;
  late NotificationCubit cubit;
  setUp(() {
    h = NotificationTestHarness();
    cubit = h.createCubit();
  });
  tearDown(() => h.dispose());

  test(
    'enabling feeding explicitly requests permissions and retains normal scheduling after exact denial',
    () async {
      h.permission = const NotificationPermissionStatus(
        canShowNotifications: true,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      h.feedingPlans.add(h.feedingPlan());
      await cubit.initialize();
      verifyNever(h.repository.requestExactAlarmPermission);
      await cubit.setPreferences(
        NotificationPreferences(feedingRemindersEnabled: true),
      );
      expect(cubit.state.preferences!.feedingRemindersEnabled, isTrue);
      expect(cubit.state.plan!.reminders, isNotEmpty);
      verify(h.repository.requestExactAlarmPermission).called(1);
      await cubit.refresh();
      verifyNever(h.repository.requestExactAlarmPermission);
    },
  );

  test(
    'known feeding deletion restores the future meal from the snapshot without clinical reads',
    () async {
      final plan = h.feedingPlan();
      h.feedingPlans.add(plan);
      h.feedingEntries.add(
        FeedingEntry(
          id: 'entry',
          petId: 'pet1',
          amountGrams: 40,
          givenAt: h.clock,
          mealId: plan.meals.single.id,
          scheduledDate: DateTime(2030, 1, 1),
        ),
      );
      h.preferences = NotificationPreferences(feedingRemindersEnabled: true);
      await cubit.initialize();
      expect(
        cubit.state.plan!.reminders.first.scheduledDate,
        DateTime(2030, 1, 2),
      );
      clearInteractions(h.feeding);
      clearInteractions(h.pets);
      await cubit.removeFeedingEntry('pet1', 'entry');
      expect(
        cubit.state.plan!.reminders.first.scheduledDate,
        DateTime(2030, 1, 1),
      );
      verifyZeroInteractions(h.feeding);
      verifyZeroInteractions(h.pets);
    },
  );

  test(
    'an earlier cancellation completing without a snapshot does not unlock a pending save',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      when(h.repository.getPermissionStatus).thenAnswer(
        (_) async => const Error(NotificationFailure('Status failed')),
      );
      await cubit.initialize();
      when(
        h.repository.getPermissionStatus,
      ).thenAnswer((_) async => Success(h.permission));
      final value = NotificationPreferences(
        medicationRemindersEnabled: true,
        vaccinationRemindersEnabled: true,
      );
      final gate = Completer<Result<void>>();
      when(
        () => h.repository.savePreferences(value),
      ).thenAnswer((_) => gate.future);
      final deleting = cubit.removeDeleted(petId: 'pet1', medicationId: 'med1');
      final saving = cubit.setPreferences(value);
      await deleting;
      final pending = cubit.state;
      final repeated = cubit.setPreferences(value);
      gate.complete(const Success(null));
      await saving;
      await repeated;
      expect(pending.isSaving, isTrue);
      expect(pending.isBusy, isTrue);
      verify(() => h.repository.savePreferences(value)).called(1);
    },
  );

  for (final action in [
    NotificationAction.notificationPermission,
    NotificationAction.exactPermission,
    NotificationAction.openSettings,
  ]) {
    test(
      'failed $action retries that operation, with no preference write',
      () async {
        await cubit.initialize();
        switch (action) {
          case NotificationAction.notificationPermission:
            when(h.repository.requestNotificationPermission).thenAnswer(
              (_) async =>
                  const Error(NotificationFailure('Permission failed')),
            );
          case NotificationAction.exactPermission:
            when(h.repository.requestExactAlarmPermission).thenAnswer(
              (_) async => const Error(NotificationFailure('Exact failed')),
            );
          default:
            when(h.repository.openNotificationSettings).thenAnswer(
              (_) async => const Error(NotificationFailure('Settings failed')),
            );
        }
        await cubit.perform(action);
        expect(cubit.state.issue!.action, action);
        when(
          h.repository.requestNotificationPermission,
        ).thenAnswer((_) async => Success(h.permission));
        when(
          h.repository.requestExactAlarmPermission,
        ).thenAnswer((_) async => Success(h.permission));
        when(
          h.repository.openNotificationSettings,
        ).thenAnswer((_) async => const Success(null));
        await cubit.retry();
        expect(cubit.state.issue, isNull);
        verifyNever(() => h.repository.savePreferences(any()));
        if (action != NotificationAction.openSettings) {
          expect(cubit.state.permissions, h.permission);
        }
      },
    );
  }

  test(
    'allowing notifications opens device settings only when they stay blocked',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      h.permission = const NotificationPermissionStatus(
        canShowNotifications: false,
        canScheduleExactAlarms: true,
        requiresExactAlarmPermission: true,
      );
      await cubit.initialize();
      await cubit.perform(NotificationAction.notificationPermission);
      verify(h.repository.requestNotificationPermission).called(1);
      verify(h.repository.openNotificationSettings).called(1);
      expect(cubit.state.issue, isNull);

      when(h.repository.openNotificationSettings).thenAnswer(
        (_) async => const Error(NotificationFailure('Settings failed')),
      );
      await cubit.perform(NotificationAction.notificationPermission);
      expect(
        cubit.state.issue?.action,
        NotificationAction.notificationPermission,
      );

      // An undecided permission answered with Allow needs no settings.
      h.permission = const NotificationPermissionStatus(
        canShowNotifications: true,
        canScheduleExactAlarms: true,
        requiresExactAlarmPermission: true,
      );
      clearInteractions(h.repository);
      await cubit.retry();
      verify(h.repository.requestNotificationPermission).called(1);
      verifyNever(h.repository.openNotificationSettings);
      expect(cubit.state.issue, isNull);
      expect(cubit.state.permissions?.canShowNotifications, isTrue);
    },
  );

  test(
    'an earlier refresh failure does not unlock a pending save or allow a duplicate',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      await cubit.initialize();
      var reads = 0;
      when(h.repository.getPermissionStatus).thenAnswer(
        (_) async => reads++ == 0
            ? const Error(NotificationFailure('Status failed'))
            : Success(h.permission),
      );
      final value = NotificationPreferences(
        medicationRemindersEnabled: true,
        vaccinationRemindersEnabled: true,
      );
      final gate = Completer<Result<void>>();
      when(
        () => h.repository.savePreferences(value),
      ).thenAnswer((_) => gate.future);
      final refreshing = cubit.refresh();
      final saving = cubit.setPreferences(value);
      await refreshing;
      final pending = cubit.state;
      final repeated = cubit.setPreferences(value);
      gate.complete(const Success(null));
      await saving;
      await repeated;
      expect(pending.isSaving, isTrue);
      expect(pending.isBusy, isTrue);
      verify(() => h.repository.savePreferences(value)).called(1);
    },
  );

  test(
    'an edit queued during initialization is included in the final native plan',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      final gate = Completer<Result<NotificationTarget?>>();
      when(h.repository.initialize).thenAnswer((_) => gate.future);
      final initializing = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      h.medicines.add(h.medication(id: 'new'));
      final refreshing = cubit.refresh();
      gate.complete(const Success(null));
      await initializing;
      await refreshing;
      expect(h.submissions, hasLength(1));
      expect(
        (h.submissions.single.first.target as MedicationDoseNotificationTarget)
            .medicationId,
        'new',
      );
    },
  );

  test(
    'a settings draft can save while automatic synchronization is already awaiting a read',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      await cubit.initialize();
      final gate = Completer<Result<NotificationPermissionStatus>>();
      var reads = 0;
      when(h.repository.getPermissionStatus).thenAnswer(
        (_) => reads++ == 0 ? gate.future : Future.value(Success(h.permission)),
      );
      final refreshing = cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isBusy, isTrue);
      final changed = NotificationPreferences(
        medicationRemindersEnabled: true,
        vaccinationRemindersEnabled: true,
      );
      final saving = cubit.setPreferences(changed);
      gate.complete(Success(h.permission));
      await refreshing;
      await saving;
      expect(cubit.state.preferences, changed);
      verify(() => h.repository.savePreferences(changed)).called(1);
    },
  );

  test(
    'a deletion during a denied-permission startup still clears the blocked queue',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      const denied = NotificationPermissionStatus(
        canShowNotifications: false,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      final gate = Completer<Result<NotificationPermissionStatus>>();
      when(h.repository.getPermissionStatus).thenAnswer((_) => gate.future);
      final initializing = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      final deleted = cubit.removeDeleted(petId: 'pet1', medicationId: 'med1');
      gate.complete(const Success(denied));
      await initializing;
      await deleted;
      expect(h.submissions, hasLength(1));
      expect(h.submissions.single, isEmpty);
      verifyZeroInteractions(h.medications);
    },
  );

  blocTest<NotificationCubit, NotificationState>(
    'initializes disabled defaults and clears owned reminders without prompting or clinical reads',
    build: () => cubit,
    act: (cubit) => cubit.initialize(),
    expect: () => [
      const NotificationState(isBusy: true),
      NotificationState(isBusy: true, preferences: NotificationPreferences()),
      isA<NotificationState>()
          .having((s) => s.isBusy, 'busy', false)
          .having((s) => s.plan!.reminders, 'empty queue', isEmpty),
    ],
    verify: (_) {
      verifyNever(h.repository.requestNotificationPermission);
      verifyNever(h.repository.requestExactAlarmPermission);
      verifyZeroInteractions(h.medications);
      verifyZeroInteractions(h.pets);
      verifyZeroInteractions(h.vaccinations);
    },
  );

  test(
    'planned medication and vaccination reminders share one budget and coverage state',
    () async {
      h.preferences = NotificationPreferences(
        medicationRemindersEnabled: true,
        vaccinationRemindersEnabled: true,
      );
      h.medicines.add(h.medication());
      h.vaccines.add(h.vaccination());
      await cubit.initialize();
      expect(h.submissions.single, hasLength(64));
      expect(cubit.state.plan!.hasMore, isTrue);
      expect(cubit.state.lastSyncedAt, h.clock);
      expect(cubit.state.issue, isNull);
    },
  );

  test(
    'native initialization failure can retry and does not read clinical data',
    () async {
      when(h.repository.initialize).thenAnswer(
        (_) async => const Error(NotificationFailure('Init failed')),
      );
      await cubit.initialize();
      expect(cubit.state.issue!.action, NotificationAction.initialize);
      verifyZeroInteractions(h.pets);
      when(
        h.repository.initialize,
      ).thenAnswer((_) async => const Success(null));
      await cubit.retry();
      expect(cubit.state.issue, isNull);
      expect(cubit.state.preferences, isNotNull);
    },
  );

  test(
    'preference read failure remains unknown and is retried without reinitializing native state',
    () async {
      when(h.repository.getPreferences).thenAnswer(
        (_) async => const Error(PreferencesStorageFailure('Prefs failed')),
      );
      await cubit.initialize();
      expect(cubit.state.preferences, isNull);
      expect(cubit.state.issue!.message, 'Prefs failed');
      expect(h.submissions, isEmpty);
      when(
        h.repository.getPreferences,
      ).thenAnswer((_) async => Success(h.preferences));
      await cubit.retry();
      verify(h.repository.initialize).called(1);
      expect(cubit.state.issue, isNull);
    },
  );

  test(
    'failed log reads preserve native queue and retry loads canonical results',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      h.medicines.add(h.medication());
      when(
        () => h.medications.getAllDoseLogs(
          fromDate: any(named: 'fromDate'),
          toDate: any(named: 'toDate'),
        ),
      ).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Logs failed')),
      );
      await cubit.initialize();
      expect(h.submissions, isEmpty);
      expect(cubit.state.issue!.message, 'Logs failed');
      when(
        () => h.medications.getAllDoseLogs(
          fromDate: any(named: 'fromDate'),
          toDate: any(named: 'toDate'),
        ),
      ).thenAnswer((_) async => const Success([]));
      await cubit.retry();
      expect(h.submissions.single, hasLength(64));
      expect(cubit.state.issue, isNull);
    },
  );

  test(
    'Given and Skipped writes remove a future-today reminder on refresh',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      h.medicines.add(h.medication(end: DateTime(2030, 1, 1)));
      await cubit.initialize();
      expect(h.submissions.last, hasLength(1));
      for (final status in MedicationDoseStatus.values) {
        h.logs
          ..clear()
          ..add(
            MedicationDoseLog(
              periodId: 'period-med1',
              scheduledDate: DateTime(2030, 1, 1),
              scheduledMinute: 720,
              status: status,
              givenAt: status == MedicationDoseStatus.given ? h.clock : null,
            ),
          );
        await cubit.refresh();
        expect(h.submissions.last, isEmpty);
      }
      h.logs.clear();
      await cubit.refresh();
      expect(h.submissions.last, hasLength(1));
    },
  );

  for (final type in ['pet', 'medication', 'vaccination']) {
    test(
      'known $type deletion cancels by ID and rebuilds from cache without source reads',
      () async {
        h.preferences = NotificationPreferences(
          medicationRemindersEnabled: true,
          vaccinationRemindersEnabled: true,
        );
        h.medicines.addAll([
          h.medication(),
          h.medication(id: 'other', petId: 'pet2'),
        ]);
        h.vaccines.addAll([
          h.vaccination(),
          h.vaccination(id: 'other', petId: 'pet2'),
        ]);
        await cubit.initialize();
        clearInteractions(h.medications);
        clearInteractions(h.vaccinations);
        clearInteractions(h.pets);
        await cubit.removeDeleted(
          petId: 'pet1',
          petDeleted: type == 'pet',
          medicationId: type == 'medication' ? 'med1' : null,
          vaccinationId: type == 'vaccination' ? 'vax1' : null,
        );
        expect(h.cancellations, [
          type == 'pet'
              ? 'pet:pet1'
              : type == 'medication'
              ? 'med:pet1:med1'
              : 'vax:pet1:vax1',
        ]);
        final targets = h.submissions.last.map((r) => r.target);
        if (type == 'pet') {
          expect(targets.every((t) => t.petId == 'pet2'), isTrue);
        } else if (type == 'medication') {
          expect(
            targets.whereType<MedicationDoseNotificationTarget>().any(
              (t) => t.medicationId == 'med1',
            ),
            isFalse,
          );
        } else {
          expect(
            targets.whereType<VaccinationNotificationTarget>().any(
              (t) => t.vaccinationId == 'vax1',
            ),
            isFalse,
          );
        }
        verifyZeroInteractions(h.medications);
        verifyZeroInteractions(h.vaccinations);
        verifyZeroInteractions(h.pets);
      },
    );
  }

  test(
    'failed deletion cancellation retries the intended cancellation without rereading the source',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      h.medicines.add(h.medication());
      await cubit.initialize();
      h.failCancel = true;
      await cubit.removeDeleted(petId: 'pet1', medicationId: 'med1');
      clearInteractions(h.medications);
      clearInteractions(h.pets);
      h.failCancel = false;
      await cubit.retry();
      expect(h.cancellations, ['med:pet1:med1', 'med:pet1:med1']);
      expect(h.submissions.last, isEmpty);
      verifyZeroInteractions(h.medications);
      verifyZeroInteractions(h.pets);
    },
  );

  test(
    'deleting while a slow read is pending never reschedules the stale record',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      final medication = h.medication();
      final loaded = Completer<Result<List<Medication>>>();
      when(h.medications.getAllMedications).thenAnswer((_) => loaded.future);
      final initializing = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      final deleted = cubit.removeDeleted(petId: 'pet1', medicationId: 'med1');
      loaded.complete(Success([medication]));
      await initializing;
      await deleted;
      expect(h.submissions, hasLength(1));
      expect(h.submissions.single, isEmpty);
      verify(h.medications.getAllMedications).called(1);
    },
  );

  test(
    'enabling medication requests permission and exact access, then persists and syncs',
    () async {
      await cubit.initialize();
      h.permission = const NotificationPermissionStatus(
        canShowNotifications: false,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      when(h.repository.requestNotificationPermission).thenAnswer((_) async {
        h.permission = const NotificationPermissionStatus(
          canShowNotifications: true,
          canScheduleExactAlarms: false,
          requiresExactAlarmPermission: true,
        );
        return Success(h.permission);
      });
      final value = NotificationPreferences(medicationRemindersEnabled: true);
      await cubit.setPreferences(value);
      expect(cubit.state.preferences, value);
      expect(cubit.state.permissions!.canScheduleExactAlarms, isFalse);
      expect(cubit.state.saveError, isNull);
      verify(h.repository.requestNotificationPermission).called(1);
      verify(h.repository.requestExactAlarmPermission).called(1);
    },
  );

  test(
    'permission denial still stores the requested preference but schedules nothing',
    () async {
      await cubit.initialize();
      h.permission = const NotificationPermissionStatus(
        canShowNotifications: false,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      final value = NotificationPreferences(vaccinationRemindersEnabled: true);
      await cubit.setPreferences(value);
      expect(cubit.state.preferences, value);
      expect(cubit.state.plan!.reminders, isEmpty);
      expect(cubit.state.issue, isNull);
      verifyNever(h.repository.requestExactAlarmPermission);
      verifyZeroInteractions(h.vaccinations);
    },
  );

  test(
    'saving failure retains prior settings and an actionable retry, including during automatic sync',
    () async {
      await cubit.initialize();
      h.failSave = true;
      final value = NotificationPreferences(vaccinationRemindersEnabled: true);
      await cubit.setPreferences(value);
      expect(cubit.state.preferences, NotificationPreferences());
      expect(cubit.state.failedPreferences, value);
      await cubit.refresh();
      expect(cubit.state.saveError, 'Save failed');
      h.failSave = false;
      await cubit.retrySave();
      expect(cubit.state.preferences, value);
      expect(cubit.state.failedPreferences, isNull);
    },
  );

  test(
    'successful preference save followed by sync failure retries sync without saving again',
    () async {
      await cubit.initialize();
      h.failSync = true;
      final value = NotificationPreferences(medicationRemindersEnabled: true);
      await cubit.setPreferences(value);
      expect(cubit.state.preferences, value);
      expect(cubit.state.saveError, isNull);
      expect(cubit.state.issue!.action, NotificationAction.synchronize);
      h.failSync = false;
      await cubit.retry();
      verify(() => h.repository.savePreferences(value)).called(1);
      expect(cubit.state.issue, isNull);
    },
  );

  test(
    'turning all categories Off cancels even if permission reads fail',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      await cubit.initialize();
      when(h.repository.getPermissionStatus).thenAnswer(
        (_) async => const Error(NotificationFailure('Status failed')),
      );
      await cubit.setPreferences(NotificationPreferences());
      expect(h.submissions.last, isEmpty);
      expect(cubit.state.issue, isNull);
    },
  );

  test(
    'pre-frame duplicate saves are blocked and unchanged values do not resubmit',
    () async {
      await cubit.initialize();
      final value = NotificationPreferences(vaccinationRemindersEnabled: true);
      final gate = Completer<Result<void>>();
      when(
        () => h.repository.savePreferences(value),
      ).thenAnswer((_) => gate.future);
      final first = cubit.setPreferences(value);
      final repeated = cubit.setPreferences(value);
      await Future<void>.delayed(Duration.zero);
      gate.complete(const Success(null));
      await first;
      await repeated;
      await cubit.setPreferences(value);
      verify(() => h.repository.savePreferences(value)).called(1);
    },
  );

  test('cold and warm tap targets remain pending until acknowledged', () async {
    const target = VaccinationNotificationTarget(
      petId: 'pet1',
      vaccinationId: 'vax1',
      daysBefore: 0,
    );
    when(
      h.repository.initialize,
    ).thenAnswer((_) async => const Success(target));
    await cubit.initialize();
    expect(cubit.state.pendingTarget, target);
    cubit.acknowledgeTarget();
    expect(cubit.state.pendingTarget, isNull);
    h.taps.add(target);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.pendingTarget, target);
  });

  test(
    'foreground clock checks only reload when due, at day change or backward clock movement',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      h.medicines.add(h.medication());
      await cubit.initialize();
      clearInteractions(h.medications);
      h.clock = DateTime(2030, 1, 1, 11);
      await cubit.refreshForClockChange();
      verifyZeroInteractions(h.medications);
      h.clock = DateTime(2030, 1, 1, 12);
      await cubit.refreshForClockChange();
      verify(h.medications.getAllMedications).called(1);
      h.clock = DateTime(2030, 1, 1, 11);
      await cubit.refreshForClockChange();
      verify(h.medications.getAllMedications).called(1);
    },
  );

  test(
    'closing during an awaited read does not emit or schedule afterward',
    () async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      final gate = Completer<Result<List<Medication>>>();
      when(h.medications.getAllMedications).thenAnswer((_) => gate.future);
      final initializing = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      gate.complete(const Success([]));
      await initializing;
      expect(h.submissions, isEmpty);
    },
  );

  group('reminder offer after a saved record', () {
    const denied = NotificationPermissionStatus(
      canShowNotifications: false,
      canScheduleExactAlarms: false,
      requiresExactAlarmPermission: true,
    );

    test(
      'offers a disabled, unoffered category for a current record',
      () async {
        await cubit.initialize();
        await cubit.offerReminders(ReminderCategory.medication);
        expect(cubit.state.reminderOffer, ReminderCategory.medication);
        verifyNever(h.repository.requestNotificationPermission);
      },
    );

    test('a record ending today still reminds and is offered', () async {
      await cubit.initialize();
      await cubit.offerReminders(
        ReminderCategory.feeding,
        lastDay: DateTime(2030, 1, 1),
      );
      expect(cubit.state.reminderOffer, ReminderCategory.feeding);
    });

    test(
      'enabled, already offered or ended categories are not offered',
      () async {
        h.preferences = NotificationPreferences(
          medicationRemindersEnabled: true,
          offeredCategories: {ReminderCategory.vaccination},
        );
        await cubit.initialize();
        await cubit.offerReminders(ReminderCategory.medication);
        await cubit.offerReminders(ReminderCategory.vaccination);
        await cubit.offerReminders(
          ReminderCategory.feeding,
          lastDay: DateTime(2029, 12, 31),
        );
        expect(cubit.state.reminderOffer, isNull);
      },
    );

    test('no offer appears when preferences could not be read', () async {
      when(h.repository.getPreferences).thenAnswer(
        (_) async => const Error(PreferencesStorageFailure('Read failed')),
      );
      await cubit.initialize();
      await cubit.offerReminders(ReminderCategory.medication);
      expect(cubit.state.reminderOffer, isNull);
    });

    test('accepting enables the category and asks only for notification permission', () async {
      h.permission = denied;
      when(h.repository.requestNotificationPermission).thenAnswer(
        (_) async => const Success(
          NotificationPermissionStatus(
            canShowNotifications: true,
            canScheduleExactAlarms: false,
            requiresExactAlarmPermission: true,
          ),
        ),
      );
      h.medicines.add(h.medication(start: DateTime(2030, 1, 2)));
      await cubit.initialize();
      await cubit.offerReminders(ReminderCategory.medication);
      await cubit.answerReminderOffer(accepted: true);
      expect(cubit.state.reminderOffer, isNull);
      expect(h.preferences.medicationRemindersEnabled, isTrue);
      expect(h.preferences.offeredCategories, {ReminderCategory.medication});
      expect(cubit.state.preferences, h.preferences);
      verify(h.repository.requestNotificationPermission).called(1);
      verifyNever(h.repository.requestExactAlarmPermission);
    });

    test('accepting while the system blocks notifications keeps the choice and reports it', () async {
      h.permission = denied;
      await cubit.initialize();
      await cubit.offerReminders(ReminderCategory.vaccination);
      await cubit.answerReminderOffer(accepted: true);
      expect(h.preferences.vaccinationRemindersEnabled, isTrue);
      expect(cubit.state.permissions?.canShowNotifications, isFalse);
      expect(cubit.state.saveError, isNull);
    });

    test('declining records the offer without permission prompts', () async {
      h.permission = denied;
      await cubit.initialize();
      await cubit.offerReminders(ReminderCategory.feeding);
      await cubit.answerReminderOffer(accepted: false);
      expect(h.preferences.feedingRemindersEnabled, isFalse);
      expect(h.preferences.offeredCategories, {ReminderCategory.feeding});
      verifyNever(h.repository.requestNotificationPermission);
      await cubit.offerReminders(ReminderCategory.feeding);
      expect(cubit.state.reminderOffer, isNull);
    });

    test('a failed save keeps the accepted choice for a retry without precise timing', () async {
      h.permission = const NotificationPermissionStatus(
        canShowNotifications: true,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      h.failSave = true;
      await cubit.initialize();
      await cubit.offerReminders(ReminderCategory.feeding);
      await cubit.answerReminderOffer(accepted: true);
      expect(cubit.state.saveError, 'Save failed');
      expect(cubit.state.preferences!.feedingRemindersEnabled, isFalse);
      h.failSave = false;
      await cubit.retrySave();
      expect(cubit.state.saveError, isNull);
      expect(cubit.state.preferences!.feedingRemindersEnabled, isTrue);
      verifyNever(h.repository.requestExactAlarmPermission);
    });
  });
}
