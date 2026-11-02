import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_meal.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_state.dart';
import 'package:petlytics/features/feeding/presentation/pages/feeding_page.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_detail_page.dart';
import 'package:petlytics/features/notification/presentation/pages/notification_settings_page.dart';
import '../../../../helpers/feeding_test_harness.dart';
import '../../../../helpers/settings_test_harness.dart';
import '../../../../helpers/multi_step_form_helpers.dart';

void main() {
  late FeedingTestHarness feeding;
  late SettingsTestHarness app;
  const target = VaccinationNotificationTarget(
    petId: 'pet',
    vaccinationId: 'vax',
    daysBefore: 0,
  );
  setUpAll(SettingsTestHarness.initialize);
  setUp(() {
    feeding = FeedingTestHarness();
    app = SettingsTestHarness(care: feeding)..register();
    when(
      () => feeding.vaccinations.getVaccinationById('pet', 'vax'),
    ).thenAnswer(
      (_) async => Success(
        Vaccination(
          id: 'vax',
          petId: 'pet',
          vaccineName: 'Rabies',
          status: VaccinationStatus.planned,
          date: DateTime.now().add(const Duration(days: 3)),
        ),
      ),
    );
  });
  Future<void> pump(WidgetTester tester, String location) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await app.pump(tester, location: location);
  }

  testWidgets(
    'an open meal sheet defers reminder navigation until explicit Close',
    (tester) async {
      feeding.plans = [
        FeedingPlan(
          id: 'plan',
          petId: 'pet',
          startDate: feeding.today,
          meals: const [
            FeedingMeal(
              id: 'meal',
              planId: 'plan',
              scheduledMinute: 540,
              amountGrams: 30,
            ),
          ],
        ),
      ];
      await pump(tester, AppRoutes.allFeeding);
      await tester.tap(find.text('09:00'));
      await tester.pumpAndSettle();
      app.notifications.taps.add(target);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(BottomSheet), findsOneWidget);
      verifyNever(() => feeding.vaccinations.getVaccinationById(any(), any()));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      verifyNever(() => feeding.feeding.createFeedingEntry(any()));
    },
  );

  for (final settings in [true, false]) {
    for (final appBarBack in [true, false]) {
      testWidgets(
        'meal reminder opens its day from ${settings ? 'Settings' : 'the same pet hub'} without recording and returns with ${appBarBack ? 'app-bar' : 'system'} Back',
        (tester) async {
          feeding.clock = DateTime(2030, 1, 2, 10);
          final plan = FeedingPlan(
            id: 'meal-plan',
            petId: 'pet',
            startDate: DateTime(2030, 1, 1),
            meals: const [
              FeedingMeal(
                id: 'meal',
                planId: 'meal-plan',
                scheduledMinute: 720,
                amountGrams: 40,
              ),
            ],
          );
          feeding.plans = [plan];
          app.notifications.feedingPlans.add(plan);
          await pump(
            tester,
            settings ? AppRoutes.pets : AppRoutes.vetVisits('pet'),
          );
          if (settings) {
            unawaited(appRouter.push(AppRoutes.notificationSettings));
            await tester.pumpAndSettle();
          }
          app.notifications.taps.add(
            FeedingMealNotificationTarget(
              petId: 'pet',
              planId: plan.id,
              mealId: 'meal',
              scheduledDate: DateTime(2030, 1, 1),
              scheduledMinute: 720,
            ),
          );
          await tester.pumpAndSettle();
          expect(appRouter.state.uri.path, AppRoutes.feeding('pet'));
          final loaded =
              tester
                      .element(find.byType(FeedingPage))
                      .read<FeedingCubit>()
                      .state
                  as FeedingLoaded;
          expect(loaded.date, DateTime(2030, 1, 1));
          if (!settings) {
            await tester.tap(find.text('History'));
            await tester.pumpAndSettle();
            app.notifications.taps.add(
              FeedingMealNotificationTarget(
                petId: 'pet',
                planId: plan.id,
                mealId: 'meal',
                scheduledDate: DateTime(2030, 1, 1),
                scheduledMinute: 720,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<SegmentedButton<int>>(
                    find.widgetWithText(SegmentedButton<int>, 'Meals'),
                  )
                  .selected,
              {0},
            );
          }
          verifyNever(() => feeding.feeding.createFeedingEntry(any()));
          expect(tester.takeException(), isNull);
          if (appBarBack) {
            await tester.tap(find.byType(BackButton).last);
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          if (settings) {
            expect(find.byType(NotificationSettingsPage), findsOneWidget);
          }
        },
      );
    }
  }

  testWidgets(
    'idle global feeding allows a reminder and Back returns to feeding',
    (tester) async {
      await pump(tester, AppRoutes.allFeeding);
      app.notifications.taps.add(target);
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, AppRoutes.allFeeding);
      verifyNever(() => feeding.feeding.createFeedingEntry(any()));
    },
  );

  testWidgets(
    'a reminder waits for a pending feeding write without writing another record',
    (tester) async {
      feeding.plans = [
        FeedingPlan(
          id: 'plan',
          petId: 'pet',
          startDate: feeding.today,
          meals: const [
            FeedingMeal(
              id: 'meal',
              planId: 'plan',
              scheduledMinute: 540,
              amountGrams: 30,
            ),
          ],
        ),
      ];
      feeding.pendingSave = Completer<Result<void>>();
      await pump(tester, AppRoutes.allFeeding);
      final cubit = tester
          .element(find.byType(FeedingPage))
          .read<FeedingCubit>();
      final saving = cubit.recordMeal(
        (cubit.state as FeedingLoaded).meals.single,
      );
      await tester.pump();
      app.notifications.taps.add(target);
      await tester.pump(const Duration(milliseconds: 200));
      expect(appRouter.state.uri.path, AppRoutes.allFeeding);
      verifyNever(() => feeding.vaccinations.getVaccinationById(any(), any()));
      feeding.pendingSave!.complete(const Success(null));
      await saving;
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      expect(feeding.entries, hasLength(1));
      verify(() => feeding.feeding.createFeedingEntry(any())).called(1);
    },
  );

  for (final plan in [false, true]) {
    testWidgets(
      '${plan ? 'plan' : 'entry'} draft is retained until explicit discard before opening a reminder',
      (tester) async {
        await pump(
          tester,
          plan
              ? AppRoutes.addEditFeedingPlan('pet')
              : AppRoutes.addEditFeedingEntry('pet'),
        );
        final field = plan
            ? find.widgetWithText(TextFormField, 'Amount', skipOffstage: false)
            : find.byKey(const ValueKey('feeding-amount'), skipOffstage: false);
        await enterFormText(tester, field, '25');
        app.notifications.taps.add(target);
        await tester.pumpAndSettle();
        expect(find.byType(VaccinationDetailPage), findsNothing);
        expect(tester.widget<TextFormField>(field).controller!.text, '25');
        await leaveForm(tester);
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Discard changes'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(VaccinationDetailPage), findsOneWidget);
        expect(feeding.entries, isEmpty);
        expect(feeding.plans, isEmpty);
      },
    );
  }
}
