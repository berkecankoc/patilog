import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/feeding/data/data_sources/feeding_local_data_source.dart';
import 'package:patilog/features/feeding/data/models/feeding_entry_model.dart';
import 'package:patilog/features/feeding/data/models/feeding_plan_model.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';
import 'package:patilog/features/feeding/domain/repositories/feeding_repository.dart';

final class FeedingRepositoryImpl implements FeedingRepository {
  final FeedingLocalDataSource localDataSource;

  const FeedingRepositoryImpl(this.localDataSource);

  Future<Result<T>> _result<T>(
    Future<T> Function() action,
    String message,
  ) async {
    try {
      return Success(await action());
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Feeding record not found'));
    } on LocalDataSourceException {
      return Error(LocalDatabaseFailure(message));
    }
  }

  @override
  Future<Result<List<FeedingPlan>>> getFeedingPlans(String petId) => _result(
    () async => (await localDataSource.getFeedingPlans(
      petId,
    )).map((model) => model.toEntity()).toList(),
    'Failed to load feeding plans',
  );

  @override
  Future<Result<List<FeedingPlan>>> getAllFeedingPlans() => _result(
    () async => (await localDataSource.getAllFeedingPlans())
        .map((model) => model.toEntity())
        .toList(),
    'Failed to load feeding plans',
  );

  @override
  Future<Result<FeedingPlan>> getFeedingPlanById(String petId, String planId) =>
      _result(
        () async => (await localDataSource.getFeedingPlanById(
          petId,
          planId,
        )).toEntity(),
        'Failed to load feeding plan',
      );

  @override
  Future<Result<void>> createFeedingPlan(FeedingPlan plan) => _result(
    () => localDataSource.createFeedingPlan(FeedingPlanModel.fromEntity(plan)),
    'Failed to create feeding plan',
  );

  @override
  Future<Result<void>> updateFeedingPlan(FeedingPlan plan) => _result(
    () => localDataSource.updateFeedingPlan(FeedingPlanModel.fromEntity(plan)),
    'Failed to update feeding plan',
  );

  @override
  Future<Result<void>> deleteFeedingPlan(String petId, String planId) =>
      _result(
        () => localDataSource.deleteFeedingPlan(petId, planId),
        'Failed to delete feeding plan',
      );

  @override
  Future<Result<List<FeedingEntry>>> getFeedingEntries(
    String petId, {
    required DateTime from,
    required DateTime before,
  }) => _result(
    () async => (await localDataSource.getFeedingEntries(
      petId,
      from: from,
      before: before,
    )).map((model) => model.toEntity()).toList(),
    'Failed to load feeding entries',
  );

  @override
  Future<Result<List<FeedingEntry>>> getAllFeedingEntries({
    required DateTime from,
    required DateTime before,
  }) => _result(
    () async => (await localDataSource.getAllFeedingEntries(
      from: from,
      before: before,
    )).map((model) => model.toEntity()).toList(),
    'Failed to load feeding entries',
  );

  @override
  Future<Result<List<FeedingEntry>>> getPlannedFeedingEntries(
    String petId, {
    required DateTime fromDate,
    required DateTime toDate,
  }) => _result(
    () async => (await localDataSource.getPlannedFeedingEntries(
      petId,
      fromDate: fromDate,
      toDate: toDate,
    )).map((model) => model.toEntity()).toList(),
    'Failed to load planned feeding entries',
  );

  @override
  Future<Result<List<FeedingEntry>>> getAllPlannedFeedingEntries({
    required DateTime fromDate,
    required DateTime toDate,
  }) => _result(
    () async => (await localDataSource.getAllPlannedFeedingEntries(
      fromDate: fromDate,
      toDate: toDate,
    )).map((model) => model.toEntity()).toList(),
    'Failed to load planned feeding entries',
  );

  @override
  Future<Result<void>> createFeedingEntry(FeedingEntry entry) => _result(
    () =>
        localDataSource.createFeedingEntry(FeedingEntryModel.fromEntity(entry)),
    'Failed to create feeding entry',
  );

  @override
  Future<Result<void>> updateFeedingEntry(FeedingEntry entry) => _result(
    () =>
        localDataSource.updateFeedingEntry(FeedingEntryModel.fromEntity(entry)),
    'Failed to update feeding entry',
  );

  @override
  Future<Result<void>> deleteFeedingEntry(String petId, String entryId) =>
      _result(
        () => localDataSource.deleteFeedingEntry(petId, entryId),
        'Failed to delete feeding entry',
      );
}
