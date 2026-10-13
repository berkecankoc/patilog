import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';

abstract interface class WeightHistoryRepository {
  /// Returns this pet's measurements, newest measurement first.
  /// Returns an empty list when the pet has no measurements.
  Future<Result<List<WeightEntry>>> getWeightEntries(String petId);

  Future<Result<void>> createWeightEntry(WeightEntry entry);
  Future<Result<void>> updateWeightEntry(WeightEntry entry);
  Future<Result<void>> deleteWeightEntry(String id);
}
