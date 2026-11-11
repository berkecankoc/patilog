import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:patilog/features/medication/data/models/medication_model_values.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';

final class MedicationPeriodModel extends Equatable {
  final String id;
  final String medicationId;
  final DateTime startDate;
  final DateTime? endDate;
  final int intervalDays;
  final List<int> doseTimes;
  final String? dosageInstructions;
  final String? vetVisitId;
  final String? clinicName;
  final String? veterinarianName;
  final String? notes;

  MedicationPeriodModel({
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

  factory MedicationPeriodModel.fromJson(Map<String, dynamic> json) =>
      MedicationPeriodModel(
        id: json['id'] as String,
        medicationId: json['medication_id'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] == null
            ? null
            : DateTime.parse(json['end_date'] as String),
        intervalDays: json['interval_days'] as int,
        doseTimes: (jsonDecode(json['dose_times'] as String) as List)
            .cast<int>(),
        dosageInstructions: json['dosage_instructions'] as String?,
        vetVisitId: json['vet_visit_id'] as String?,
        clinicName: json['clinic_name'] as String?,
        veterinarianName: json['veterinarian_name'] as String?,
        notes: json['notes'] as String?,
      );

  factory MedicationPeriodModel.fromEntity(MedicationPeriod period) =>
      MedicationPeriodModel(
        id: period.id,
        medicationId: period.medicationId,
        startDate: period.startDate,
        endDate: period.endDate,
        intervalDays: period.intervalDays,
        doseTimes: period.doseTimes,
        dosageInstructions: period.dosageInstructions,
        vetVisitId: period.vetVisitId,
        clinicName: period.clinicName,
        veterinarianName: period.veterinarianName,
        notes: period.notes,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'medication_id': medicationId,
    'start_date': calendarDateKey(startDate),
    'end_date': endDate == null ? null : calendarDateKey(endDate!),
    'interval_days': intervalDays,
    'dose_times': jsonEncode(doseTimes),
    'dosage_instructions': optionalText(dosageInstructions),
    'vet_visit_id': vetVisitId,
    'clinic_name': optionalText(clinicName),
    'veterinarian_name': optionalText(veterinarianName),
    'notes': optionalText(notes),
  };

  MedicationPeriod toEntity() => MedicationPeriod(
    id: id,
    medicationId: medicationId,
    startDate: startDate,
    endDate: endDate,
    intervalDays: intervalDays,
    doseTimes: doseTimes,
    dosageInstructions: dosageInstructions,
    vetVisitId: vetVisitId,
    clinicName: clinicName,
    veterinarianName: veterinarianName,
    notes: notes,
  );

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
