import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/l10n/app_locale.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/notification/domain/entities/notification_channel_labels.dart';
import 'package:patilog/features/notification/domain/entities/notification_permission_status.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/notification_reminder.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_state.dart';
import 'package:patilog/features/notification/presentation/utils/notification_content.dart';
import 'package:patilog/l10n/generated/app_localizations_tr.dart';

import '../../../../helpers/notification_test_harness.dart';

void main() {
  late NotificationTestHarness h;
  late NotificationCubit cubit;
  final turkish = NotificationContent(
    AppLocalizationsTr('tr_TR'),
    turkishLocale,
  );
  setUpAll(() => initializeDateFormatting());
  setUp(() {
    h = NotificationTestHarness();
    h.preferences = NotificationPreferences(
      medicationRemindersEnabled: true,
      vaccinationRemindersEnabled: true,
    );
    h.medicines.add(h.medication());
    h.vaccines.add(h.vaccination());
    cubit = h.createCubit();
  });
  tearDown(() => h.dispose());

  test(
    'the first submitted plan uses the selected language without an English queue first',
    () async {
      await cubit.setContent(turkish);
      expect(h.submissions, isEmpty);
      await cubit.initialize();
      expect(h.submissions, hasLength(1));
      expect(h.submissions.single.first.body, 'Planlanan doz · 12:00');
      expect(h.channelSubmissions.single, turkish.channels);
      verify(h.repository.initialize).called(1);
      verifyNever(h.repository.requestNotificationPermission);
      verifyNever(h.repository.requestExactAlarmPermission);
    },
  );

  test(
    'locale-only updates retain targets, times, order and pending taps without clinical rereads',
    () async {
      await cubit.initialize();
      final before = cubit.state.plan!.reminders;
      final target = before.first.target;
      cubit.requestOpen(target);
      clearInteractions(h.pets);
      clearInteractions(h.medications);
      clearInteractions(h.vaccinations);
      await cubit.setContent(turkish);
      final after = cubit.state.plan!.reminders;
      expect(
        after.map(
          (r) => (r.target.identityKey, r.scheduledDate, r.scheduledMinute),
        ),
        orderedEquals(
          before.map(
            (r) => (r.target.identityKey, r.scheduledDate, r.scheduledMinute),
          ),
        ),
      );
      expect(after.first.body, 'Planlanan doz · 12:00');
      expect(cubit.state.pendingTarget, target);
      verifyZeroInteractions(h.pets);
      verifyZeroInteractions(h.medications);
      verifyZeroInteractions(h.vaccinations);
      final count = h.submissions.length;
      await cubit.setContent(
        NotificationContent(AppLocalizationsTr('tr_TR'), turkishLocale),
      );
      expect(h.submissions, hasLength(count));
      verifyNever(h.repository.requestNotificationPermission);
      verifyNever(h.repository.requestExactAlarmPermission);
    },
  );

  test(
    'a language change during initialization submits only the final localized plan',
    () async {
      final gate = Completer<Result<NotificationPreferences>>();
      when(h.repository.getPreferences).thenAnswer((_) => gate.future);
      final initialization = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      final changing = cubit.setContent(turkish);
      gate.complete(Success(h.preferences));
      await Future.wait([initialization, changing]);
      expect(h.submissions, hasLength(1));
      expect(h.submissions.single.first.body, 'Planlanan doz · 12:00');
      expect(cubit.state.isBusy, isFalse);
      verify(h.repository.initialize).called(1);
    },
  );

  test(
    'rapid locale changes during a native write are serialized and the final language wins',
    () async {
      final gate = Completer<Result<void>>();
      var attempts = 0;
      when(
        () => h.repository.synchronizeReminders(
          any(),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer((call) async {
        h.submissions.add(
          List.of(
            call.positionalArguments.single as List<NotificationReminder>,
          ),
        );
        h.channelSubmissions.add(
          call.namedArguments[#channels] as NotificationChannelLabels,
        );
        return attempts++ == 0 ? gate.future : const Success(null);
      });
      final initialization = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      final toTurkish = cubit.setContent(turkish);
      final toEnglish = cubit.setContent(englishNotificationContent);
      gate.complete(const Success(null));
      await Future.wait([initialization, toTurkish, toEnglish]);
      expect(h.submissions, hasLength(2));
      expect(h.submissions.last.first.body, 'Scheduled dose · 12:00');
      expect(h.channelSubmissions.last, englishNotificationContent.channels);
      expect(cubit.state.isBusy, isFalse);
      expect(
        h.submissions.last.map((r) => r.target.identityKey).toSet(),
        hasLength(h.submissions.last.length),
      );
    },
  );

  test(
    'a locale change during preferences saving neither unlocks nor duplicates the write',
    () async {
      await cubit.initialize();
      final value = NotificationPreferences(medicationRemindersEnabled: true);
      final gate = Completer<Result<void>>();
      when(
        () => h.repository.savePreferences(value),
      ).thenAnswer((_) => gate.future);
      final saving = cubit.setPreferences(value);
      await Future<void>.delayed(Duration.zero);
      final changing = cubit.setContent(turkish);
      expect(cubit.state.isSaving, isTrue);
      expect(cubit.state.isBusy, isTrue);
      await cubit.setPreferences(value);
      gate.complete(const Success(null));
      await Future.wait([saving, changing]);
      expect(cubit.state.preferences, value);
      expect(cubit.state.isSaving, isFalse);
      expect(cubit.state.isBusy, isFalse);
      expect(h.submissions.last.first.body, 'Planlanan doz · 12:00');
      verify(() => h.repository.savePreferences(value)).called(1);
    },
  );

  test(
    'failed settings and device actions remain actionable after a locale-only synchronization',
    () async {
      await cubit.initialize();
      h.failSave = true;
      final value = NotificationPreferences(vaccinationRemindersEnabled: true);
      await cubit.setPreferences(value);
      when(h.repository.openNotificationSettings).thenAnswer(
        (_) async =>
            const Error(NotificationFailure('Private native diagnostic')),
      );
      await cubit.perform(NotificationAction.openSettings);
      await cubit.setContent(turkish);
      expect(cubit.state.saveError, 'Save failed');
      expect(cubit.state.failedPreferences, value);
      expect(cubit.state.issue!.action, NotificationAction.openSettings);
      when(
        h.repository.openNotificationSettings,
      ).thenAnswer((_) async => const Success(null));
      await cubit.retry();
      verify(h.repository.openNotificationSettings).called(2);
      expect(cubit.state.issue, isNull);
      expect(cubit.state.saveError, 'Save failed');
    },
  );

  test(
    'a failed locale synchronization retries using the current language',
    () async {
      await cubit.initialize();
      h.failSync = true;
      await cubit.setContent(turkish);
      expect(cubit.state.issue!.action, NotificationAction.synchronize);
      h.failSync = false;
      await cubit.retry();
      expect(cubit.state.issue, isNull);
      expect(h.submissions.last.first.body, 'Planlanan doz · 12:00');
      expect(h.channelSubmissions.last, turkish.channels);
    },
  );

  test(
    'a locale update queued during deletion cannot resurrect the removed medication',
    () async {
      await cubit.initialize();
      clearInteractions(h.pets);
      clearInteractions(h.medications);
      clearInteractions(h.vaccinations);
      final gate = Completer<Result<void>>();
      when(
        () => h.repository.cancelMedicationReminders('pet1', 'med1'),
      ).thenAnswer((_) => gate.future);
      final deleting = cubit.removeDeleted(petId: 'pet1', medicationId: 'med1');
      await Future<void>.delayed(Duration.zero);
      final changing = cubit.setContent(turkish);
      gate.complete(const Success(null));
      await Future.wait([deleting, changing]);
      expect(
        h.submissions.last.every(
          (r) => r.target is VaccinationNotificationTarget,
        ),
        isTrue,
      );
      expect(h.submissions.last, hasLength(2));
      expect(
        h.submissions.last.every((r) => r.body.startsWith('Aşı tarihi:')),
        isTrue,
      );
      verifyZeroInteractions(h.pets);
      verifyZeroInteractions(h.medications);
      verifyZeroInteractions(h.vaccinations);
    },
  );

  test(
    'denied notifications keep an empty queue while channel labels follow the locale',
    () async {
      h.permission = const NotificationPermissionStatus(
        canShowNotifications: false,
        canScheduleExactAlarms: false,
        requiresExactAlarmPermission: true,
      );
      await cubit.initialize();
      await cubit.setContent(turkish);
      expect(h.submissions.last, isEmpty);
      expect(h.channelSubmissions.last, turkish.channels);
      verifyNever(h.pets.getPets);
      verifyNever(h.repository.requestNotificationPermission);
    },
  );

  test('a closed Cubit ignores a language change', () async {
    await cubit.initialize();
    await cubit.close();
    final count = h.submissions.length;
    await cubit.setContent(turkish);
    expect(h.submissions, hasLength(count));
  });

  test(
    'a locale change after midnight reads the current day instead of reusing yesterday’s dose results',
    () async {
      await cubit.initialize();
      clearInteractions(h.medications);
      h.clock = DateTime(2030, 1, 2, 10);
      h.logs.add(
        MedicationDoseLog(
          periodId: 'period-med1',
          scheduledDate: DateTime(2030, 1, 2),
          scheduledMinute: 720,
          status: MedicationDoseStatus.given,
          givenAt: h.clock,
        ),
      );
      await cubit.setContent(turkish);
      verify(
        () => h.medications.getAllDoseLogs(
          fromDate: DateTime(2030, 1, 2),
          toDate: DateTime(2030, 1, 2),
        ),
      ).called(1);
      expect(
        h.submissions.last.where(
          (r) =>
              r.target is MedicationDoseNotificationTarget &&
              r.scheduledDate == DateTime(2030, 1, 2),
        ),
        isEmpty,
      );
      expect(h.submissions.last.first.body.startsWith('Aşı tarihi:'), isTrue);
      expect(cubit.state.isBusy, isFalse);
    },
  );
}
