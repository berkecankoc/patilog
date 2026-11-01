import 'package:flutter/material.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:petlytics/features/notification/presentation/widgets/notification_runtime.dart';
import '../../../../helpers/notification_test_harness.dart';

void main() {
  late NotificationTestHarness h;
  late NotificationCubit cubit;
  late CareRecordChanges changes;
  setUp(() {
    h = NotificationTestHarness();
    changes = CareRecordChanges();
  });
  tearDown(() async {
    changes.dispose();
    await h.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    cubit = h.createCubit();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: CareRecordChangeScope(
          changes: changes,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: appSupportedLocales,
            locale: englishLocale,
            home: NotificationRuntime(child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async => tester.pumpWidget(const SizedBox()));
  }

  testWidgets(
    'starts once and responds to global/current-list mutations without permission prompts',
    (tester) async {
      await pump(tester);
      expect(h.submissions, hasLength(1));
      changes.changed(
        'pet1',
        PetCareTab.medications,
        globalListIsCurrent: true,
      );
      await tester.pumpAndSettle();
      expect(h.submissions, hasLength(2));
      verify(h.repository.initialize).called(1);
      verifyNever(h.repository.requestNotificationPermission);
      verifyNever(h.repository.requestExactAlarmPermission);
    },
  );

  testWidgets(
    'known delete uses cached data, while weight-only and visit-link deletions do not replan',
    (tester) async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      h.medicines.add(h.medication());
      await pump(tester);
      clearInteractions(h.medications);
      clearInteractions(h.pets);
      changes.changed('pet1', PetCareTab.medications, deletedId: 'med1');
      await tester.pumpAndSettle();
      expect(h.cancellations, ['med:pet1:med1']);
      expect(h.submissions.last, isEmpty);
      verifyZeroInteractions(h.medications);
      verifyZeroInteractions(h.pets);
      final count = h.submissions.length;
      changes.changed('pet1', PetCareTab.weightHistory);
      changes.changed('pet1', PetCareTab.vetVisits, deletedId: 'visit1');
      await tester.pumpAndSettle();
      expect(h.submissions, hasLength(count));
    },
  );

  testWidgets(
    'resume refreshes and background clock ticks do not read sources',
    (tester) async {
      h.preferences = NotificationPreferences(medicationRemindersEnabled: true);
      h.medicines.add(h.medication());
      await pump(tester);
      final count = h.submissions.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      h.clock = DateTime(2030, 1, 1, 13);
      await tester.pump(const Duration(minutes: 2));
      expect(h.submissions, hasLength(count));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.submissions.length, greaterThan(count));
    },
  );

  testWidgets(
    'unmounting removes listeners and timers without closing the externally owned bus',
    (tester) async {
      await pump(tester);
      final count = h.submissions.length;
      await tester.pumpWidget(const SizedBox());
      changes.changed('pet1', PetCareTab.vaccinations);
      await tester.pump(const Duration(minutes: 2));
      expect(h.submissions, hasLength(count));
    },
  );
}
