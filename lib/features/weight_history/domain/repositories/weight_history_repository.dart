import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';

abstract interface class WeightHistoryRepository {
  /// Returns this pet's measurements, newest measurement first.
  /// Returns an empty list when the pet has no measurements.
  Future<Result<List<WeightEntry>>> getWeightEntries(String petId);

  /// All pets' measurements, newest first, latest insertion first on ties.
  Future<Result<List<WeightEntry>>> getAllWeightEntries();

  Future<Result<void>> createWeightEntry(WeightEntry entry);
  Future<Result<void>> updateWeightEntry(WeightEntry entry);
  Future<Result<void>> deleteWeightEntry(String id);
}
