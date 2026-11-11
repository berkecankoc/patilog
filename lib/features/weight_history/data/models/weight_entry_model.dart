import 'package:equatable/equatable.dart';
import 'package:patilog/core/utils/weight_utils.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';

final class WeightEntryModel extends Equatable {
  final String id;
  final String petId;
  final double weight;
  final DateTime measuredAt;

  const WeightEntryModel({
    required this.id,
    required this.petId,
    required this.weight,
    required this.measuredAt,
  });

  factory WeightEntryModel.fromJson(Map<String, dynamic> json) =>
      WeightEntryModel(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        weight: (json['weight'] as num).toDouble(),
        measuredAt: DateTime.parse(json['measured_at'] as String).toUtc(),
      );

  factory WeightEntryModel.fromEntity(WeightEntry entry) => WeightEntryModel(
    id: entry.id,
    petId: entry.petId,
    weight: entry.weight,
    measuredAt: entry.measuredAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pet_id': petId,
    'weight': normalizeWeight(weight),
    // Normalize stored timestamps so text ordering follows measurement time.
    'measured_at': _formatTimestamp(measuredAt),
  };

  WeightEntry toEntity() =>
      WeightEntry(id: id, petId: petId, weight: weight, measuredAt: measuredAt);

  static String _formatTimestamp(DateTime date) {
    final utc = date.toUtc();
    final timestamp = utc.toIso8601String();
    // Dart omits zero microseconds; keep fixed precision for SQLite text ordering.
    return utc.microsecond == 0
        ? timestamp.replaceFirst('Z', '000Z')
        : timestamp;
  }

  @override
  List<Object?> get props => [id, petId, weight, measuredAt];
}
