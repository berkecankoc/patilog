import 'package:equatable/equatable.dart';

final class WeightEntry extends Equatable {
  final String id;
  final String petId;

  /// Measured weight in kilograms.
  final double weight;
  final DateTime measuredAt;

  const WeightEntry({
    required this.id,
    required this.petId,
    required this.weight,
    required this.measuredAt,
  });

  @override
  List<Object?> get props => [id, petId, weight, measuredAt];
}
