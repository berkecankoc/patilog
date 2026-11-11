import 'package:equatable/equatable.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';

/// A computed occurrence; only its optional result is persisted.
final class MedicationDose extends Equatable {
  final Medication medication;
  final MedicationPeriod period;
  final DateTime scheduledDate;
  final int scheduledMinute;

  /// Null means no record, including for past doses; never infer skipped.
  final MedicationDoseLog? log;

  const MedicationDose({
    required this.medication,
    required this.period,
    required this.scheduledDate,
    required this.scheduledMinute,
    this.log,
  });

  @override
  List<Object?> get props => [
    medication,
    period,
    scheduledDate,
    scheduledMinute,
    log,
  ];
}
