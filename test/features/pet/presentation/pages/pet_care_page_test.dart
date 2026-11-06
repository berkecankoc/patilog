import 'dart:async';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/core/widgets/pet_care_tabs.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/presentation/pages/medication_list_page.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_care_page.dart';
import 'package:petlytics/features/all_pets_care/presentation/pages/all_pets_care_page.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_avatar.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import '../../../../helpers/pet_care_test_harness.dart';
import '../../../../helpers/feeding_test_harness.dart';
import '../../../../helpers/multi_step_form_helpers.dart';

void main() {
  late PetCareTestHarness app;
  setUpAll(() async {
    await loadFormTestFont();
    final period = MedicationPeriod(
      id: 'fallback',
      medicationId: 'med',
      startDate: DateTime(2026),
      intervalDays: 1,
      doseTimes: [480],
    );
    registerFallbackValue(period);
    registerFallbackValue(
      Medication(
        id: 'fallback',
        petId: 'pet',
        name: 'Fallback',
        periods: [period],
      ),
    );
    registerFallbackValue(
      MedicationDoseLog(
        periodId: 'period',
        scheduledDate: DateTime(2026),
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      ),
    );
  });
  setUp(() {
    app = FeedingTestHarness();
    app.register();
  });

  Future<void> select(WidgetTester tester, PetCareTab tab) async {
    final target = find.widgetWithText(
      Tab,
      tab.label(AppLocalizations.of(tester.element(find.byType(TabBar)))),
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tab arrows reveal more sections without changing the selected page',
    (tester) async {
      final router = await app.pump(
        tester,
        location: AppRoutes.petDetail('pet'),
      );
      final strip = tester.state(find.byType(TabBar));
      final scroll = tester
          .widget<TabBar>(find.byType(TabBar))
          .scrollController!;
      final next = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'More tabs',
      );
      final previous = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Previous tabs',
      );
      final bounds = tester.getRect(find.byType(TabBar));
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);
      expect(tester.getSize(next), const Size(48, 48));
      await tester.tap(next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final midway = scroll.offset;
      expect(midway, greaterThan(0));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(midway));
      expect(router.state.uri.path, AppRoutes.petDetail('pet'));
      expect(tester.state(find.byType(TabBar)), same(strip));
      expect(tester.getRect(find.byType(TabBar)), bounds);
      verifyNever(
        () => app.repository.getMedications(
          any(),
          vetVisitId: any(named: 'vetVisitId'),
        ),
      );
      verifyNever(() => app.weights.getWeightEntries(any()));
      for (
        var i = 0;
        i < PetCareTab.values.length &&
            tester.widget<IconButton>(next).onPressed != null;
        i++
      ) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(scroll.position.extentAfter, closeTo(0, 1));
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      await tester.drag(find.byType(TabBar), const Offset(1600, 0));
      await tester.pumpAndSettle();
      expect(scroll.position.extentBefore, closeTo(0, 1));
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      expect(tester.getRect(find.byType(TabBar)), bounds);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one persistent tab strip preserves its position through tab changes and detail return',
    (tester) async {
      app.medications = [app.sample()];
      await app.pump(tester, location: AppRoutes.petDetail('pet'));
      final strip = tester.state(find.byType(TabBar));
      final avatar = tester.getRect(find.byType(PetAvatar));
      expect(
        avatar.left - tester.getRect(find.byType(BackButton)).right,
        inInclusiveRange(0, 8),
      );
      await select(tester, PetCareTab.medications);
      expect(tester.state(find.byType(TabBar)), same(strip));
      expect(tester.getRect(find.byType(PetAvatar)), avatar);
      final scroll = find.descendant(
        of: find.byType(TabBar),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      final offset = position.pixels;
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<int>),
          matching: find.text('Medications'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medication A'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TabBar)), same(strip));
      expect(tester.state<ScrollableState>(scroll).position, same(position));
      expect(position.pixels, closeTo(offset, 0.1));
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.dividerHeight, 0);
      expect(
        tester.getBottomLeft(find.byType(TabBar)).dy,
        tester.getBottomLeft(find.byType(AppBar)).dy,
      );
      expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isFalse);
      await tester.tap(find.widgetWithText(Tab, 'Vaccinations'));
      await tester.pump();
      expect(position.pixels, closeTo(offset, 0.1));
      await tester.pump(const Duration(milliseconds: 80));
      final midway = position.pixels;
      await tester.pumpAndSettle();
      expect(midway, lessThan(offset));
      expect(position.pixels, lessThan(midway));
    },
  );

  for (final locale in [const Locale('en', 'US'), const Locale('tr', 'TR')]) {
    testWidgets(
      'tab arrow bounds update after viewport changes at large text in $locale',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await app.pump(
          tester,
          location: AppRoutes.petDetail('pet'),
          size: const Size(320, 568),
          scale: 2,
          locale: locale,
        );
        final bar = tester.widget<TabBar>(find.byType(TabBar));
        final scroll = bar.scrollController!;
        final strings = AppLocalizations.of(
          tester.element(find.byType(TabBar)),
        );
        final next = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == strings.moreTabs,
        );
        final previous = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == strings.previousTabs,
        );
        final origin = scroll.offset;
        final target = (origin + scroll.position.viewportDimension - 48).clamp(
          scroll.position.minScrollExtent,
          scroll.position.maxScrollExtent,
        );
        await tester.tap(next);
        await tester.pump();
        expect(scroll.offset, closeTo(target, 1));
        expect(tester.getSize(next), const Size(48, 48));
        tester.view.physicalSize = const Size(2400, 568);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(next).onPressed, isNull);
        expect(tester.widget<IconButton>(previous).onPressed, isNull);
        tester.view.physicalSize = const Size(320, 568);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(next).onPressed, isNotNull);
        expect(scroll.offset, closeTo(0, 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'tabs load once and preserve catalog choice and independent scroll positions',
    (tester) async {
      app.medications = [app.sample()];
      app.measurements = List.generate(
        30,
        (i) => WeightEntry(
          id: 'entry-$i',
          petId: 'pet',
          weight: 3.0 + i / 10,
          measuredAt: DateTime(2026, 1, 30 - i),
        ),
      );
      final router = await app.pump(
        tester,
        location: AppRoutes.petDetail('pet'),
      );
      verifyNever(
        () => app.repository.getMedications(
          any(),
          vetVisitId: any(named: 'vetVisitId'),
        ),
      );
      verifyNever(() => app.weights.getWeightEntries(any()));
      verifyNever(() => app.visits.getVetVisits(any()));
      await select(tester, PetCareTab.medications);
      final page = tester.state(find.byType(PetCarePage));
      final catalog = find.descendant(
        of: find.byType(SegmentedButton<int>),
        matching: find.text('Medications'),
      );
      await tester.tap(catalog);
      await tester.pumpAndSettle();
      expect(find.text('Medication A'), findsOneWidget);
      await select(tester, PetCareTab.weightHistory);
      expect(tester.state(find.byType(PetCarePage)), same(page));
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scroll).position.pixels;
      expect(position, greaterThan(0));
      await select(tester, PetCareTab.medications);
      expect(find.text('Medication A'), findsOneWidget);
      expect(find.byTooltip('Previous day'), findsNothing);
      await select(tester, PetCareTab.weightHistory);
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        closeTo(position, 0.1),
      );
      verify(() => app.weights.getWeightEntries('pet')).called(1);
      verify(
        () => app.repository.getMedications('pet', vetVisitId: null),
      ).called(1);
      verify(() => app.pets.getPetById('pet')).called(1);
      expect(find.byTooltip('My pets'), findsNothing);
      expect(find.byTooltip('Delete pet'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.pets);
      expect(find.byType(AllPetsCarePage), findsOneWidget);
      expect(find.byType(PetCarePage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a saved form returns to its tab and refreshes only that data', (
    tester,
  ) async {
    final router = await app.pump(tester, location: AppRoutes.petDetail('pet'));
    await select(tester, PetCareTab.medications);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Medication name'),
      'New medicine',
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add medication'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.medications('pet'));
    expect(find.byType(MedicationListPage), findsOneWidget);
    verify(() => app.repository.createMedication(any())).called(1);
    verify(
      () => app.repository.getMedications('pet', vetVisitId: null),
    ).called(2);
    verifyNever(() => app.weights.getWeightEntries(any()));
    verifyNever(() => app.visits.getVetVisits(any()));
    expect(tester.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'detail dose ${fails ? 'failure' : 'success'} keeps tracking current without unnecessary reads',
      (tester) async {
        app.medications = [app.sample()];
        app.failDose = fails;
        await app.pump(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SegmentedButton<int>),
            matching: find.text('Medications'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Medication A'));
        await tester.pumpAndSettle();
        final calendar = find.widgetWithText(FilledButton, 'Dose calendar');
        await tester.ensureVisible(calendar);
        await tester.pumpAndSettle();
        await tester.tap(calendar);
        await tester.pumpAndSettle();
        final given = find.widgetWithText(FilledButton, 'Given').first;
        await tester.scrollUntilVisible(
          find.text('08:00'),
          300,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(given);
        await tester.pumpAndSettle();
        expect(app.logs, hasLength(fails ? 0 : 1));
        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Doses'));
        await tester.pumpAndSettle();
        expect(
          find.text('Given at 12:15 · Edit'),
          fails ? findsNothing : findsOneWidget,
        );
        verify(
          () => app.repository.getMedications('pet', vetVisitId: null),
        ).called(fails ? 1 : 2);
        verifyNever(() => app.weights.getWeightEntries(any()));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'visit changes refresh dependent tabs on entry and retain content after failure',
    (tester) async {
      await app.pump(tester, location: AppRoutes.petDetail('pet'));
      await select(tester, PetCareTab.vaccinations);
      await select(tester, PetCareTab.weightHistory);
      await select(tester, PetCareTab.vetVisits);
      PetCareChanges.maybeOf(
        tester.element(find.byType(PetCarePage)),
      )!.changed(PetCareTab.vetVisits, listIsCurrent: true);
      await tester.pumpAndSettle();
      verify(
        () => app.vaccinations.getVaccinations('pet', vetVisitId: null),
      ).called(1);
      when(
        () => app.vaccinations.getVaccinations('pet', vetVisitId: null),
      ).thenAnswer(
        (_) async =>
            const Error(LocalDatabaseFailure('Could not refresh vaccinations')),
      );
      await select(tester, PetCareTab.vaccinations);
      expect(find.text('Failed to load vaccinations'), findsOneWidget);
      expect(find.text('No vaccinations yet'), findsOneWidget);
      when(
        () => app.vaccinations.getVaccinations('pet', vetVisitId: null),
      ).thenAnswer((_) async => const Success([]));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to load vaccinations'), findsNothing);
      expect(find.text('No vaccinations yet'), findsOneWidget);
      verify(
        () => app.vaccinations.getVaccinations('pet', vetVisitId: null),
      ).called(2);
      verify(() => app.visits.getVetVisits('pet')).called(1);
      verify(() => app.weights.getWeightEntries('pet')).called(1);
      verifyNever(
        () => app.repository.getMedications(
          any(),
          vetVisitId: any(named: 'vetVisitId'),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a pet change clears all cached tab state and uses matching records',
    (tester) async {
      const other = Pet(
        id: 'other',
        name: 'Luna',
        species: PetSpecies.bird,
        sex: PetSex.unknown,
        reproductiveStatus: ReproductiveStatus.unknown,
      );
      when(
        () => app.pets.getPetById('other'),
      ).thenAnswer((_) async => const Success(other));
      app.measurements = [
        WeightEntry(
          id: 'first',
          petId: 'pet',
          weight: 4.2,
          measuredAt: DateTime(2026),
        ),
      ];
      final router = await app.pump(
        tester,
        location: AppRoutes.weightHistory('pet'),
      );
      final first = tester.state(find.byType(PetCarePage));
      expect(find.text('4.2 kg'), findsNWidgets(2));
      router.go(AppRoutes.weightHistory('other'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(PetCarePage)), isNot(same(first)));
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Simba'), findsNothing);
      expect(find.text('4.2 kg'), findsNothing);
      expect(find.text('No measurements yet'), findsOneWidget);
      await select(tester, PetCareTab.profile);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Profile details'), findsOneWidget);
      verify(() => app.weights.getWeightEntries('other')).called(1);
    },
  );

  testWidgets(
    'pending dose writes block stale tab and Back callbacks before the next frame',
    (tester) async {
      app.medications = [app.sample()];
      final router = await app.pump(tester);
      final tabs = PetCareTabs.maybeOf(
        tester.element(find.byType(MedicationListPage)),
      )!;
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      final scroll = bar.scrollController!;
      final next = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'More tabs',
        ),
      );
      final offset = scroll.offset;
      expect(next.onPressed, isNotNull);
      app.pendingDose = Completer();
      await tester.tap(find.widgetWithText(FilledButton, 'Given').first);
      tabs.onSelect(PetCareTab.profile);
      tabs.onExit();
      next.onPressed?.call();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(router.state.uri.path, AppRoutes.medications('pet'));
      expect(scroll.offset, offset);
      app.pendingDose!.complete(const Success(null));
      await tester.pumpAndSettle();
      await select(tester, PetCareTab.profile);
      expect(find.text('Profile details'), findsOneWidget);
    },
  );

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'shared header and active FAB fit large text at $size, dark=$dark',
        (tester) async {
          await app.pump(
            tester,
            location: AppRoutes.petDetail('pet'),
            size: size,
            scale: 2,
            dark: dark,
          );
          for (final tab in PetCareTab.values) {
            await select(tester, tab);
            expect(find.byType(AppBar), findsOneWidget);
            expect(find.byType(Scaffold), findsNWidgets(2));
            expect(find.text('Simba').hitTestable(), findsOneWidget);
            expect(
              find.byTooltip('Delete pet'),
              tab == PetCareTab.profile ? findsOneWidget : findsNothing,
            );
            if (tab != PetCareTab.profile) {
              expect(
                find.byType(FloatingActionButton).hitTestable(),
                findsOneWidget,
              );
            }
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
