import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/feeding/data/data_sources/feeding_local_data_source.dart';
import 'package:petlytics/features/feeding/data/models/feeding_entry_model.dart';
import 'package:petlytics/features/feeding/data/models/feeding_meal_model.dart';
import 'package:petlytics/features/feeding/data/models/feeding_plan_model.dart';
import 'package:petlytics/features/feeding/data/repositories/feeding_repository_impl.dart';

class MockFeedingLocalDataSource extends Mock
    implements FeedingLocalDataSource {}

void main() {
  late MockFeedingLocalDataSource source;
  late FeedingRepositoryImpl repository;
  final start = DateTime(2026, 11, 1);
  final end = DateTime(2026, 11, 2);
  final plan = FeedingPlanModel(
    id: 'plan',
    petId: 'pet',
    startDate: start,
    meals: const [
      FeedingMealModel(
        id: 'meal',
        planId: 'plan',
        scheduledMinute: 540,
        amountGrams: 30.5,
      ),
    ],
  );
  final entry = FeedingEntryModel(
    id: 'entry',
    petId: 'pet',
    amountGrams: 25.5,
    givenAt: start,
    mealId: 'meal',
    scheduledDate: start,
    foodName: 'Snapshot',
    notes: 'Note',
  );

  setUp(() {
    source = MockFeedingLocalDataSource();
    repository = FeedingRepositoryImpl(source);
  });

  test(
    'scoped/all plan reads and a single read convert nested entities',
    () async {
      when(() => source.getFeedingPlans('pet')).thenAnswer((_) async => [plan]);
      when(() => source.getAllFeedingPlans()).thenAnswer((_) async => [plan]);
      when(
        () => source.getFeedingPlanById('pet', 'plan'),
      ).thenAnswer((_) async => plan);
      expect(
        await repository.getFeedingPlans('pet'),
        Success([plan.toEntity()]),
      );
      expect(await repository.getAllFeedingPlans(), Success([plan.toEntity()]));
      expect(
        await repository.getFeedingPlanById('pet', 'plan'),
        Success(plan.toEntity()),
      );
      verify(() => source.getFeedingPlanById('pet', 'plan')).called(1);
    },
  );

  test(
    'actual and planned read bounds forward unchanged and convert snapshots',
    () async {
      when(
        () => source.getFeedingEntries('pet', from: start, before: end),
      ).thenAnswer((_) async => [entry]);
      when(
        () => source.getAllFeedingEntries(from: start, before: end),
      ).thenAnswer((_) async => [entry]);
      when(
        () => source.getPlannedFeedingEntries(
          'pet',
          fromDate: start,
          toDate: end,
        ),
      ).thenAnswer((_) async => [entry]);
      when(
        () => source.getAllPlannedFeedingEntries(fromDate: start, toDate: end),
      ).thenAnswer((_) async => [entry]);
      expect(
        await repository.getFeedingEntries('pet', from: start, before: end),
        Success([entry.toEntity()]),
      );
      expect(
        await repository.getAllFeedingEntries(from: start, before: end),
        Success([entry.toEntity()]),
      );
      expect(
        await repository.getPlannedFeedingEntries(
          'pet',
          fromDate: start,
          toDate: end,
        ),
        Success([entry.toEntity()]),
      );
      expect(
        await repository.getAllPlannedFeedingEntries(
          fromDate: start,
          toDate: end,
        ),
        Success([entry.toEntity()]),
      );
    },
  );

  test(
    'writes use model factories and succeed without a second read',
    () async {
      when(() => source.createFeedingPlan(plan)).thenAnswer((_) async {});
      when(() => source.updateFeedingPlan(plan)).thenAnswer((_) async {});
      when(() => source.createFeedingEntry(entry)).thenAnswer((_) async {});
      when(() => source.updateFeedingEntry(entry)).thenAnswer((_) async {});
      when(
        () => source.deleteFeedingPlan('pet', 'plan'),
      ).thenAnswer((_) async {});
      when(
        () => source.deleteFeedingEntry('pet', 'entry'),
      ).thenAnswer((_) async {});
      expect(
        await repository.createFeedingPlan(plan.toEntity()),
        isA<Success<void>>(),
      );
      expect(
        await repository.updateFeedingPlan(plan.toEntity()),
        isA<Success<void>>(),
      );
      expect(
        await repository.createFeedingEntry(entry.toEntity()),
        isA<Success<void>>(),
      );
      expect(
        await repository.updateFeedingEntry(entry.toEntity()),
        isA<Success<void>>(),
      );
      expect(
        await repository.deleteFeedingPlan('pet', 'plan'),
        isA<Success<void>>(),
      );
      expect(
        await repository.deleteFeedingEntry('pet', 'entry'),
        isA<Success<void>>(),
      );
      verify(() => source.createFeedingPlan(plan)).called(1);
      verify(() => source.updateFeedingPlan(plan)).called(1);
      verify(() => source.createFeedingEntry(entry)).called(1);
      verify(() => source.updateFeedingEntry(entry)).called(1);
      verify(() => source.deleteFeedingPlan('pet', 'plan')).called(1);
      verify(() => source.deleteFeedingEntry('pet', 'entry')).called(1);
      verifyNoMoreInteractions(source);
    },
  );

  test('empty lists remain successful reads', () async {
    when(() => source.getFeedingPlans('pet')).thenAnswer((_) async => []);
    when(
      () => source.getAllFeedingEntries(from: start, before: end),
    ).thenAnswer((_) async => []);
    expect(
      await repository.getFeedingPlans('pet'),
      isA<Success>().having((result) => result.data, 'data', isEmpty),
    );
    expect(
      await repository.getAllFeedingEntries(from: start, before: end),
      isA<Success>().having((result) => result.data, 'data', isEmpty),
    );
  });

  for (final exception in [
    const LocalDataSourceException(),
    const LocalDataNotFoundException(),
  ]) {
    test(
      'every operation maps ${exception.runtimeType} to a typed failure',
      () async {
        when(() => source.getFeedingPlans('pet')).thenThrow(exception);
        when(() => source.getAllFeedingPlans()).thenThrow(exception);
        when(
          () => source.getFeedingPlanById('pet', 'plan'),
        ).thenThrow(exception);
        when(() => source.createFeedingPlan(plan)).thenThrow(exception);
        when(() => source.updateFeedingPlan(plan)).thenThrow(exception);
        when(
          () => source.deleteFeedingPlan('pet', 'plan'),
        ).thenThrow(exception);
        when(
          () => source.getFeedingEntries('pet', from: start, before: end),
        ).thenThrow(exception);
        when(
          () => source.getAllFeedingEntries(from: start, before: end),
        ).thenThrow(exception);
        when(
          () => source.getPlannedFeedingEntries(
            'pet',
            fromDate: start,
            toDate: end,
          ),
        ).thenThrow(exception);
        when(
          () =>
              source.getAllPlannedFeedingEntries(fromDate: start, toDate: end),
        ).thenThrow(exception);
        when(() => source.createFeedingEntry(entry)).thenThrow(exception);
        when(() => source.updateFeedingEntry(entry)).thenThrow(exception);
        when(
          () => source.deleteFeedingEntry('pet', 'entry'),
        ).thenThrow(exception);
        final operations = <Future<Result<dynamic>> Function()>[
          () => repository.getFeedingPlans('pet'),
          repository.getAllFeedingPlans,
          () => repository.getFeedingPlanById('pet', 'plan'),
          () => repository.createFeedingPlan(plan.toEntity()),
          () => repository.updateFeedingPlan(plan.toEntity()),
          () => repository.deleteFeedingPlan('pet', 'plan'),
          () => repository.getFeedingEntries('pet', from: start, before: end),
          () => repository.getAllFeedingEntries(from: start, before: end),
          () => repository.getPlannedFeedingEntries(
            'pet',
            fromDate: start,
            toDate: end,
          ),
          () => repository.getAllPlannedFeedingEntries(
            fromDate: start,
            toDate: end,
          ),
          () => repository.createFeedingEntry(entry.toEntity()),
          () => repository.updateFeedingEntry(entry.toEntity()),
          () => repository.deleteFeedingEntry('pet', 'entry'),
        ];
        for (final operation in operations) {
          final result = await operation();
          expect(result, isA<Error>());
          expect(
            (result as Error).failure,
            exception is LocalDataNotFoundException
                ? isA<NotFoundFailure>()
                : isA<LocalDatabaseFailure>(),
          );
        }
      },
    );
  }
}
