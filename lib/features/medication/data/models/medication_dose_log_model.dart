import 'package:equatable/equatable.dart';
import 'package:patilog/features/medication/data/models/medication_model_values.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';

final class MedicationDoseLogModel extends Equatable {
  final String periodId;
  final DateTime scheduledDate;
  final int scheduledMinute;
  final MedicationDoseStatus status;
  final DateTime? givenAt;

  const MedicationDoseLogModel({
    required this.periodId,
    required this.scheduledDate,
    required this.scheduledMinute,
    required this.status,
    this.givenAt,
  });

  factory MedicationDoseLogModel.fromJson(Map<String, dynamic> json) =>
      MedicationDoseLogModel(
        periodId: json['period_id'] as String,
        scheduledDate: DateTime.parse(json['scheduled_date'] as String),
        scheduledMinute: json['scheduled_minute'] as int,
        status: MedicationDoseStatus.values.byName(json['status'] as String),
        givenAt: json['given_at'] == null
            ? null
            : DateTime.parse(json['given_at'] as String),
      );

  factory MedicationDoseLogModel.fromEntity(MedicationDoseLog log) =>
      MedicationDoseLogModel(
        periodId: log.periodId,
        scheduledDate: log.scheduledDate,
        scheduledMinute: log.scheduledMinute,
        status: log.status,
        givenAt: log.givenAt,
      );

  Map<String, dynamic> toJson() => {
    'period_id': periodId,
    'scheduled_date': calendarDateKey(scheduledDate),
    'scheduled_minute': scheduledMinute,
    'status': status.name,
    'given_at': givenAt?.toUtc().toIso8601String(),
  };

  MedicationDoseLog toEntity() => MedicationDoseLog(
    periodId: periodId,
    scheduledDate: scheduledDate,
    scheduledMinute: scheduledMinute,
    status: status,
    givenAt: givenAt,
  );

  @override
  List<Object?> get props => [
    periodId,
    scheduledDate,
    scheduledMinute,
    status,
    givenAt,
  ];
}
