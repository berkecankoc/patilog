import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_meal.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_state.dart';
import 'package:petlytics/features/feeding/presentation/pages/feeding_page.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import '../../../../helpers/feeding_test_harness.dart';
import '../../../../helpers/multi_step_form_helpers.dart';

void main() {
  late FeedingTestHarness app;
  setUpAll(loadFormTestFont);
  setUp(() {
    app = FeedingTestHarness()..clock = DateTime(2030, 1, 2, 12, 15);
    app.register();
    app.plans = [
      FeedingPlan(
        id: 'plan',
        petId: 'pet',
        startDate: DateTime(2030, 1, 1),
        meals: const [
          FeedingMeal(
            id: 'meal',
            planId: 'plan',
            scheduledMinute: 540,
            amountGrams: 30.5,
            foodName: 'Food',
          ),
        ],
      ),
    ];
  });
  tearDown(() async => getIt.reset());
  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('09:00').first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AppDateField), findsNothing);
  }

  Future<void> save(WidgetTester tester, {bool settle = true}) async {
    final button = find.byType(ElevatedButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  FeedingEntry recorded({DateTime? instant}) => FeedingEntry(
    id: 'entry',
    petId: 'pet',
    amountGrams: 25,
    givenAt: instant ?? DateTime(2030, 1, 2, 9, 2, 17),
    mealId: 'meal',
    scheduledDate: DateTime(2030, 1, 2),
    notes: 'Keep notes',
  );

  testWidgets(
    'meal body opens amount/time and saves once without changing its scheduled day',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.feeding('pet'));
      clearInteractions(app.feeding);
      await open(tester);
      expect(router.state.uri.path, AppRoutes.feeding('pet'));
      expect(
        tester.widget<TextFormField>(field('Amount')).controller!.text,
        '30.5',
      );
      expect(
        tester.widget<TextFormField>(field('Feeding time')).controller!.text,
        '12:15',
      );
      await tester.enterText(field('Amount'), '42,5');
      await tester.enterText(field('Feeding time'), '1100');
      await save(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.entries.single.amountGrams, 42.5);
      expect(app.entries.single.givenAt, DateTime(2030, 1, 2, 11));
      expect(app.entries.single.scheduledDate, DateTime(2030, 1, 2));
      expect(app.entries.single.mealId, 'meal');
      verify(() => app.feeding.createFeedingEntry(any())).called(1);
      verifyNoMoreInteractions(app.feeding);
    },
  );

  testWidgets(
    'editing amount retains identity, exact actual instant, null food and notes',
    (tester) async {
      final original = recorded(instant: DateTime.utc(2030, 1, 1, 8, 5, 17));
      app.entries = [original];
      await app.pump(tester, location: AppRoutes.feeding('pet'));
      await open(tester);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.enterText(field('Amount'), '40');
      await save(tester);
      final saved = app.entries.single;
      expect(saved.amountGrams, 40);
      expect(saved.id, original.id);
      expect(saved.givenAt, original.givenAt);
      expect(saved.scheduledDate, original.scheduledDate);
      expect(saved.foodName, isNull);
      expect(saved.notes, original.notes);
      expect(app.plans.single.meals.single.amountGrams, 30.5);
      verify(() => app.feeding.updateFeedingEntry(any())).called(1);
      verifyNever(() => app.feeding.createFeedingEntry(any()));
    },
  );

  testWidgets('past meals use their own day; future meals remain read only', (
    tester,
  ) async {
    await app.pump(tester, location: AppRoutes.feeding('pet'));
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    await open(tester);
    await tester.enterText(field('Feeding time'), '2359');
    await save(tester);
    expect(app.entries.single.givenAt, DateTime(2030, 1, 1, 23, 59));
    expect(app.entries.single.scheduledDate, DateTime(2030, 1, 1));
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00').first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Scheduled'), findsOneWidget);
  });

  testWidgets('invalid precision and future actual times do not write', (
    tester,
  ) async {
    await app.pump(tester, location: AppRoutes.feeding('pet'));
    await open(tester);
    await tester.enterText(field('Amount'), '1.22');
    await tester.enterText(field('Feeding time'), '2359');
    await save(tester);
    expect(find.text('Use at most one decimal place'), findsOneWidget);
    expect(find.text('Given time cannot be in the future.'), findsOneWidget);
    verifyNever(() => app.feeding.createFeedingEntry(any()));
  });

  testWidgets(
    'failed save retains input and retries with the same visible Save action',
    (tester) async {
      app.failSave = true;
      await app.pump(tester, location: AppRoutes.feeding('pet'));
      await open(tester);
      await tester.enterText(field('Amount'), '40');
      await save(tester);
      expect(
        tester.widget<TextFormField>(field('Amount')).controller!.text,
        '40',
      );
      expect(find.text('Failed to save feeding record'), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
      app.failSave = false;
      await save(tester);
      expect(app.entries, hasLength(1));
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'discarding a failed meal edit also drops its failed write intent',
    (tester) async {
      app.failSave = true;
      await app.pump(tester, location: AppRoutes.feeding('pet'));
      await open(tester);
      await tester.enterText(field('Amount'), '40');
      await save(tester);
      await tester.ensureVisible(find.byTooltip('Close'));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Discard changes'));
      await tester.pumpAndSettle();
      final state =
          tester.element(find.byType(FeedingPage)).read<FeedingCubit>().state
              as FeedingLoaded;
      expect(state.failedAction, isNull);
      expect(state.actionFailure, isNull);
      expect(app.entries, isEmpty);
    },
  );

  testWidgets(
    'failed refresh is recoverable in the sheet without replacing its draft',
    (tester) async {
      await app.pump(tester, location: AppRoutes.feeding('pet'));
      await open(tester);
      await tester.enterText(field('Amount'), '40');
      final cubit = tester
          .element(find.byType(FeedingPage))
          .read<FeedingCubit>();
      app.failLoad = true;
      await cubit.load(petId: 'pet');
      await tester.pumpAndSettle();
      expect(
        find.text('This feeding record is no longer available.'),
        findsNothing,
      );
      expect(
        tester.widget<TextFormField>(field('Amount')).controller!.text,
        '40',
      );
      app.failLoad = false;
      final retry = find.widgetWithText(TextButton, 'Retry').hitTestable();
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('Amount')).controller!.text,
        '40',
      );
      await save(tester);
      expect(app.entries.single.amountGrams, 40);
    },
  );

  testWidgets(
    'global meal panel keeps the selected pet ownership without directory rereads',
    (tester) async {
      const pets = [
        Pet(
          id: 'pet',
          name: 'Simba',
          species: PetSpecies.cat,
          sex: PetSex.male,
          reproductiveStatus: ReproductiveStatus.intact,
        ),
        Pet(
          id: 'other',
          name: 'Buddy',
          species: PetSpecies.dog,
          sex: PetSex.male,
          reproductiveStatus: ReproductiveStatus.intact,
        ),
      ];
      when(app.pets.getPets).thenAnswer((_) async => const Success(pets));
      app.plans = [
        ...app.plans,
        FeedingPlan(
          id: 'other-plan',
          petId: 'other',
          startDate: DateTime(2030, 1, 1),
          meals: const [
            FeedingMeal(
              id: 'other-meal',
              planId: 'other-plan',
              scheduledMinute: 600,
              amountGrams: 80,
            ),
          ],
        ),
      ];
      await app.pump(tester, location: AppRoutes.allFeeding);
      clearInteractions(app.pets);
      await tester.ensureVisible(find.text('10:00'));
      await tester.tap(find.text('10:00'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(app.entries.single.petId, 'other');
      expect(app.entries.single.mealId, 'other-meal');
      verifyZeroInteractions(app.pets);
    },
  );

  testWidgets('pending save blocks double taps, Close and system Back', (
    tester,
  ) async {
    app.pendingSave = Completer<Result<void>>();
    await app.pump(tester, location: AppRoutes.feeding('pet'));
    await open(tester);
    final button = find.byType(ElevatedButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
    app.pendingSave!.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(app.entries, hasLength(1));
    verify(() => app.feeding.createFeedingEntry(any())).called(1);
  });

  for (final systemBack in [true, false]) {
    testWidgets(
      'dirty ${systemBack ? 'system' : 'Close'} exit preserves or discards the draft explicitly',
      (tester) async {
        await app.pump(tester, location: AppRoutes.feeding('pet'));
        await open(tester);
        await tester.enterText(field('Amount'), '40');
        Future<void> close() async {
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Close'));
          }
          await tester.pumpAndSettle();
        }

        await close();
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(field('Amount')).controller!.text,
          '40',
        );
        await close();
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Discard changes'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(app.entries, isEmpty);
      },
    );
  }

  testWidgets(
    'clear requires a fresh confirmation on retry and removes the known record locally',
    (tester) async {
      app.entries = [recorded()];
      await app.pump(tester, location: AppRoutes.feeding('pet'));
      await open(tester);
      clearInteractions(app.feeding);
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Clear record'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Clear record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.entries, hasLength(1));
      app.failDeleteEntry = true;
      await tester.tap(find.widgetWithText(TextButton, 'Clear record'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear record'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      app.failDeleteEntry = false;
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Clear record'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Clear record'));
      await tester.pumpAndSettle();
      expect(find.text('Delete feeding record?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear record'));
      await tester.pumpAndSettle();
      expect(app.entries, isEmpty);
      expect(find.byType(BottomSheet), findsNothing);
      verify(() => app.feeding.deleteFeedingEntry('pet', 'entry')).called(2);
      verifyNoMoreInteractions(app.feeding);
    },
  );

  for (final (locale, size, scale, keyboard) in [
    (turkishLocale, const Size(320, 568), 2.0, 180.0),
    (englishLocale, const Size(640, 320), 2.0, 140.0),
  ]) {
    testWidgets('sheet actions clear keyboard and bounds at $locale $size', (
      tester,
    ) async {
      await app.pump(
        tester,
        location: AppRoutes.feeding('pet'),
        locale: locale,
        size: size,
        scale: scale,
        keyboard: keyboard,
        bottomInset: 16,
        dark: true,
      );
      await open(tester);
      final s = AppLocalizations.of(
        tester.element(find.byType(TextFormField).first),
      );
      final amount = field(s.feedingAmount);
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '35');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: amount, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isFalse,
      );
      final button = find.byType(ElevatedButton);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(button).bottom,
        lessThanOrEqualTo(size.height - keyboard),
      );
      expect(tester.takeException(), isNull);
      expect(app.entries, isEmpty);
    });
  }
}
