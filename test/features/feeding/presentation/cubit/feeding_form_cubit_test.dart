import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_meal.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';
import 'package:petlytics/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_form_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_form_state.dart';

class MockFeedingRepository extends Mock implements FeedingRepository {}

class CountingIds implements IdGenerator {
  int calls = 0;
  @override
  String generate() => 'new-${++calls}';
}

void main() {
  late MockFeedingRepository repository;
  late CountingIds ids;
  final date = DateTime(2026, 11, 1, 12);
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
      ),
    ],
  );
  final entry = FeedingEntry(
    id: 'entry',
    petId: 'pet',
    givenAt: date,
    amountGrams: 30,
    mealId: 'meal',
    scheduledDate: DateTime(2026, 11, 1),
  );
  const failure = NotFoundFailure('Deleted');

  setUpAll(() {
    registerFallbackValue(plan);
    registerFallbackValue(entry);
  });
  setUp(() {
    repository = MockFeedingRepository();
    ids = CountingIds();
  });
  FeedingFormCubit makeCubit() => FeedingFormCubit(repository, ids);
  Future<void> saveEntry(FeedingFormCubit cubit, {FeedingEntry? existing}) =>
      cubit.saveEntry(
        petId: 'pet',
        existing: existing,
        amountGrams: 25.5,
        givenAt: date,
        foodName: ' Food ',
        notes: '  ',
      );

  blocTest<FeedingFormCubit, FeedingFormState>(
    'manual creation saves normalized snapshots and is terminal',
    build: () {
      when(
        () => repository.createFeedingEntry(any()),
      ).thenAnswer((_) async => const Success(null));
      return makeCubit();
    },
    act: (cubit) async {
      await saveEntry(cubit);
      await saveEntry(cubit);
    },
    expect: () => [
      const FeedingFormState(isSaving: true),
      isA<FeedingFormState>()
          .having((s) => s.isSaved, 'saved', true)
          .having((s) => s.savedEntry!.mealId, 'manual', isNull)
          .having((s) => s.savedEntry!.foodName, 'trimmed', 'Food')
          .having((s) => s.savedEntry!.notes, 'blank', isNull),
    ],
    verify: (_) {
      expect(ids.calls, 1);
      verify(() => repository.createFeedingEntry(any())).called(1);
      verifyNever(() => repository.updateFeedingEntry(any()));
    },
  );

  test(
    'entry corrections retain owner/ID/occurrence while allowing actual time and amount changes',
    () async {
      when(
        () => repository.updateFeedingEntry(any()),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.saveEntry(
        petId: 'pet',
        existing: entry,
        amountGrams: 35,
        givenAt: DateTime(2026, 11, 2, 1),
        notes: ' Late feeding ',
      );
      final saved = cubit.state.savedEntry!;
      expect(saved.id, entry.id);
      expect(saved.petId, entry.petId);
      expect(saved.mealId, entry.mealId);
      expect(saved.scheduledDate, entry.scheduledDate);
      expect(saved.amountGrams, 35);
      expect(saved.givenAt, DateTime(2026, 11, 2, 1));
      expect(saved.notes, 'Late feeding');
      expect(entry.amountGrams, 30);
      expect(ids.calls, 0);
    },
  );

  test(
    'new plan versions generate a fresh parent/meal identity and normalize calendar fields',
    () async {
      when(
        () => repository.createFeedingPlan(any()),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.savePlan(
        petId: 'pet',
        startDate: date,
        endDate: DateTime.utc(2026, 12, 31, 23),
        meals: const [
          FeedingMealDraft(
            id: 'old-meal',
            scheduledMinute: 1000,
            amountGrams: 40,
            foodName: ' ',
          ),
          FeedingMealDraft(
            scheduledMinute: 540,
            amountGrams: 30,
            foodName: ' Food ',
          ),
        ],
      );
      final saved = cubit.state.savedPlan!;
      expect(saved.id, 'new-1');
      expect(saved.meals.map((m) => m.id).toSet(), {'new-2', 'new-3'});
      expect(saved.meals.every((m) => m.planId == saved.id), isTrue);
      expect(saved.meals.map((m) => m.foodName), ['Food', null]);
      expect(saved.startDate, DateTime(2026, 11, 1));
      expect(saved.endDate, DateTime(2026, 12, 31));
      expect(ids.calls, 3);
      verifyNever(() => repository.updateFeedingPlan(any()));
    },
  );

  test(
    'editing a pending plan keeps existing IDs and generates IDs only for added meals',
    () async {
      when(
        () => repository.updateFeedingPlan(any()),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.savePlan(
        petId: 'pet',
        existing: plan,
        startDate: date,
        meals: const [
          FeedingMealDraft(id: 'meal', scheduledMinute: 540, amountGrams: 35),
          FeedingMealDraft(scheduledMinute: 1000, amountGrams: 40),
        ],
      );
      expect(cubit.state.savedPlan!.id, 'plan');
      expect(cubit.state.savedPlan!.meals.map((m) => m.id), ['meal', 'new-1']);
      expect(ids.calls, 1);
      verify(() => repository.updateFeedingPlan(any())).called(1);
      verifyNever(() => repository.createFeedingPlan(any()));
    },
  );

  test(
    'foreign records and unknown existing meal IDs fail before generating IDs or writing',
    () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.saveEntry(
        petId: 'other',
        existing: entry,
        amountGrams: 10,
        givenAt: date,
      );
      expect(cubit.state.saveFailure, isA<NotFoundFailure>());
      await cubit.savePlan(
        petId: 'other',
        existing: plan,
        startDate: date,
        meals: const [],
      );
      expect(cubit.state.saveFailure, isA<NotFoundFailure>());
      await cubit.savePlan(
        petId: 'pet',
        existing: plan,
        startDate: date,
        meals: const [
          FeedingMealDraft(
            id: 'foreign',
            scheduledMinute: 540,
            amountGrams: 20,
          ),
        ],
      );
      expect(cubit.state.saveFailure, isA<NotFoundFailure>());
      expect(ids.calls, 0);
      verifyZeroInteractions(repository);
    },
  );

  for (final isPlan in [false, true]) {
    test(
      '${isPlan ? 'plan' : 'entry'} failure remains typed and can retry without background reloads',
      () async {
        Future<void> save(FeedingFormCubit cubit) => isPlan
            ? cubit.savePlan(
                petId: 'pet',
                existing: plan,
                startDate: date,
                meals: const [
                  FeedingMealDraft(
                    id: 'meal',
                    scheduledMinute: 540,
                    amountGrams: 30,
                  ),
                ],
              )
            : saveEntry(cubit, existing: entry);
        if (isPlan) {
          when(
            () => repository.updateFeedingPlan(any()),
          ).thenAnswer((_) async => const Error(failure));
        } else {
          when(
            () => repository.updateFeedingEntry(any()),
          ).thenAnswer((_) async => const Error(failure));
        }
        final cubit = makeCubit();
        addTearDown(cubit.close);
        await save(cubit);
        expect(cubit.state.saveFailure, same(failure));
        expect(cubit.state.isSaved, isFalse);
        final pending = Completer<Result<void>>();
        if (isPlan) {
          when(
            () => repository.updateFeedingPlan(any()),
          ).thenAnswer((_) => pending.future);
        } else {
          when(
            () => repository.updateFeedingEntry(any()),
          ).thenAnswer((_) => pending.future);
        }
        final saving = save(cubit);
        expect(cubit.state.saveFailure, isNull);
        expect(cubit.state.isSaving, isTrue);
        await save(cubit);
        await saveEntry(cubit);
        pending.complete(const Success(null));
        await saving;
        expect(cubit.state.isSaved, isTrue);
        expect(ids.calls, 0);
        if (isPlan) {
          verify(() => repository.updateFeedingPlan(any())).called(2);
        } else {
          verify(() => repository.updateFeedingEntry(any())).called(2);
        }
        verifyNoMoreInteractions(repository);
      },
    );
  }

  test(
    'closing during save suppresses late emissions and all further writes',
    () async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.createFeedingEntry(any()),
      ).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      final saving = saveEntry(cubit);
      await cubit.close();
      pending.complete(const Success(null));
      await expectLater(saving, completes);
      await saveEntry(cubit);
      await cubit.savePlan(petId: 'pet', startDate: date, meals: const []);
      expect(ids.calls, 1);
      verify(() => repository.createFeedingEntry(any())).called(1);
      verifyNoMoreInteractions(repository);
    },
  );
}
