import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/di/injection.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';
import 'package:patilog/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:patilog/features/feeding/domain/use_cases/calculate_feeding_meals.dart';
import 'package:patilog/features/feeding/domain/use_cases/calculate_feeding_totals.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_form_cubit.dart';
import 'pet_care_test_harness.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';

class MockFeedingRepository extends Mock implements FeedingRepository {}

/// Existing app navigation with controllable feeding reads/writes for widget tests.
class FeedingTestHarness extends PetCareTestHarness {
  final feeding = MockFeedingRepository();
  List<FeedingPlan> plans = [];
  List<FeedingEntry> entries = [];
  bool failLoad = false;
  bool failSave = false;
  bool failDeleteEntry = false;
  Completer<Result<void>>? pendingSave;

  @override
  void register() {
    registerFallbackValue(clock);
    registerFallbackValue(sample());
    registerFallbackValue(sample().periods.first);
    registerFallbackValue(
      MedicationDoseLog(
        periodId: 'fallback',
        scheduledDate: today,
        scheduledMinute: 0,
        status: MedicationDoseStatus.given,
        givenAt: clock,
      ),
    );
    registerFallbackValue(
      VetVisit(
        id: 'fallback',
        petId: 'pet',
        visitedOn: today,
        reason: 'Fallback',
      ),
    );
    super.register();
    registerFallbackValue(clock);
    registerFallbackValue(
      FeedingEntry(id: '', petId: '', givenAt: clock, amountGrams: 1),
    );
    registerFallbackValue(
      FeedingPlan(id: '', petId: '', startDate: today, meals: []),
    );
    Result<List<FeedingPlan>> readPlans(String? pet) => failLoad
        ? const Error(LocalDatabaseFailure('Load failed'))
        : Success(plans.where((p) => pet == null || p.petId == pet).toList());
    when(feeding.getAllFeedingPlans).thenAnswer((_) async => readPlans(null));
    when(() => feeding.getFeedingPlans(any())).thenAnswer(
      (call) async => readPlans(call.positionalArguments[0] as String),
    );
    List<FeedingEntry> ordered(Iterable<FeedingEntry> values) {
      final indexed = values.toList().reversed.indexed.toList()
        ..sort((a, b) {
          final time = b.$2.givenAt.compareTo(a.$2.givenAt);
          return time == 0 ? a.$1.compareTo(b.$1) : time;
        });
      return indexed.map((item) => item.$2).toList();
    }

    Result<List<FeedingEntry>> actual(Invocation call, String? pet) => Success(
      ordered(
        entries.where(
          (e) =>
              (pet == null || e.petId == pet) &&
              !e.givenAt.isBefore(call.namedArguments[#from] as DateTime) &&
              e.givenAt.isBefore(call.namedArguments[#before] as DateTime),
        ),
      ),
    );
    Result<List<FeedingEntry>> planned(Invocation call, String? pet) => Success(
      ordered(
        entries.where(
          (e) =>
              (pet == null || e.petId == pet) &&
              e.scheduledDate != null &&
              !e.scheduledDate!.isBefore(
                call.namedArguments[#fromDate] as DateTime,
              ) &&
              !e.scheduledDate!.isAfter(
                call.namedArguments[#toDate] as DateTime,
              ),
        ),
      ),
    );
    when(
      () => feeding.getFeedingEntries(
        any(),
        from: any(named: 'from'),
        before: any(named: 'before'),
      ),
    ).thenAnswer(
      (call) async => actual(call, call.positionalArguments[0] as String),
    );
    when(
      () => feeding.getAllFeedingEntries(
        from: any(named: 'from'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((call) async => actual(call, null));
    when(
      () => feeding.getPlannedFeedingEntries(
        any(),
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer(
      (call) async => planned(call, call.positionalArguments[0] as String),
    );
    when(
      () => feeding.getAllPlannedFeedingEntries(
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer((call) async => planned(call, null));
    Future<Result<void>> write(void Function() commit) async {
      final result = pendingSave != null
          ? await pendingSave!.future
          : failSave
          ? const Error<void>(LocalDatabaseFailure('Save failed'))
          : const Success<void>(null);
      if (result is Success<void>) commit();
      return result;
    }

    when(() => feeding.createFeedingEntry(any())).thenAnswer(
      (call) =>
          write(() => entries.add(call.positionalArguments[0] as FeedingEntry)),
    );
    when(() => feeding.updateFeedingEntry(any())).thenAnswer(
      (call) => write(() {
        final updated = call.positionalArguments[0] as FeedingEntry;
        entries = entries
            .map(
              (e) =>
                  e.id == updated.id && e.petId == updated.petId ? updated : e,
            )
            .toList();
      }),
    );
    when(() => feeding.createFeedingPlan(any())).thenAnswer(
      (call) =>
          write(() => plans.add(call.positionalArguments[0] as FeedingPlan)),
    );
    when(() => feeding.updateFeedingPlan(any())).thenAnswer(
      (call) => write(() {
        final updated = call.positionalArguments[0] as FeedingPlan;
        plans = plans
            .map(
              (p) =>
                  p.id == updated.id && p.petId == updated.petId ? updated : p,
            )
            .toList();
      }),
    );
    when(() => feeding.deleteFeedingEntry(any(), any())).thenAnswer((
      call,
    ) async {
      if (failDeleteEntry) {
        return const Error(LocalDatabaseFailure('Delete failed'));
      }
      entries.removeWhere(
        (e) =>
            e.petId == call.positionalArguments[0] &&
            e.id == call.positionalArguments[1],
      );
      return const Success(null);
    });
    when(() => feeding.deleteFeedingPlan(any(), any())).thenAnswer((
      call,
    ) async {
      plans.removeWhere(
        (p) =>
            p.petId == call.positionalArguments[0] &&
            p.id == call.positionalArguments[1],
      );
      return const Success(null);
    });
    getIt.registerFactory<FeedingCubit>(
      () => FeedingCubit(
        feeding,
        ids,
        const CalculateFeedingMeals(),
        const CalculateFeedingTotals(),
        now: () => clock,
      ),
    );
    getIt.registerFactory<FeedingFormCubit>(
      () => FeedingFormCubit(feeding, ids),
    );
  }
}
