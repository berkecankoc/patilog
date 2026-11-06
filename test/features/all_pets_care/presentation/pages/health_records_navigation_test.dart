import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/core/widgets/app_pet_filter.dart';
import 'package:petlytics/core/widgets/care_record_card.dart';
import 'package:petlytics/features/all_pets_care/presentation/pages/all_pets_care_page.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_state.dart';
import 'package:petlytics/features/weight_history/presentation/pages/weight_entry_form_page.dart';
import 'package:petlytics/features/weight_history/presentation/pages/weight_history_page.dart';
import 'package:petlytics/features/weight_history/presentation/widgets/weight_history_chart.dart';
import 'package:petlytics/features/weight_history/presentation/utils/weight_chart_data.dart';

import '../../../../helpers/pet_care_test_harness.dart';
import '../../../../helpers/multi_step_form_helpers.dart';

void main() {
  late PetCareTestHarness app;
  const cat = Pet(
    id: 'pet',
    name: 'Simba',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  const dog = Pet(
    id: 'other',
    name: 'Buddy',
    species: PetSpecies.dog,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  late List<Pet> pets;
  late WeightEntry latest;
  setUpAll(() async {
    await loadFormTestFont();
    registerFallbackValue(DateTime(2026));
    final period = MedicationPeriod(
      id: 'fallback',
      medicationId: 'fallback',
      startDate: DateTime(2026),
      intervalDays: 1,
      doseTimes: [480],
    );
    registerFallbackValue(
      Medication(
        id: 'fallback',
        petId: 'pet',
        name: 'Fallback',
        periods: [period],
      ),
    );
    registerFallbackValue(period);
    registerFallbackValue(
      MedicationDoseLog(
        periodId: 'fallback',
        scheduledDate: DateTime(2026),
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      ),
    );
    registerFallbackValue(
      VetVisit(
        id: 'fallback',
        petId: 'pet',
        visitedOn: DateTime(2026),
        reason: 'Fallback',
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
    app = PetCareTestHarness()..register();
    pets = [cat, dog];
    latest = WeightEntry(
      id: 'latest',
      petId: cat.id,
      weight: 4.5,
      measuredAt: app.today,
    );
    app.measurements = [
      latest,
      WeightEntry(id: 'dog', petId: dog.id, weight: 12, measuredAt: app.today),
      WeightEntry(
        id: 'old',
        petId: cat.id,
        weight: 4,
        measuredAt: app.today.subtract(const Duration(days: 2)),
      ),
    ];
    when(app.pets.getPets).thenAnswer((_) async => Success(List.of(pets)));
    when(() => app.pets.getPetById(any())).thenAnswer(
      (call) async => Success(
        pets.firstWhere((p) => p.id == call.positionalArguments.first),
      ),
    );
  });

  Future<void> nav(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byTooltip(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> filter(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.byType(AppPetFilter));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'four destinations retain the selected health tab and one lazy root',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.pets);
      final root = tester.state(find.byType(AllPetsCarePage));
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      verifyNever(app.weights.getAllWeightEntries);
      await nav(tester, 'Health records');
      expect(router.state.uri.path, AppRoutes.allVetVisits);
      expect(find.byType(Tab), findsNWidgets(3));
      await tester.tap(find.widgetWithText(Tab, 'Weight history'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.allWeightHistory);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await nav(tester, 'Medications');
      await nav(tester, 'Health records');
      expect(router.state.uri.path, AppRoutes.allWeightHistory);
      expect(tester.state(find.byType(AllPetsCarePage)), same(root));
      verify(app.weights.getAllWeightEntries).called(1);
      verify(app.pets.getPets).called(1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.pets);
    },
  );

  for (final location in [
    AppRoutes.healthRecords,
    AppRoutes.allVaccinations,
    AppRoutes.allWeightHistory,
  ]) {
    testWidgets('restored $location selects its health tab', (tester) async {
      final router = await app.pump(tester, location: location);
      final target = location == AppRoutes.healthRecords
          ? AppRoutes.allVetVisits
          : location;
      expect(router.state.uri.path, target);
      final index = target == AppRoutes.allVetVisits
          ? 0
          : target == AppRoutes.allVaccinations
          ? 1
          : 2;
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        index,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    });
  }

  testWidgets(
    'latest cards never combine pets; selection reveals one cached history',
    (tester) async {
      await app.pump(tester, location: AppRoutes.allWeightHistory);
      expect(find.byType(CareRecordCard), findsNWidgets(2));
      expect(find.text('4.5 kg'), findsOneWidget);
      expect(find.text('12 kg'), findsOneWidget);
      expect(find.text('4 kg'), findsNothing);
      expect(find.byType(WeightHistoryChart), findsNothing);
      await tester.tap(find.widgetWithText(CareRecordCard, 'Simba'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WeightHistoryChart>(find.byType(WeightHistoryChart))
            .entries
            .map((e) => e.petId)
            .toSet(),
        {cat.id},
      );
      await filter(tester, 'Buddy · Dog');
      expect(
        tester
            .widget<WeightHistoryChart>(find.byType(WeightHistoryChart))
            .entries
            .map((e) => e.petId)
            .toSet(),
        {dog.id},
      );
      await filter(tester, 'All pets');
      expect(find.byType(CareRecordCard), findsNWidgets(2));
      verify(app.weights.getAllWeightEntries).called(1);
      verifyNever(() => app.weights.getWeightEntries(any()));
      verifyNever(() => app.pets.getPetById(any()));
    },
  );

  testWidgets(
    'pets without measurements still have a card and a working add flow',
    (tester) async {
      app.measurements = [latest];
      final router = await app.pump(
        tester,
        location: AppRoutes.allWeightHistory,
      );
      await tester.tap(find.widgetWithText(CareRecordCard, 'Buddy'));
      await tester.pumpAndSettle();
      expect(find.text('No measurements yet'), findsOneWidget);
      await tester.tap(find.byTooltip('Add measurement'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.addEditWeightEntry(dog.id));
      expect(find.byType(WeightEntryFormPage), findsOneWidget);
      expect(find.text(dog.name), findsOneWidget);
      verifyNever(() => app.pets.getPetById(any()));
    },
  );

  testWidgets(
    'all-pets add asks for an owner and successful save refreshes once',
    (tester) async {
      when(() => app.weights.createWeightEntry(any())).thenAnswer((call) async {
        app.measurements.insert(
          0,
          call.positionalArguments.first as WeightEntry,
        );
        return const Success(null);
      });
      final router = await app.pump(
        tester,
        location: AppRoutes.allWeightHistory,
      );
      await tester.tap(find.byTooltip('Add measurement'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buddy').last);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.addEditWeightEntry(dog.id));
      await enterFormText(
        tester,
        find.widgetWithText(TextFormField, 'Weight', skipOffstage: false),
        '13',
      );
      await submitForm(tester);
      expect(router.state.uri.path, AppRoutes.allWeightHistory);
      expect(find.text('13 kg'), findsOneWidget);
      verify(app.weights.getAllWeightEntries).called(2);
      verify(
        () => app.weights.createWeightEntry(
          any(that: isA<WeightEntry>().having((e) => e.petId, 'owner', dog.id)),
        ),
      ).called(1);
      verifyNever(() => app.weights.getWeightEntries(any()));
    },
  );

  testWidgets(
    'scoped and global weights reuse classes with separate route-owned Cubits',
    (tester) async {
      final router = await app.pump(
        tester,
        location: AppRoutes.allWeightHistory,
      );
      final global = tester
          .element(find.byType(WeightHistoryPage))
          .read<WeightHistoryCubit>();
      unawaited(router.push(AppRoutes.weightHistory(dog.id)));
      await tester.pumpAndSettle();
      final scoped = tester
          .element(find.byType(WeightHistoryPage))
          .read<WeightHistoryCubit>();
      expect(scoped, isNot(same(global)));
      expect((scoped.state as WeightHistoryLoaded).petId, dog.id);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .element(find.byType(WeightHistoryPage))
            .read<WeightHistoryCubit>(),
        same(global),
      );
      verify(app.weights.getAllWeightEntries).called(1);
      verify(() => app.weights.getWeightEntries(dog.id)).called(1);
    },
  );

  testWidgets(
    'editing a selected measurement preserves the owner and refreshes its chart once',
    (tester) async {
      when(() => app.weights.updateWeightEntry(any())).thenAnswer((call) async {
        final updated = call.positionalArguments.first as WeightEntry;
        app.measurements = [
          for (final entry in app.measurements)
            entry.id == updated.id ? updated : entry,
        ];
        return const Success(null);
      });
      final router = await app.pump(
        tester,
        location: AppRoutes.allWeightHistory,
      );
      await tester.tap(find.widgetWithText(CareRecordCard, 'Simba'));
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, '4.5 kg');
      await tester.scrollUntilVisible(
        row,
        250,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.2);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WeightEntryFormPage>(find.byType(WeightEntryFormPage))
            .entry,
        latest,
      );
      await enterFormText(
        tester,
        find.widgetWithText(TextFormField, 'Weight', skipOffstage: false),
        '4.7',
      );
      await submitForm(tester);
      expect(router.state.uri.path, AppRoutes.allWeightHistory);
      expect(
        tester
            .widget<WeightHistoryChart>(find.byType(WeightHistoryChart))
            .entries
            .first
            .weight,
        4.7,
      );
      verify(app.weights.getAllWeightEntries).called(2);
      verify(
        () => app.weights.updateWeightEntry(
          any(
            that: isA<WeightEntry>()
                .having((e) => e.id, 'entry', latest.id)
                .having((e) => e.petId, 'owner', cat.id),
          ),
        ),
      ).called(1);
      verifyNever(() => app.weights.getWeightEntries(any()));
    },
  );

  testWidgets(
    'health tabs retain the selected pet, chart range and scroll without reads',
    (tester) async {
      await app.pump(tester, location: AppRoutes.allWeightHistory);
      await tester.tap(find.widgetWithText(CareRecordCard, 'Simba'));
      await tester.pumpAndSettle();
      final all = find.byKey(const ValueKey(WeightChartRange.all));
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final offset = scroll.pixels;
      await tester.tap(find.widgetWithText(Tab, 'Vaccinations'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Weight history'));
      await tester.pumpAndSettle();
      expect(scroll.pixels, offset);
      expect(tester.widget<ChoiceChip>(all).selected, isTrue);
      expect(
        tester
            .widget<WeightHistoryChart>(find.byType(WeightHistoryChart))
            .entries
            .every((e) => e.petId == cat.id),
        isTrue,
      );
      verify(app.weights.getAllWeightEntries).called(1);
    },
  );

  testWidgets(
    'empty directory offers the first pet while failed weight reads require Retry',
    (tester) async {
      pets = [];
      app.measurements = [];
      when(app.weights.getAllWeightEntries).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Read failed')),
      );
      await app.pump(tester, location: AppRoutes.allWeightHistory);
      expect(find.text('No measurements yet'), findsNothing);
      when(app.weights.getAllWeightEntries)
          .thenAnswer((_) async => const Success([]));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No pets yet'), findsOneWidget);
      expect(
        find.byTooltip('Add your first pet').hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(AppPetFilter), findsNothing);
    },
  );

  testWidgets(
    'failed delete retains selected history; retry confirms; success uses no second read',
    (tester) async {
      var fail = true;
      when(() => app.weights.deleteWeightEntry(any())).thenAnswer((call) async {
        if (fail) return const Error(LocalDatabaseFailure('Delete failed'));
        app.measurements.removeWhere(
          (e) => e.id == call.positionalArguments.first,
        );
        return const Success(null);
      });
      await app.pump(tester, location: AppRoutes.allWeightHistory);
      await tester.tap(find.widgetWithText(CareRecordCard, 'Simba'));
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, '4.5 kg');
      await tester.scrollUntilVisible(
        row,
        250,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.2);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('for Simba?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Failed to delete measurement').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verify(() => app.weights.deleteWeightEntry(latest.id)).called(1);
      fail = false;
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byType(WeightHistoryPage))
          .read<WeightHistoryCubit>();
      expect(
        (cubit.state as WeightHistoryLoaded).entries.map((e) => e.id),
        isNot(contains(latest.id)),
      );
      expect(find.text('Failed to delete measurement'), findsNothing);
      verify(app.weights.getAllWeightEntries).called(1);
      verifyNever(() => app.weights.getWeightEntries(any()));
    },
  );

  testWidgets(
    'known scoped deletion and pet removal update retained global cards locally',
    (tester) async {
      await app.pump(tester, location: AppRoutes.allWeightHistory);
      final context = tester.element(find.byType(WeightHistoryPage));
      CareRecordChanges.maybeOf(context)!
          .changed(cat.id, PetCareTab.weightHistory, deletedId: latest.id);
      await tester.pumpAndSettle();
      expect(find.text('4 kg'), findsOneWidget);
      expect(find.text('4.5 kg'), findsNothing);
      pets = [cat];
      CareRecordChanges.maybeOf(context)!
          .changed(dog.id, PetCareTab.profile, petDeleted: true);
      await tester.pumpAndSettle();
      expect(find.text('Buddy'), findsNothing);
      expect(find.text('12 kg'), findsNothing);
      verify(app.weights.getAllWeightEntries).called(1);
    },
  );

  testWidgets('pending delete blocks tab changes, bottom navigation and Back', (
    tester,
  ) async {
    final pending = Completer<Result<void>>();
    when(() => app.weights.deleteWeightEntry(any()))
        .thenAnswer((_) => pending.future);
    final router = await app.pump(tester, location: AppRoutes.allWeightHistory);
    await tester.tap(find.widgetWithText(CareRecordCard, 'Simba'));
    await tester.pumpAndSettle();
    final cubit = tester
        .element(find.byType(WeightHistoryPage))
        .read<WeightHistoryCubit>();
    final write = cubit.deleteWeightEntry(latest);
    await tester.pump();
    await tester.tap(
      find.widgetWithText(Tab, 'Vaccinations'),
      warnIfMissed: false,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byTooltip('My pets'),
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(router.state.uri.path, AppRoutes.allWeightHistory);
    pending.complete(const Success(null));
    await write;
    await tester.pumpAndSettle();
    verify(() => app.weights.deleteWeightEntry(latest.id)).called(1);
  });

  for (final locale in [englishLocale, turkishLocale]) {
    for (final dark in [false, true]) {
      testWidgets(
        'health tabs, weight cards and filter fit $locale dark=$dark with large text',
        (tester) async {
          await app.pump(
            tester,
            location: AppRoutes.allWeightHistory,
            locale: locale,
            dark: dark,
            size: const Size(320, 568),
            scale: 2,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(Tab), findsNWidgets(3));
          expect(find.byType(NavigationDestination), findsNWidgets(4));
          final bar = tester.getRect(find.byType(TabBar));
          final navBar = tester.getRect(find.byType(NavigationBar));
          final fab = tester.getRect(find.byType(FloatingActionButton));
          expect(bar.bottom, lessThan(navBar.top));
          expect(fab.bottom, lessThanOrEqualTo(navBar.top));
          await tester.scrollUntilVisible(
            find.widgetWithText(CareRecordCard, 'Buddy'),
            150,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('Buddy').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
