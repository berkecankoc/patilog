import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_meal.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';
import 'package:petlytics/features/feeding/presentation/pages/feeding_page.dart';
import 'package:petlytics/features/feeding/presentation/widgets/feeding_chart.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import '../../../../helpers/feeding_test_harness.dart';
import '../../../../helpers/multi_step_form_helpers.dart';

void main() {
  late FeedingTestHarness app;
  FeedingPlan plan({
    String id = 'plan',
    String petId = 'pet',
    DateTime? start,
    double amount = 30.5,
  }) => FeedingPlan(
    id: id,
    petId: petId,
    startDate: start ?? app.today,
    meals: [
      FeedingMeal(
        id: '$id-meal',
        planId: id,
        scheduledMinute: 540,
        amountGrams: amount,
        foodName: 'Food',
      ),
    ],
  );
  FeedingEntry entry({
    String id = 'entry',
    String petId = 'pet',
    String? mealId,
  }) => FeedingEntry(
    id: id,
    petId: petId,
    amountGrams: 20.5,
    givenAt: app.clock.subtract(const Duration(minutes: 1)),
    mealId: mealId,
    scheduledDate: mealId == null ? null : app.today,
  );
  Finder field(String label) =>
      find.widgetWithText(TextFormField, label, skipOffstage: false);
  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> switchView(WidgetTester tester, int index) async {
    final s = AppLocalizations.of(tester.element(find.byType(FeedingPage)));
    final tab = find
        .text([s.dailyMeals, s.feedingPlans, s.history][index])
        .first;
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  setUpAll(loadFormTestFont);
  setUp(() {
    app = FeedingTestHarness();
    app.clock = DateTime.now();
    app.register();
  });
  tearDown(() async {
    await getIt.reset();
  });

  for (final locale in [englishLocale, turkishLocale]) {
    for (final (width, scale) in [
      (320.0, 1.0),
      (390.0, 1.0),
      (320.0, 2.0),
      (390.0, 2.0),
    ]) {
      testWidgets(
        'navigation icons align at $locale width $width scale $scale',
        (tester) async {
          await app.pump(
            tester,
            location: AppRoutes.pets,
            locale: locale,
            size: Size(width, 844),
            scale: scale,
          );
          final destinations = find.byType(NavigationDestination);
          final strings = AppLocalizations.of(
            tester.element(destinations.first),
          );
          expect(
            tester
                .widgetList<NavigationDestination>(destinations)
                .map((d) => d.label),
            containsAll([strings.vaccinations, strings.medications]),
          );
          final positions = <double>[];
          for (var i = 0; i < 5; i++) {
            final icon = find
                .descendant(
                  of: destinations.at(i),
                  matching: find.byWidgetPredicate(
                    (w) => w is Icon || w is ImageIcon,
                  ),
                )
                .first;
            positions.add(tester.getCenter(icon).dy);
          }
          expect(
            positions.every((y) => (y - positions.first).abs() < .1),
            isTrue,
            reason: '$positions',
          );
        },
      );
    }
  }

  testWidgets('history groups records by day and leaves plans one tap away', (
    tester,
  ) async {
    app.plans = [
      FeedingPlan(
        id: 'plan',
        petId: 'pet',
        startDate: app.today,
        endDate: DateTime(app.today.year, app.today.month, app.today.day + 3),
        meals: plan().meals,
      ),
    ];
    app.entries = [
      for (var i = 0; i < 80; i++)
        FeedingEntry(
          id: 'entry-$i',
          petId: 'pet',
          amountGrams: 20,
          givenAt: app.clock.subtract(Duration(days: i % 7)),
        ),
    ];
    await app.pump(tester, location: AppRoutes.feeding('pet'));
    expect(find.byIcon(Icons.schedule_outlined), findsNothing);
    await switchView(tester, 2);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    final groups = find.byType(ExpansionTile);
    await tester.scrollUntilVisible(
      groups.first,
      250,
      scrollable: find
          .descendant(
            of: find.byType(FeedingPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(groups.first);
    await tester.tap(groups.first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(find.text('Plans').hitTestable(), findsOneWidget);
    await switchView(tester, 1);
    expect(find.text('Edit end date').hitTestable(), findsOneWidget);
    expect(find.text('Set end date'), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  testWidgets(
    'today recording updates both views locally and double taps do not duplicate it',
    (tester) async {
      app.plans = [plan()];
      await app.pump(tester, location: AppRoutes.feeding('pet'));
      expect(find.byType(FeedingPage), findsOneWidget);
      clearInteractions(app.feeding);
      final given = find.widgetWithText(FilledButton, 'Given');
      await tester.tap(given);
      await tester.tap(given, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(app.entries, hasLength(1));
      expect(app.entries.single.amountGrams, 30.5);
      expect(app.entries.single.mealId, 'plan-meal');
      verify(() => app.feeding.createFeedingEntry(any())).called(1);
      verifyNoMoreInteractions(app.feeding);
      expect(find.widgetWithText(FilledButton, 'Given'), findsNothing);
    },
  );

  testWidgets(
    'manual form accepts decimal comma and automatic colon then refreshes its caller',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.feeding('pet'));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await enterFormText(
        tester,
        find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
        '12,5',
      );
      await enterFormText(
        tester,
        find.byKey(const ValueKey('feeding-time'), skipOffstage: false),
        '0000',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('feeding-time'), skipOffstage: false),
            )
            .controller!
            .text,
        '00:00',
      );
      await submitForm(tester);
      expect(router.state.uri.path, AppRoutes.feeding('pet'));
      expect(app.entries.single.amountGrams, 12.5);
      expect(app.entries.single.mealId, isNull);
      expect(app.entries.single.givenAt.hour, 0);
      expect(find.text('12.5 g'), findsWidgets);
    },
  );

  for (final systemBack in [false, true]) {
    testWidgets(
      'dirty entry uses discard confirmation through ${systemBack ? 'system' : 'app-bar'} Back',
      (tester) async {
        final router = await app.pump(
          tester,
          location: AppRoutes.feeding('pet'),
        );
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await enterFormText(
          tester,
          find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
          '25',
        );
        await leaveForm(tester, systemBack: systemBack);
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(
                  const ValueKey('feeding-amount'),
                  skipOffstage: false,
                ),
              )
              .controller!
              .text,
          '25',
        );
        await leaveForm(tester, systemBack: systemBack);
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Discard changes'),
        );
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.feeding('pet'));
        expect(app.entries, isEmpty);
      },
    );
  }

  testWidgets(
    'failed form save retains the Review and draft with one fixed retry action',
    (tester) async {
      app.failSave = true;
      await app.pump(tester, location: AppRoutes.addEditFeedingEntry('pet'));
      await enterFormText(
        tester,
        find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
        '15.5',
      );
      await submitForm(tester);
      expect(find.text('Failed to save feeding record'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
      expect(find.text('Retry save'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
            )
            .controller!
            .text,
        '15.5',
      );
      app.failSave = false;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();
      expect(app.entries.single.amountGrams, 15.5);
    },
  );

  testWidgets('pending save blocks both Back paths and repeat submit', (
    tester,
  ) async {
    app.pendingSave = Completer<Result<void>>();
    final router = await app.pump(tester, location: AppRoutes.feeding('pet'));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await enterFormText(
      tester,
      find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
      '10',
    );
    await submitForm(tester, settle: false);
    await tester.tap(find.byType(BackButton));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(router.state.uri.path, AppRoutes.addEditFeedingEntry('pet'));
    expect(find.text('Discard changes?'), findsNothing);
    app.pendingSave!.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(app.entries, hasLength(1));
    expect(router.state.uri.path, AppRoutes.feeding('pet'));
  });

  testWidgets(
    'editing an amount retains the exact actual instant and planned occurrence',
    (tester) async {
      final original = entry(mealId: 'plan-meal');
      app.entries = [original];
      final router = await app.pump(tester, location: AppRoutes.feeding('pet'));
      unawaited(
        router.push(
          AppRoutes.addEditFeedingEntry('pet'),
          extra: FeedingEntryFormExtra(
            petId: 'pet',
            petName: 'Simba',
            entry: original,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Save changes'),
            )
            .onPressed,
        isNull,
      );
      await enterFormText(
        tester,
        find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
        '35.5',
      );
      await submitForm(tester);
      final saved = app.entries.single;
      expect(saved.amountGrams, 35.5);
      expect(saved.givenAt, original.givenAt);
      expect(saved.mealId, original.mealId);
      expect(saved.scheduledDate, original.scheduledDate);
      verify(() => app.feeding.updateFeedingEntry(any())).called(1);
    },
  );

  testWidgets(
    'new plans save their first meal and pending edits keep plan identity',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.feeding('pet'));
      await switchView(tester, 1);
      await reveal(tester, find.widgetWithText(OutlinedButton, 'Create plan'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Create plan'));
      await tester.pumpAndSettle();
      await enterFormText(tester, field('Amount'), '30.5');
      await submitForm(tester);
      expect(app.plans.single.startDate, app.today);
      expect(app.plans.single.meals.single.amountGrams, 30.5);
      await switchView(tester, 0);
      expect(find.widgetWithText(FilledButton, 'Given'), findsOneWidget);
      final pending = plan(
        id: 'pending',
        start: DateTime(app.today.year, app.today.month, app.today.day + 1),
      );
      app.plans.add(pending);
      unawaited(
        router.push(
          AppRoutes.addEditFeedingPlan('pet'),
          extra: FeedingPlanFormExtra(
            petId: 'pet',
            petName: 'Simba',
            plan: pending,
            plans: app.plans,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterFormText(tester, field('Amount'), '40');
      await submitForm(tester);
      expect(app.plans, hasLength(2));
      expect(app.plans.last.id, 'pending');
      expect(app.plans.last.meals.single.id, 'pending-meal');
      expect(app.plans.last.meals.single.amountGrams, 40);
    },
  );

  testWidgets('ending a started plan retains its meals and recorded history', (
    tester,
  ) async {
    app.plans = [plan()];
    final recorded = entry(mealId: 'plan-meal');
    app.entries = [recorded];
    await app.pump(tester, location: AppRoutes.feeding('pet'));
    await switchView(tester, 1);
    final end = find.widgetWithText(TextButton, 'Set end date');
    await tester.scrollUntilVisible(
      end,
      300,
      scrollable: find
          .descendant(
            of: find.byType(FeedingPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await reveal(tester, end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    final picker = find.byTooltip('End date (optional): choose date');
    await reveal(tester, picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await submitForm(tester);
    expect(app.plans.single.endDate, app.today);
    expect(app.plans.single.meals.single.id, 'plan-meal');
    expect(app.entries, [recorded]);
    verify(() => app.feeding.updateFeedingPlan(any())).called(1);
    verifyNever(() => app.feeding.createFeedingPlan(any()));
  });

  testWidgets(
    'every meal can be removed when another remains; duplicate times are rejected',
    (tester) async {
      await app.pump(tester, location: AppRoutes.addEditFeedingPlan('pet'));
      await enterFormText(tester, field('Amount').first, '25');
      await reveal(tester, find.widgetWithText(OutlinedButton, 'Add meal'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add meal'));
      await tester.pumpAndSettle();
      await enterFormText(tester, field('Meal time').last, '0900');
      await enterFormText(tester, field('Amount').last, '20');
      await reviewForm(tester);
      expect(find.text('Each meal needs a different time'), findsWidgets);
      await reveal(tester, find.byTooltip('Remove meal 1'));
      await tester.tap(find.byTooltip('Remove meal 1'));
      await tester.pumpAndSettle();
      await submitForm(tester);
      expect(app.plans.single.meals, hasLength(1));
      expect(app.plans.single.meals.single.amountGrams, 20);
      expect(app.plans.single.meals.single.scheduledMinute, 540);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deleting a record asks again on Retry and never reloads a known deletion',
    (tester) async {
      app.entries = [entry()];
      app.failDeleteEntry = true;
      await app.pump(tester, location: AppRoutes.feeding('pet'));
      clearInteractions(app.feeding);
      await reveal(tester, find.byTooltip('Delete feeding record?'));
      await tester.tap(find.byTooltip('Delete feeding record?'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(app.entries, hasLength(1));
      expect(find.text('Failed to delete feeding record'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Delete feeding record?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(app.entries, hasLength(1));
      app.failDeleteEntry = false;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(app.entries, isEmpty);
      verify(() => app.feeding.deleteFeedingEntry('pet', 'entry')).called(2);
      verifyNoMoreInteractions(app.feeding);
    },
  );

  testWidgets('foreign extras cannot populate another pet entry form', (
    tester,
  ) async {
    final router = await app.pump(tester, location: AppRoutes.feeding('pet'));
    unawaited(
      router.push(
        AppRoutes.addEditFeedingEntry('pet'),
        extra: FeedingEntryFormExtra(
          petId: 'other',
          petName: 'Wrong pet',
          entry: entry(petId: 'other'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('Wrong pet'), findsNothing);
    await enterFormText(
      tester,
      find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
      '19,5',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
          )
          .controller!
          .text,
      '19,5',
    );
    verifyNever(() => app.feeding.updateFeedingEntry(any()));
  });

  testWidgets(
    'global feeding keeps per-pet totals and does not query the directory on filter changes',
    (tester) async {
      const other = Pet(
        id: 'other',
        name: 'Buddy',
        species: PetSpecies.dog,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      );
      const simba = Pet(
        id: 'pet',
        name: 'Simba',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      );
      when(
        app.pets.getPets,
      ).thenAnswer((_) async => const Success([simba, other]));
      app.plans = [plan(), plan(id: 'other-plan', petId: 'other')];
      app.entries = [entry(), entry(id: 'other', petId: 'other')];
      await app.pump(tester, location: AppRoutes.allFeeding);
      final dropdown = find.byType(DropdownButtonFormField<String>);
      for (final view in [0, 1, 2]) {
        await switchView(tester, view);
        expect(
          tester.getRect(dropdown).bottom,
          lessThan(tester.getRect(find.byType(SegmentedButton<int>)).top),
        );
      }
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(
        find.text('Select a pet above to see its daily feeding chart.'),
        findsOneWidget,
      );
      clearInteractions(app.pets);
      clearInteractions(app.feeding);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simba').last);
      await tester.pumpAndSettle();
      final chart = tester.widget<FeedingChart>(find.byType(FeedingChart));
      expect(chart.totals.last.amountGrams, 20.5);
      for (final view in [1, 0, 2]) {
        await switchView(tester, view);
        expect(
          tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
          'pet',
        );
      }
      verifyZeroInteractions(app.pets);
      verifyZeroInteractions(app.feeding);
    },
  );

  testWidgets(
    'a delayed display name preserves entered draft and performs one lookup',
    (tester) async {
      final name = Completer<Result<Pet>>();
      when(() => app.pets.getPetById('pet')).thenAnswer((_) => name.future);
      await app.pump(tester, location: AppRoutes.addEditFeedingEntry('pet'));
      await enterFormText(
        tester,
        find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
        '19,5',
      );
      name.complete(
        const Success(
          Pet(
            id: 'pet',
            name: 'Simba',
            species: PetSpecies.cat,
            sex: PetSex.male,
            reproductiveStatus: ReproductiveStatus.intact,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Simba'), findsWidgets);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('feeding-amount'), skipOffstage: false),
            )
            .controller!
            .text,
        '19,5',
      );
      verify(() => app.pets.getPetById('pet')).called(1);
      verifyNever(() => app.feeding.createFeedingEntry(any()));
    },
  );

  testWidgets(
    'plan context loading has a Retry and does not query meal history',
    (tester) async {
      app.failLoad = true;
      await app.pump(tester, location: AppRoutes.addEditFeedingPlan('pet'));
      expect(find.text('Failed to load feeding records'), findsOneWidget);
      app.failLoad = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(AppMultiStepForm), findsOneWidget);
      verify(() => app.feeding.getFeedingPlans('pet')).called(2);
      verifyNever(
        () => app.feeding.getFeedingEntries(
          any(),
          from: any(named: 'from'),
          before: any(named: 'before'),
        ),
      );
    },
  );

  testWidgets(
    'numeric Done dismisses without saving and fixed actions clear simulated keyboard bounds',
    (tester) async {
      await app.pump(
        tester,
        location: AppRoutes.addEditFeedingEntry('pet'),
        keyboard: 300,
        bottomInset: 16,
      );
      final amount = find.byKey(
        const ValueKey('feeding-amount'),
        skipOffstage: false,
      );
      await enterFormText(tester, amount, '25.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(
        find.descendant(of: amount, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isFalse);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('multi-step-form-actions')))
            .bottom,
        lessThanOrEqualTo(844 - 300),
      );
      verifyNever(() => app.feeding.createFeedingEntry(any()));
    },
  );

  for (final locale in [englishLocale, turkishLocale]) {
    testWidgets(
      'decimal chart labels stay on one line and clear dates in $locale',
      (tester) async {
        final semantics = tester.ensureSemantics();
        app.entries = [
          FeedingEntry(
            id: 'small',
            petId: 'pet',
            amountGrams: 0.3,
            givenAt: app.clock,
          ),
        ];
        await app.pump(
          tester,
          location: AppRoutes.feeding('pet'),
          locale: locale,
          size: const Size(320, 568),
          scale: 2,
        );
        await switchView(tester, 2);
        final chart = find.byType(FeedingChart);
        await tester.scrollUntilVisible(
          chart,
          300,
          scrollable: find
              .descendant(
                of: find.byType(FeedingPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final decimal = find.descendant(
          of: chart,
          matching: find.text(locale == turkishLocale ? '0,1' : '0.1'),
        );
        expect(decimal, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(decimal);
        expect(paragraph.didExceedMaxLines, isFalse);
        final summary = find.descendant(
          of: chart,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.image == true,
          ),
        );
        final data = tester.getSemantics(summary).getSemanticsData();
        expect(
          data.value,
          contains(locale == turkishLocale ? '0,3 g' : '0.3 g'),
        );
        expect(
          data.value,
          contains(AppLocalizations.of(tester.element(chart)).noDoseRecord),
        );
        final zero = find.descendant(of: chart, matching: find.text('0'));
        final start = DateTime(
          app.today.year,
          app.today.month,
          app.today.day - 6,
        );
        final date = find.descendant(
          of: chart,
          matching: find.text(
            DateFormat.MMMd(locale.toLanguageTag()).format(start),
          ),
        );
        expect(
          tester.getTopLeft(date).dy - tester.getBottomLeft(zero).dy,
          greaterThanOrEqualTo(15.9),
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  for (final (locale, dark, size, scale) in [
    (englishLocale, false, const Size(320, 568), 1.0),
    (turkishLocale, true, const Size(320, 568), 2.0),
    (englishLocale, true, const Size(640, 320), 2.0),
  ]) {
    testWidgets(
      'feeding layout and form actions clear bounds at $locale $size scale $scale',
      (tester) async {
        app.plans = [plan()];
        app.entries = [entry()];
        final router = await app.pump(
          tester,
          location: AppRoutes.feeding('pet'),
          locale: locale,
          dark: dark,
          size: size,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        final fab = find.byType(FloatingActionButton);
        expect(tester.getRect(fab).bottom, lessThanOrEqualTo(size.height));
        unawaited(
          router.push(
            AppRoutes.addEditFeedingEntry('pet'),
            extra: FeedingEntryFormExtra(
              petId: 'pet',
              petName: 'Simba',
              entry: app.entries.single,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final fixed = find.byKey(const ValueKey('multi-step-form-actions'));
        expect(tester.getRect(fixed).bottom, lessThanOrEqualTo(size.height));
        final s = AppLocalizations.of(
          tester.element(find.byType(AppMultiStepForm)),
        );
        expect(
          find.widgetWithText(ElevatedButton, s.saveChanges),
          findsOneWidget,
        );
      },
    );
  }
}
