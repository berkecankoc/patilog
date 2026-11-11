import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_meal.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_occurrence.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';
import 'package:patilog/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:patilog/features/feeding/domain/use_cases/calculate_feeding_meals.dart';
import 'package:patilog/features/feeding/domain/use_cases/calculate_feeding_totals.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_state.dart';

class MockFeedingRepository extends Mock implements FeedingRepository {}

class CountingIds implements IdGenerator {
  int calls = 0;
  @override
  String generate() => 'id-${++calls}';
}

void main() {
  late MockFeedingRepository repository;
  late CountingIds ids;
  late DateTime clock;
  final date = DateTime(2026, 11, 1);
  final plan = FeedingPlan(
    id: 'plan',
    petId: 'pet',
    startDate: date,
    meals: const [
      FeedingMeal(
        id: 'meal',
        planId: 'plan',
        scheduledMinute: 540,
        amountGrams: 30,
        foodName: 'Food',
      ),
    ],
  );
  final next = FeedingPlan(
    id: 'next',
    petId: 'pet',
    startDate: DateTime(2026, 11, 2),
    meals: const [
      FeedingMeal(
        id: 'next-meal',
        planId: 'next',
        scheduledMinute: 600,
        amountGrams: 40,
      ),
    ],
  );
  final recorded = FeedingEntry(
    id: 'entry',
    petId: 'pet',
    amountGrams: 25,
    givenAt: DateTime(2026, 11, 1, 10),
    mealId: 'meal',
    scheduledDate: date,
  );
  const failure = LocalDatabaseFailure('Failed');

  setUpAll(() {
    registerFallbackValue(date);
    registerFallbackValue(recorded);
  });

  void stubReads({
    List<FeedingPlan>? plans,
    List<FeedingEntry> entries = const [],
    List<FeedingEntry> planned = const [],
  }) {
    when(
      () => repository.getFeedingPlans(any()),
    ).thenAnswer((_) async => Success(plans ?? [plan]));
    when(
      () => repository.getAllFeedingPlans(),
    ).thenAnswer((_) async => Success(plans ?? [plan]));
    when(
      () => repository.getFeedingEntries(
        any(),
        from: any(named: 'from'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) async => Success(entries));
    when(
      () => repository.getAllFeedingEntries(
        from: any(named: 'from'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) async => Success(entries));
    when(
      () => repository.getPlannedFeedingEntries(
        any(),
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer((_) async => Success(planned));
    when(
      () => repository.getAllPlannedFeedingEntries(
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer((_) async => Success(planned));
  }

  FeedingCubit makeCubit() => FeedingCubit(
    repository,
    ids,
    const CalculateFeedingMeals(),
    const CalculateFeedingTotals(),
    now: () => clock,
  );

  setUp(() {
    repository = MockFeedingRepository();
    ids = CountingIds();
    clock = DateTime(2026, 11, 1, 15, 30);
    stubReads();
  });

  test(
    'meal correction updates both caches without changing the plan, notes or insertion ties',
    () async {
      final original = FeedingEntry(
        id: recorded.id,
        petId: recorded.petId,
        amountGrams: recorded.amountGrams,
        givenAt: recorded.givenAt,
        mealId: recorded.mealId,
        scheduledDate: recorded.scheduledDate,
        notes: 'Keep notes',
      );
      stubReads(entries: [original], planned: [original]);
      when(
        () => repository.updateFeedingEntry(any()),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final meal = (cubit.state as FeedingLoaded).meals.single;
      clearInteractions(repository);
      expect(
        await cubit.saveMeal(meal, amountGrams: 40, givenAt: original.givenAt),
        isTrue,
      );
      final loaded = cubit.state as FeedingLoaded;
      final updated = loaded.meals.single.entry!;
      expect(updated.id, original.id);
      expect(updated.foodName, isNull);
      expect(updated.notes, original.notes);
      expect(updated.scheduledDate, original.scheduledDate);
      expect(loaded.entries.single, updated);
      expect(cubit.totalsFor('pet').last.amountGrams, 40);
      expect(loaded.plans.single.meals.single.amountGrams, 30);
      verify(() => repository.updateFeedingEntry(updated)).called(1);
      verifyNoMoreInteractions(repository);
      expect(ids.calls, 0);
    },
  );

  test(
    'corrections preserve planned completion when the actual instant leaves the visible history range',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      when(
        () => repository.updateFeedingEntry(any()),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final meal = (cubit.state as FeedingLoaded).meals.single;
      await cubit.saveMeal(
        meal,
        amountGrams: 40,
        givenAt: date.subtract(const Duration(days: 8)),
      );
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.entries, isEmpty);
      expect(loaded.meals.single.entry!.amountGrams, 40);
      expect(cubit.totalsFor('pet').last.amountGrams, isNull);
    },
  );

  test(
    'failed corrections retain their exact intent and retry without recreating a meal',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      when(
        () => repository.updateFeedingEntry(any()),
      ).thenAnswer((_) async => const Error(failure));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final meal = (cubit.state as FeedingLoaded).meals.single;
      expect(
        await cubit.saveMeal(meal, amountGrams: 40, givenAt: recorded.givenAt),
        isFalse,
      );
      final failed = cubit.state as FeedingLoaded;
      expect(failed.meals.single.entry, recorded);
      expect(failed.failedAction, isA<UpdateFeedingMealAction>());
      when(
        () => repository.updateFeedingEntry(any()),
      ).thenAnswer((_) async => const Success(null));
      await cubit.performAction(failed.failedAction!);
      expect(
        (cubit.state as FeedingLoaded).meals.single.entry!.amountGrams,
        40,
      );
      verifyNever(() => repository.createFeedingEntry(any()));
    },
  );

  test(
    'unchanged, stale and future meal submissions do not create or overwrite records',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final meal = (cubit.state as FeedingLoaded).meals.single;
      clearInteractions(repository);
      expect(
        await cubit.saveMeal(
          meal,
          amountGrams: recorded.amountGrams,
          givenAt: recorded.givenAt,
        ),
        isTrue,
      );
      expect(
        await cubit.saveMeal(
          meal,
          amountGrams: 40,
          givenAt: clock.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
      cubit.removeDeletedEntry('pet', recorded.id);
      expect(
        await cubit.saveMeal(meal, amountGrams: 40, givenAt: clock),
        isFalse,
      );
      verifyZeroInteractions(repository);
      expect(ids.calls, 0);
    },
  );

  blocTest<FeedingCubit, FeedingState>(
    'scoped loading exposes known meals and seven-day totals',
    build: makeCubit,
    act: (cubit) => cubit.load(petId: 'pet'),
    expect: () => [
      const FeedingLoading(),
      isA<FeedingLoaded>()
          .having((s) => s.petId, 'owner', 'pet')
          .having(
            (s) => s.meals.single.entry,
            'no record after successful reads',
            isNull,
          )
          .having((s) => s.historyDays, 'days', 7),
    ],
    verify: (cubit) {
      verify(
        () => repository.getFeedingEntries(
          'pet',
          from: DateTime(2026, 10, 26),
          before: DateTime(2026, 11, 2),
        ),
      ).called(1);
      verifyNever(() => repository.getAllFeedingPlans());
      expect(cubit.totalsFor('pet'), hasLength(7));
      expect(cubit.totalsFor('other'), isEmpty);
    },
  );

  test(
    'global reads use bounded all-pets methods and keep totals separate by pet',
    () async {
      stubReads(
        entries: [
          recorded,
          FeedingEntry(
            id: 'other',
            petId: 'other',
            amountGrams: 100,
            givenAt: clock,
          ),
        ],
      );
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(historyDays: 30);
      expect((cubit.state as FeedingLoaded).petId, isNull);
      expect(cubit.totalsFor('pet').last.amountGrams, 25);
      expect(cubit.totalsFor('other').last.amountGrams, 100);
      verify(() => repository.getAllFeedingPlans()).called(1);
      verify(
        () => repository.getAllFeedingEntries(
          from: DateTime(2026, 10, 3),
          before: DateTime(2026, 11, 2),
        ),
      ).called(1);
      verifyNever(() => repository.getFeedingPlans(any()));
    },
  );

  for (final read in ['plans', 'actual', 'planned']) {
    blocTest<FeedingCubit, FeedingState>(
      'a $read read failure never exposes unknown results as No record',
      build: () {
        if (read == 'plans') {
          when(
            () => repository.getFeedingPlans('pet'),
          ).thenAnswer((_) async => const Error(failure));
        }
        if (read == 'actual') {
          when(
            () => repository.getFeedingEntries(
              'pet',
              from: any(named: 'from'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => const Error(failure));
        }
        if (read == 'planned') {
          when(
            () => repository.getPlannedFeedingEntries(
              'pet',
              fromDate: any(named: 'fromDate'),
              toDate: any(named: 'toDate'),
            ),
          ).thenAnswer((_) async => const Error(failure));
        }
        return makeCubit();
      },
      act: (cubit) async {
        await cubit.load(petId: 'pet');
        await cubit.performAction(RecordFeedingMealAction(recorded));
      },
      expect: () => [const FeedingLoading(), const FeedingError(failure)],
      verify: (_) {
        expect(ids.calls, 0);
        verifyNever(() => repository.createFeedingEntry(any()));
      },
    );
  }

  test(
    'failed refresh preserves content/date and retries the requested range',
    () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final original = cubit.state as FeedingLoaded;
      when(
        () => repository.getFeedingPlans('pet'),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.load(
        petId: 'pet',
        date: DateTime(2026, 11, 2),
        historyDays: 30,
      );
      final failed = cubit.state as FeedingLoaded;
      expect(failed.meals, original.meals);
      expect(failed.date, original.date);
      expect(failed.refreshFailure, failure);
      await cubit.recordMeal(failed.meals.single);
      expect(ids.calls, 0);
      stubReads();
      await cubit.retryLoad();
      final retried = cubit.state as FeedingLoaded;
      expect(retried.date, DateTime(2026, 11, 2));
      expect(retried.historyDays, 30);
      expect(retried.refreshFailure, isNull);
    },
  );

  test('late reads cannot overwrite a newer owner or selected date', () async {
    final pending = Completer<Result<List<FeedingPlan>>>();
    when(
      () => repository.getFeedingPlans('pet'),
    ).thenAnswer((_) => pending.future);
    when(
      () => repository.getFeedingPlans('other'),
    ).thenAnswer((_) async => const Success([]));
    final cubit = makeCubit();
    addTearDown(cubit.close);
    final old = cubit.load(petId: 'pet');
    await cubit.load(petId: 'other', date: DateTime(2026, 10, 31));
    pending.complete(Success([plan]));
    await old;
    final current = cubit.state as FeedingLoaded;
    expect(current.petId, 'other');
    expect(current.date, DateTime(2026, 10, 31));
    expect(current.plans, isEmpty);
    expect(current.meals, isEmpty);
  });

  test(
    'quick recording uses canonical meal data, updates local totals and blocks duplicates',
    () async {
      when(
        () => repository.createFeedingEntry(any()),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      clearInteractions(repository);
      final fake = FeedingOccurrence(
        plan: plan,
        date: date,
        meal: const FeedingMeal(
          id: 'meal',
          planId: 'plan',
          scheduledMinute: 0,
          amountGrams: 999,
        ),
      );
      await cubit.recordMeal(fake);
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.meals.single.entry!.amountGrams, 30);
      expect(loaded.meals.single.entry!.foodName, 'Food');
      expect(loaded.meals.single.entry!.givenAt, clock);
      expect(loaded.mutationRevision, 1);
      expect(cubit.totalsFor('pet').last.amountGrams, 30);
      await cubit.recordMeal(fake);
      expect(ids.calls, 1);
      verify(() => repository.createFeedingEntry(any())).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'pending writes block repeated taps, loads and clock refresh before the next frame',
    () async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.createFeedingEntry(any()),
      ).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final meal = (cubit.state as FeedingLoaded).meals.single;
      clearInteractions(repository);
      final saving = cubit.recordMeal(meal);
      await cubit.recordMeal(meal);
      await cubit.load(petId: 'other');
      await cubit.refreshForClockChange();
      expect(
        (cubit.state as FeedingLoaded).pendingAction,
        isA<RecordFeedingMealAction>(),
      );
      pending.complete(const Success(null));
      await saving;
      expect(ids.calls, 1);
      verify(() => repository.createFeedingEntry(any())).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'failed meal retains exact intent overnight, then succeeds once and follows today',
    () async {
      when(
        () => repository.createFeedingEntry(any()),
      ).thenAnswer((_) async => const Error(failure));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      await cubit.recordMeal((cubit.state as FeedingLoaded).meals.single);
      final failed = cubit.state as FeedingLoaded;
      expect(failed.meals.single.entry, isNull);
      expect(failed.actionFailure, same(failure));
      expect(failed.mutationRevision, 0);
      final action = failed.failedAction! as RecordFeedingMealAction;
      clock = DateTime(2026, 11, 2, 8);
      await cubit.refreshForClockChange();
      expect((cubit.state as FeedingLoaded).date, date);
      when(
        () => repository.createFeedingEntry(action.entry),
      ).thenAnswer((_) async => const Success(null));
      await cubit.performAction(action);
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.date, DateTime(2026, 11, 2));
      expect(loaded.lastMutation, action);
      expect(loaded.mutationRevision, 1);
      expect(loaded.actionFailure, isNull);
      expect(ids.calls, 1);
      verify(() => repository.createFeedingEntry(action.entry)).called(2);
    },
  );

  test(
    'successful deletion removes both views by known ID without rereading',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      when(
        () => repository.deleteFeedingEntry('pet', 'entry'),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      clearInteractions(repository);
      await cubit.performAction(
        const DeleteFeedingEntryAction('other', 'entry'),
      );
      await cubit.performAction(const DeleteFeedingEntryAction('pet', 'entry'));
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.entries, isEmpty);
      expect(loaded.meals.single.entry, isNull);
      expect(cubit.totalsFor('pet').last.amountGrams, isNull);
      await cubit.performAction(const DeleteFeedingEntryAction('pet', 'entry'));
      verify(() => repository.deleteFeedingEntry('pet', 'entry')).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'failed deletion keeps data and retries only on a new explicit action',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      when(
        () => repository.deleteFeedingEntry('pet', 'entry'),
      ).thenAnswer((_) async => const Error(failure));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      const action = DeleteFeedingEntryAction('pet', 'entry');
      await cubit.performAction(action);
      expect((cubit.state as FeedingLoaded).entries, [recorded]);
      expect((cubit.state as FeedingLoaded).failedAction, action);
      expect((cubit.state as FeedingLoaded).pendingAction, isNull);
      verify(() => repository.deleteFeedingEntry('pet', 'entry')).called(1);
      when(
        () => repository.deleteFeedingEntry('pet', 'entry'),
      ).thenAnswer((_) async => const Success(null));
      await cubit.performAction(action);
      expect((cubit.state as FeedingLoaded).actionFailure, isNull);
      expect((cubit.state as FeedingLoaded).mutationRevision, 1);
    },
  );

  test(
    'only an owned future plan may be canceled; history and entries remain',
    () async {
      stubReads(plans: [plan, next], entries: [recorded], planned: [recorded]);
      when(
        () => repository.deleteFeedingPlan('pet', 'next'),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      clearInteractions(repository);
      await cubit.performAction(const CancelFeedingPlanAction('pet', 'plan'));
      await cubit.performAction(const CancelFeedingPlanAction('other', 'next'));
      await cubit.performAction(const CancelFeedingPlanAction('pet', 'next'));
      expect((cubit.state as FeedingLoaded).plans, [plan]);
      expect((cubit.state as FeedingLoaded).entries, [recorded]);
      verify(() => repository.deleteFeedingPlan('pet', 'next')).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('future and historical days cannot use today quick recording', () async {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.load(petId: 'pet', date: DateTime(2026, 11, 2));
    await cubit.recordMeal((cubit.state as FeedingLoaded).meals.single);
    await cubit.performAction(
      RecordFeedingMealAction(
        FeedingEntry(
          id: 'future',
          petId: 'pet',
          amountGrams: 20,
          givenAt: clock,
          mealId: 'meal',
          scheduledDate: DateTime(2026, 11, 2),
        ),
      ),
    );
    clock = DateTime(2026, 11, 3);
    await cubit.recordMeal((cubit.state as FeedingLoaded).meals.single);
    expect(ids.calls, 0);
    verifyNever(() => repository.createFeedingEntry(any()));
  });

  test(
    'midnight reloads today without carrying completed meals; history stays selected',
    () async {
      stubReads(planned: [recorded]);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      clock = DateTime(2026, 11, 2);
      stubReads();
      await cubit.refreshForClockChange();
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.date, DateTime(2026, 11, 2));
      expect(loaded.meals.single.entry, isNull);
      await cubit.load(petId: 'pet', date: date);
      clearInteractions(repository);
      clock = DateTime(2026, 11, 2, 1);
      await cubit.refreshForClockChange();
      expect((cubit.state as FeedingLoaded).date, date);
      expect((cubit.state as FeedingLoaded).currentTime, clock);
      verifyZeroInteractions(repository);
    },
  );

  test(
    'a viewed future day reloads its results when it becomes today',
    () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final tomorrow = DateTime(2026, 11, 2);
      await cubit.load(petId: 'pet', date: tomorrow);
      expect((cubit.state as FeedingLoaded).meals.single.entry, isNull);
      clock = DateTime(2026, 11, 2, 8);
      final result = FeedingEntry(
        id: 'tomorrow',
        petId: 'pet',
        amountGrams: 30,
        givenAt: clock,
        mealId: 'meal',
        scheduledDate: tomorrow,
      );
      stubReads(entries: [result], planned: [result]);
      await cubit.refreshForClockChange();
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.date, tomorrow);
      expect(loaded.meals.single.entry, result);
      await cubit.recordMeal(loaded.meals.single);
      expect(ids.calls, 0);
      verifyNever(() => repository.createFeedingEntry(any()));
    },
  );

  test(
    'an older in-flight read cannot resurrect a successfully deleted record',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final pending = Completer<Result<List<FeedingPlan>>>();
      when(
        () => repository.getFeedingPlans('pet'),
      ).thenAnswer((_) => pending.future);
      final staleRead = cubit.load(petId: 'pet');
      stubReads(entries: [recorded], planned: [recorded]);
      await cubit.load(petId: 'pet');
      when(
        () => repository.deleteFeedingEntry('pet', 'entry'),
      ).thenAnswer((_) async => const Success(null));
      clearInteractions(repository);
      await cubit.performAction(const DeleteFeedingEntryAction('pet', 'entry'));
      pending.complete(Success([plan]));
      await staleRead;
      expect((cubit.state as FeedingLoaded).entries, isEmpty);
      expect((cubit.state as FeedingLoaded).meals.single.entry, isNull);
      verify(() => repository.deleteFeedingEntry('pet', 'entry')).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'successful write followed by failed midnight refresh remains a committed mutation',
    () async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.createFeedingEntry(any()),
      ).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final saving = cubit.recordMeal(
        (cubit.state as FeedingLoaded).meals.single,
      );
      clock = DateTime(2026, 11, 2);
      when(
        () => repository.getFeedingPlans('pet'),
      ).thenAnswer((_) async => const Error(failure));
      pending.complete(const Success(null));
      await saving;
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.entries.single.id, 'id-1');
      expect(loaded.meals.single.entry, isNotNull);
      expect(loaded.actionFailure, isNull);
      expect(loaded.refreshFailure, failure);
      expect(loaded.mutationRevision, 1);
      stubReads();
      await cubit.retryLoad();
      expect((cubit.state as FeedingLoaded).date, DateTime(2026, 11, 2));
      expect((cubit.state as FeedingLoaded).mutationRevision, 1);
      verify(() => repository.createFeedingEntry(any())).called(1);
    },
  );

  test(
    'known deletion is reconciled with an in-flight refresh without rereading',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load(petId: 'pet');
      final pending = Completer<Result<List<FeedingPlan>>>();
      when(
        () => repository.getFeedingPlans('pet'),
      ).thenAnswer((_) => pending.future);
      final loading = cubit.load(petId: 'pet');
      clearInteractions(repository);
      cubit.removeDeletedEntry('pet', recorded.id);
      pending.complete(Success([plan]));
      await loading;
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.entries, isEmpty);
      expect(loaded.meals.single.entry, isNull);
      verifyZeroInteractions(repository);
    },
  );

  test(
    'failed refresh cannot restore a pet removed while the read was pending',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      final pending = Completer<Result<List<FeedingPlan>>>();
      when(repository.getAllFeedingPlans).thenAnswer((_) => pending.future);
      final loading = cubit.load();
      clearInteractions(repository);
      cubit.removeDeletedPet('pet');
      pending.complete(const Error(failure));
      await loading;
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.refreshFailure, failure);
      expect(loaded.plans, isEmpty);
      expect(loaded.entries, isEmpty);
      expect(loaded.plannedEntries, isEmpty);
      expect(loaded.meals, isEmpty);
      verifyZeroInteractions(repository);
    },
  );

  test(
    'pet deletion during first global load removes its plans and entries from the result',
    () async {
      stubReads(entries: [recorded], planned: [recorded]);
      final pending = Completer<Result<List<FeedingPlan>>>();
      when(repository.getAllFeedingPlans).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final loading = cubit.load();
      clearInteractions(repository);
      cubit.removeDeletedPet('pet');
      pending.complete(Success([plan]));
      await loading;
      final loaded = cubit.state as FeedingLoaded;
      expect(loaded.plans, isEmpty);
      expect(loaded.entries, isEmpty);
      expect(loaded.plannedEntries, isEmpty);
      expect(loaded.meals, isEmpty);
      verifyZeroInteractions(repository);
    },
  );

  test(
    'closing during a read suppresses late emissions and further work',
    () async {
      final pending = Completer<Result<List<FeedingPlan>>>();
      when(
        () => repository.getFeedingPlans('pet'),
      ).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      final loading = cubit.load(petId: 'pet');
      await cubit.close();
      pending.complete(Success([plan]));
      await expectLater(loading, completes);
      clearInteractions(repository);
      await cubit.load();
      await cubit.retryLoad();
      await cubit.refreshForClockChange();
      await cubit.performAction(const CancelFeedingPlanAction('pet', 'next'));
      verifyZeroInteractions(repository);
      expect(ids.calls, 0);
    },
  );

  test(
    'closing during a write does not cancel it or emit a late result',
    () async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.createFeedingEntry(any()),
      ).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      await cubit.load(petId: 'pet');
      final meal = (cubit.state as FeedingLoaded).meals.single;
      final saving = cubit.recordMeal(meal);
      await cubit.close();
      pending.complete(const Success(null));
      await expectLater(saving, completes);
      await cubit.recordMeal(meal);
      expect(ids.calls, 1);
      verify(() => repository.createFeedingEntry(any())).called(1);
    },
  );
}
