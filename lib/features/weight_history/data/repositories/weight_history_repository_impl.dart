import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/weight_history/data/data_sources/weight_history_local_data_source.dart';
import 'package:patilog/features/weight_history/data/models/weight_entry_model.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/domain/repositories/weight_history_repository.dart';

final class WeightHistoryRepositoryImpl implements WeightHistoryRepository {
  final WeightHistoryLocalDataSource localDataSource;
  const WeightHistoryRepositoryImpl(this.localDataSource);

  @override
  Future<Result<List<WeightEntry>>> getAllWeightEntries() async {
    try {
      final models = await localDataSource.getAllWeightEntries();
      return Success(models.map((model) => model.toEntity()).toList());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load weight history'));
    }
  }

  @override
  Future<Result<List<WeightEntry>>> getWeightEntries(String petId) async {
    try {
      final models = await localDataSource.getWeightEntries(petId);
      return Success(models.map((model) => model.toEntity()).toList());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load weight history'));
    }
  }

  @override
  Future<Result<void>> createWeightEntry(WeightEntry entry) async {
    try {
      await localDataSource.createWeightEntry(
        WeightEntryModel.fromEntity(entry),
      );
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to create measurement'));
    }
  }

  @override
  Future<Result<void>> updateWeightEntry(WeightEntry entry) async {
    try {
      await localDataSource.updateWeightEntry(
        WeightEntryModel.fromEntity(entry),
      );
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to update measurement'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Measurement not found'));
    }
  }

  @override
  Future<Result<void>> deleteWeightEntry(String id) async {
    try {
      await localDataSource.deleteWeightEntry(id);
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to delete measurement'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Measurement not found'));
    }
  }
}
