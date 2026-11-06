import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_dose_calendar.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:petlytics/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';

import '../../helpers/settings_test_harness.dart';

void main() {
  late SettingsTestHarness app;

  setUpAll(() async {
    await SettingsTestHarness.initialize();
    registerFallbackValue(
      VetVisit(
        id: 'fallback',
        petId: 'pet',
        visitedOn: DateTime(2026),
        reason: 'Fallback',
      ),
    );
    registerFallbackValue(
      Vaccination(
        id: 'fallback',
        petId: 'pet',
        vaccineName: 'Fallback',
        status: VaccinationStatus.planned,
        date: DateTime(2026),
      ),
    );
    registerFallbackValue(
      WeightEntry(
        id: 'fallback',
        petId: 'pet',
        weight: 1,
        measuredAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    app = SettingsTestHarness()..register();
    app.storedLanguage = LanguagePreference.turkish;
    getIt.registerFactory<VetVisitFormCubit>(
      () => VetVisitFormCubit(app.care.visits, app.care.ids),
    );
    getIt.registerFactory<VaccinationFormCubit>(
      () => VaccinationFormCubit(
        app.care.vaccinations,
        app.care.visits,
        SaveVaccination(app.care.vaccinations, app.care.ids),
      ),
    );
    when(
      () => app.care.vaccinations.getSuggestions(
        clinicName: any(named: 'clinicName'),
      ),
    ).thenAnswer(
      (_) async => const Success(
        VaccinationSuggestions(
          vaccineNames: [],
          clinicNames: [],
          veterinarianNames: [],
        ),
      ),
    );
  });

  Future<void> open(WidgetTester tester, String route) async {
    await app.pump(tester, location: AppRoutes.pets);
    unawaited(appRouter.push<bool>(route));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'visit errors translate in place and a failed save retains the Unicode draft',
    (tester) async {
      when(() => app.care.visits.createVetVisit(any())).thenAnswer(
        (_) async =>
            const Error(LocalDatabaseFailure('Private SQL diagnostic')),
      );
      await open(tester, AppRoutes.addEditVetVisit('pet'));
      final form = tester.state(find.byType(AppMultiStepForm));
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Ziyaret nedenini girin'), findsOneWidget);
      await app.cubit.setLanguagePreference(LanguagePreference.english);
      await tester.pumpAndSettle();
      expect(find.text('Enter a reason for the visit'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('visit-reason')),
        'İnci 🐾 kontrol',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await app.cubit.setLanguagePreference(LanguagePreference.turkish);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(AppMultiStepForm)), same(form));
      expect(find.text('İnci 🐾 kontrol'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ziyaret ekle'));
      await tester.pumpAndSettle();
      expect(
        find.text('Veteriner ziyareti eklenemedi').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Private SQL diagnostic'), findsNothing);
      expect(find.text('İnci 🐾 kontrol'), findsOneWidget);
      expect(
        verify(
          () => app.care.visits.createVetVisit(captureAny()),
        ).captured.single,
        isA<VetVisit>().having(
          (visit) => visit.reason,
          'reason',
          'İnci 🐾 kontrol',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'vaccination validation and review keep the same date and name across languages',
    (tester) async {
      when(
        () => app.care.vaccinations.createVaccination(
          any(),
          nextDose: any(named: 'nextDose'),
        ),
      ).thenAnswer(
        (_) async =>
            const Error(LocalDatabaseFailure('Private vaccine diagnostic')),
      );
      await open(tester, AppRoutes.addEditVaccination('pet'));
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Aşı adını girin'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('vaccination-name')),
        'Kuduz 🐾',
      );
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Kuduz 🐾'), findsOneWidget);
      await app.cubit.setLanguagePreference(LanguagePreference.english);
      await tester.pumpAndSettle();
      expect(find.text('Kuduz 🐾'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add vaccination'));
      await tester.pumpAndSettle();
      expect(
        find.text('Failed to create vaccination').hitTestable(),
        findsOneWidget,
      );
      await app.cubit.setLanguagePreference(LanguagePreference.turkish);
      await tester.pumpAndSettle();
      expect(find.text('Aşı eklenemedi').hitTestable(), findsOneWidget);
      final record =
          verify(
                () => app.care.vaccinations.createVaccination(
                  captureAny(),
                  nextDose: any(named: 'nextDose'),
                ),
              ).captured.single
              as Vaccination;
      expect(record.vaccineName, 'Kuduz 🐾');
      expect(DateUtils.isSameDay(record.date, DateTime.now()), isTrue);
      expect(find.text('Private vaccine diagnostic'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'medication calendar uses Monday in Turkish and Sunday in US English without moving dates',
    (tester) async {
      app.care.medications = [app.care.sample()];
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      final toggle = find.widgetWithText(FilledButton, 'Doz takvimi');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final calendar = find.byType(MedicationDoseCalendar);
      final cubit = tester.element(calendar).read<MedicationCubit>();
      await cubit.loadCalendar(DateTime(2026, 4));
      await tester.pumpAndSettle();
      final firstDay = find.byKey(
        ValueKey(('dose-calendar-day', DateTime(2026, 4, 1))),
      );
      double column() {
        final rect = tester.getRect(
          find.ancestor(of: firstDay, matching: find.byType(Row)).first,
        );
        return (tester.getCenter(firstDay).dx - rect.left) / rect.width * 7 -
            0.5;
      }

      expect(column(), closeTo(2, 0.01));
      final selected = (cubit.state as MedicationsLoaded).doses.date;
      await app.cubit.setLanguagePreference(LanguagePreference.english);
      await tester.pumpAndSettle();
      expect(tester.element(calendar).read<MedicationCubit>(), same(cubit));
      expect(column(), closeTo(3, 0.01));
      expect((cubit.state as MedicationsLoaded).doses.date, selected);
      final fifthDay = find.byKey(
        ValueKey(('dose-calendar-day', DateTime(2026, 4, 5))),
      );
      await tester.ensureVisible(fifthDay);
      await tester.tap(fifthDay);
      await tester.pumpAndSettle();
      expect(
        (cubit.state as MedicationsLoaded).doses.date,
        DateTime(2026, 4, 5),
      );
      verifyNever(() => app.care.repository.saveDoseLog(any(), any(), any()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'localized measurement input starts clean and retains a typed draft across locale changes',
    (tester) async {
      final entry = WeightEntry(
        id: 'weight',
        petId: 'pet',
        weight: 12.345,
        measuredAt: app.care.today,
      );
      when(
        () => app.care.weights.updateWeightEntry(any()),
      ).thenAnswer((_) async => const Success(null));
      await app.pump(tester, location: AppRoutes.pets);
      unawaited(
        appRouter.push<bool>(
          AppRoutes.addEditWeightEntry('pet'),
          extra: WeightEntryFormExtra(petId: 'pet', entry: entry),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('12,345 kg'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Değişiklikleri kaydet'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Düzenle'));
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextFormField, 'Kilo');
      await tester.enterText(input, '13,125');
      await app.cubit.setLanguagePreference(LanguagePreference.english);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Weight'))
            .controller!
            .text,
        '13,125',
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();
      final saved =
          verify(
                () => app.care.weights.updateWeightEntry(captureAny()),
              ).captured.single
              as WeightEntry;
      expect(saved.weight, 13.125);
      expect(saved.measuredAt, entry.measuredAt);
      expect(saved.id, entry.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visit amounts use a comma, preserve draft and currency, and save exact minor units',
    (tester) async {
      final visit = VetVisit(
        id: 'visit',
        petId: 'pet',
        visitedOn: app.care.today,
        reason: 'Kontrol',
        costMinorUnits: 12345,
        currency: VetVisitCurrency.usDollar,
      );
      when(
        () => app.care.visits.updateVetVisit(any()),
      ).thenAnswer((_) async => const Success(null));
      await app.pump(tester, location: AppRoutes.pets);
      unawaited(
        appRouter.push<bool>(
          AppRoutes.addEditVetVisit('pet'),
          extra: VetVisitFormExtra(petId: 'pet', visit: visit),
        ),
      );
      await tester.pumpAndSettle();
      final amount = find.byKey(const Key('visit-cost'));
      expect(tester.widget<TextFormField>(amount).controller!.text, '123,45');
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Değişiklikleri kaydet'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '456,78');
      await app.cubit.setLanguagePreference(LanguagePreference.english);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(amount).controller!.text, '456,78');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();
      final saved =
          verify(
                () => app.care.visits.updateVetVisit(captureAny()),
              ).captured.single
              as VetVisit;
      expect(saved.costMinorUnits, 45678);
      expect(saved.currency, VetVisitCurrency.usDollar);
      expect(saved.visitedOn, visit.visitedOn);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Turkish quick Given records the same scheduled day and actual instant',
    (tester) async {
      app.care.medications = [app.care.sample()];
      await app.pump(tester, location: AppRoutes.medications('pet'));
      await tester.tap(find.widgetWithText(FilledButton, 'Verildi').first);
      await tester.pumpAndSettle();
      expect(app.care.logs, hasLength(1));
      expect(app.care.logs.single.status, MedicationDoseStatus.given);
      expect(app.care.logs.single.scheduledDate, app.care.today);
      expect(app.care.logs.single.givenAt, app.care.clock);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open reminder editor translates existing errors and preserves time without permission prompts',
    (tester) async {
      await app.pump(tester, location: AppRoutes.notificationSettings);
      await tester.tap(find.text('Günler ve saat'));
      await tester.pumpAndSettle();
      expect(find.text('3 gün önce'), findsOneWidget);
      expect(find.text('1 gün önce'), findsOneWidget);
      expect(find.text('Aşı günü'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hatırlatma saati'),
        '99:99',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Değişiklikleri kaydet'),
      );
      await tester.pumpAndSettle();
      expect(find.text('00:00–23:59 arasında bir saat girin'), findsOneWidget);
      await app.cubit.setLanguagePreference(LanguagePreference.english);
      await tester.pumpAndSettle();
      expect(find.text('Use 00:00–23:59'), findsOneWidget);
      expect(find.text('99:99'), findsOneWidget);
      expect(find.text('3 days before'), findsOneWidget);
      verifyNever(app.notifications.repository.requestNotificationPermission);
      verifyNever(app.notifications.repository.requestExactAlarmPermission);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [ThemePreference.light, ThemePreference.dark]) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'Turkish care pages and entry forms fit $size at large text in $theme',
        (tester) async {
          app.stored = theme;
          app.care.medications = [app.care.sample()];
          await app.pump(
            tester,
            location: AppRoutes.allVetVisits,
            size: size,
            scale: 2,
          );
          for (final route in [
            AppRoutes.allVaccinations,
            AppRoutes.allMedications,
            AppRoutes.vetVisitDetail('pet', 'visit'),
            AppRoutes.notificationSettings,
            AppRoutes.addEditWeightEntry('pet'),
            AppRoutes.addEditVetVisit('pet'),
            AppRoutes.addEditVaccination('pet'),
          ]) {
            appRouter.go(route);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: route);
          }
        },
      );

      testWidgets(
        'Turkish medication review fits $size at large text in $theme',
        (tester) async {
          app.stored = theme;
          app.care.medications = [app.care.sample()];
          await app.pump(
            tester,
            location: AppRoutes.medications('pet'),
            size: size,
            scale: 2,
          );
          unawaited(appRouter.push<bool>(AppRoutes.addEditMedication('pet')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextFormField, 'İlaç adı'),
            'İlaç 🐾',
          );
          await tester.tap(find.text('Devam et'));
          await tester.pumpAndSettle();
          final time = find.widgetWithText(TextFormField, 'Doz saati');
          await tester.ensureVisible(time);
          await tester.enterText(time, '0900');
          await tester.tap(find.text('Devam et'));
          await tester.pumpAndSettle();
          expect(find.text('İlaç 🐾'), findsOneWidget);
          expect(find.text('Her gün · 09:00'), findsOneWidget);
          expect(
            find.widgetWithText(ElevatedButton, 'İlaç ekle').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
