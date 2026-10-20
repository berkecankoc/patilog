import 'package:equatable/equatable.dart';

final class MedicationPeriod extends Equatable {
  final String id;
  final String medicationId;

  /// Calendar dates without UTC conversion. End is inclusive; a later period
  /// takes over from its start date even when this end is absent or later.
  final DateTime startDate;
  final DateTime? endDate;
  final int intervalDays;

  /// Local minutes since midnight (0–1439), sorted without removing duplicates.
  /// Writes must reject duplicates; these are wall-clock times, not UTC instants.
  final List<int> doseTimes;

  final String? dosageInstructions;
  final String? vetVisitId;
  final String? clinicName;
  final String? veterinarianName;
  final String? notes;

  MedicationPeriod({
    required this.id,
    required this.medicationId,
    required this.startDate,
    this.endDate,
    required this.intervalDays,
    required List<int> doseTimes,
    this.dosageInstructions,
    this.vetVisitId,
    this.clinicName,
    this.veterinarianName,
    this.notes,
  }) : doseTimes = List.unmodifiable(List<int>.of(doseTimes)..sort());

  @override
  List<Object?> get props => [
    id,
    medicationId,
    startDate,
    endDate,
    intervalDays,
    doseTimes,
    dosageInstructions,
    vetVisitId,
    clinicName,
    veterinarianName,
    notes,
  ];
}
