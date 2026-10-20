import 'package:equatable/equatable.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';

final class Medication extends Equatable {
  final String id;
  final String petId;
  final String name;

  /// All periods, ordered by start date, including when reading by linked visit.
  final List<MedicationPeriod> periods;

  Medication({
    required this.id,
    required this.petId,
    required this.name,
    required List<MedicationPeriod> periods,
  }) : periods = List.unmodifiable(periods);

  @override
  List<Object?> get props => [id, petId, name, periods];
}
