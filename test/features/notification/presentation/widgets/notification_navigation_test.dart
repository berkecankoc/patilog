import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/router/app_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:patilog/features/all_pets_care/presentation/pages/all_pets_care_page.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';
import 'package:patilog/features/medication/presentation/pages/medication_detail_page.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_dose_calendar.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';
import 'package:patilog/features/vaccination/presentation/pages/vaccination_detail_page.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import '../../../../helpers/settings_test_harness.dart';

void main() {
  late SettingsTestHarness app;
  const target = VaccinationNotificationTarget(
    petId: 'pet',
    vaccinationId: 'vax',
    daysBefore: 0,
  );
  late Vaccination vaccination;
  setUpAll(SettingsTestHarness.initialize);
  setUp(() {
    app = SettingsTestHarness()..register();
    vaccination = Vaccination(
      id: 'vax',
      petId: 'pet',
      vaccineName: 'Rabies',
      status: VaccinationStatus.planned,
      date: DateTime.now().add(const Duration(days: 3)),
    );
    when(
      () => app.care.vaccinations.getVaccinationById('pet', 'vax'),
    ).thenAnswer((_) async => Success(vaccination));
  });
  Future<void> pump(
    WidgetTester tester, {
    String location = AppRoutes.settings,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await app.pump(tester, location: location);
  }

  Future<void> tap(WidgetTester tester, NotificationTarget value) async {
    app.notifications.taps.add(value);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cold-start target opens once with the current pet name and Back returns to its source',
    (tester) async {
      when(
        app.notifications.repository.initialize,
      ).thenAnswer((_) async => const Success(target));
      await pump(tester);
      expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      expect(find.text('Simba'), findsWidgets);
      expect(
        appRouter.state.uri.path,
        AppRoutes.vaccinationDetail('pet', 'vax'),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, AppRoutes.settings);
      verify(() => app.care.pets.getPetById('pet')).called(1);
    },
  );
  testWidgets(
    'missing or wrong-owner records keep the current screen and show an actionable explanation',
    (tester) async {
      when(
        () => app.care.vaccinations.getVaccinationById('pet', 'vax'),
      ).thenAnswer(
        (_) async => Success(
          Vaccination(
            id: 'vax',
            petId: 'other',
            vaccineName: 'Other pet',
            status: VaccinationStatus.planned,
            date: DateTime.now(),
          ),
        ),
      );
      await pump(tester);
      await tap(tester, target);
      expect(appRouter.state.uri.path, AppRoutes.settings);
      expect(
        find.text('This reminder’s record is no longer available.'),
        findsOneWidget,
      );
      expect(find.byType(VaccinationDetailPage), findsNothing);
    },
  );
  testWidgets(
    'a transient lookup failure retries the same target without permission prompts',
    (tester) async {
      when(
        () => app.care.vaccinations.getVaccinationById('pet', 'vax'),
      ).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Read failed')),
      );
      await pump(tester);
      await tap(tester, target);
      expect(find.text('Failed to open reminder'), findsOneWidget);
      when(
        () => app.care.vaccinations.getVaccinationById('pet', 'vax'),
      ).thenAnswer((_) async => Success(vaccination));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      verifyNever(app.notifications.repository.requestNotificationPermission);
    },
  );
  testWidgets(
    'notifications preserve a dirty form until the user explicitly leaves it',
    (tester) async {
      await pump(tester, location: AppRoutes.addEditPet);
      final name = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(name, 'Unsaved');
      await tap(tester, target);
      expect(appRouter.state.uri.path, AppRoutes.addEditPet);
      expect(tester.widget<TextFormField>(name).controller!.text, 'Unsaved');
      verifyNever(() => app.care.vaccinations.getVaccinationById(any(), any()));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, AppRoutes.addEditPet);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
    },
  );
  testWidgets(
    'a popup remains open until explicitly canceled before the reminder opens',
    (tester) async {
      await pump(tester, location: AppRoutes.notificationSettings);
      await tester.tap(find.text('Days & time'));
      await tester.pumpAndSettle();
      await tap(tester, target);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.byType(VaccinationDetailPage), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
    },
  );
  testWidgets('newest target wins while an older ownership lookup is pending', (
    tester,
  ) async {
    final gate = Completer<Result<Pet>>();
    when(
      () => app.care.pets.getPetById('delayed'),
    ).thenAnswer((_) => gate.future);
    await pump(tester);
    app.notifications.taps.add(
      const VaccinationNotificationTarget(
        petId: 'delayed',
        vaccinationId: 'old',
        daysBefore: 0,
      ),
    );
    await tester.pump();
    app.notifications.taps.add(target);
    await tester.pump();
    gate.complete(const Error(NotFoundFailure('Old target gone')));
    await tester.pumpAndSettle();
    expect(appRouter.state.uri.path, AppRoutes.vaccinationDetail('pet', 'vax'));
    expect(find.text('Old target gone'), findsNothing);
  });
  testWidgets(
    'a dose reminder opens its scheduled calendar day without recording a result',
    (tester) async {
      final medication = app.care.sample();
      app.care.medications.add(medication);
      await pump(tester);
      final day = DateTime(
        app.care.today.year,
        app.care.today.month,
        app.care.today.day - 1,
      );
      await tap(
        tester,
        MedicationDoseNotificationTarget(
          petId: 'pet',
          medicationId: medication.id,
          periodId: medication.periods.single.id,
          scheduledDate: day,
          scheduledMinute: 480,
        ),
      );
      expect(find.byType(MedicationDetailPage), findsOneWidget);
      expect(find.byType(MedicationDoseCalendar), findsOneWidget);
      final state =
          tester
                  .element(find.byType(MedicationDetailPage))
                  .read<MedicationCubit>()
                  .state
              as MedicationsLoaded;
      expect(DateUtils.isSameDay(state.doses.date, day), isTrue);
      verifyNever(() => app.care.repository.saveDoseLog(any(), any(), any()));
    },
  );

  testWidgets('successive reminders can open different care tabs for one pet', (
    tester,
  ) async {
    final medication = app.care.sample();
    app.care.medications.add(medication);
    await pump(tester);
    await tap(tester, target);
    await tap(
      tester,
      MedicationDoseNotificationTarget(
        petId: 'pet',
        medicationId: medication.id,
        periodId: medication.periods.single.id,
        scheduledDate: app.care.today,
        scheduledMinute: 480,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(MedicationDetailPage), findsOneWidget);
    verifyNever(() => app.care.repository.saveDoseLog(any(), any(), any()));
  });

  for (final notificationSettings in [false, true]) {
    testWidgets(
      'a reminder opens above ${notificationSettings ? 'notification settings' : 'Settings'} pushed over the pet directory',
      (tester) async {
        final medication = app.care.sample();
        app.care.medications.add(medication);
        await pump(tester, location: AppRoutes.pets);
        final directory = tester
            .element(find.byType(AllPetsCarePage))
            .read<AllPetsCareCubit>();
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        if (notificationSettings) {
          await tester.tap(find.text('Reminders'));
          await tester.pumpAndSettle();
        }
        await tap(
          tester,
          MedicationDoseNotificationTarget(
            petId: 'pet',
            medicationId: medication.id,
            periodId: medication.periods.single.id,
            scheduledDate: app.care.today,
            scheduledMinute: 480,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(MedicationDetailPage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          appRouter.state.uri.path,
          notificationSettings
              ? AppRoutes.notificationSettings
              : AppRoutes.settings,
        );
        if (notificationSettings) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        expect(appRouter.state.uri.path, AppRoutes.settings);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byType(AllPetsCarePage)).read<AllPetsCareCubit>(),
          same(directory),
        );
        verifyNever(() => app.care.repository.saveDoseLog(any(), any(), any()));
      },
    );
  }

  for (final location in [
    AppRoutes.allVetVisits,
    AppRoutes.allVaccinations,
    AppRoutes.allWeightHistory,
    AppRoutes.allMedications,
  ]) {
    testWidgets('idle global care tab $location does not block a reminder', (
      tester,
    ) async {
      await pump(tester, location: location);
      await tap(tester, target);
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
    });
  }
  testWidgets(
    'a global weight deletion finishes before a pending reminder opens',
    (tester) async {
      final entry = WeightEntry(
        id: 'measurement',
        petId: 'pet',
        weight: 4,
        measuredAt: app.care.today,
      );
      app.care.measurements = [entry];
      final pending = Completer<Result<void>>();
      when(() => app.care.weights.deleteWeightEntry(entry.id))
          .thenAnswer((_) => pending.future);
      await pump(tester, location: AppRoutes.allWeightHistory);
      final global = tester
          .element(find.byType(AllPetsCarePage))
          .read<WeightHistoryCubit>();
      final write = global.deleteWeightEntry(entry);
      await tester.pump();
      app.notifications.taps.add(target);
      await tester.pump(const Duration(milliseconds: 200));
      expect(appRouter.state.uri.path, AppRoutes.allWeightHistory);
      verifyNever(() => app.care.vaccinations.getVaccinationById(any(), any()));
      pending.complete(const Success(null));
      await write;
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
    },
  );
  testWidgets(
    'a failed global dose write finishes before the waiting reminder opens',
    (tester) async {
      app.care.medications.add(app.care.sample());
      app.care.pendingDose = Completer<Result<void>>();
      await pump(tester, location: AppRoutes.allMedications);
      final global = tester
          .element(find.byType(AllPetsCarePage))
          .read<MedicationCubit>();
      final saving = global.saveDose(
        (global.state as MedicationsLoaded).doses.doses.first,
        MedicationDoseStatus.given,
      );
      await tester.pump();
      app.notifications.taps.add(target);
      await tester.pump(const Duration(milliseconds: 200));
      expect(appRouter.state.uri.path, AppRoutes.allMedications);
      verifyNever(() => app.care.vaccinations.getVaccinationById(any(), any()));
      app.care.pendingDose!.complete(
        const Error(LocalDatabaseFailure('Dose save failed')),
      );
      await saving;
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      expect((global.state as MedicationsLoaded).actionError, isNotNull);
    },
  );
  testWidgets(
    'background delivery waits for resume before reading records or navigating',
    (tester) async {
      await pump(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tap(tester, target);
      expect(appRouter.state.uri.path, AppRoutes.settings);
      verifyNever(() => app.care.vaccinations.getVaccinationById(any(), any()));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
    },
  );
  testWidgets(
    'unmount during an ownership lookup never navigates after completion',
    (tester) async {
      final gate = Completer<Result<Pet>>();
      when(
        () => app.care.pets.getPetById('pet'),
      ).thenAnswer((_) => gate.future);
      await pump(tester);
      app.notifications.taps.add(target);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete(const Error(NotFoundFailure('Gone')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(appRouter.state.uri.path, AppRoutes.settings);
    },
  );
}
