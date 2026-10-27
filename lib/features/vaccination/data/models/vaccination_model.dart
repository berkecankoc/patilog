import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:petlytics/features/vaccination/data/codecs/vaccination_reminder_codec.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';

final class VaccinationModel extends Equatable {
  final String id;
  final String petId;
  final String vaccineName;
  final VaccinationStatus status;
  final DateTime date;
  final String? clinicName;
  final String? veterinarianName;
  final String? notes;
  final String? vetVisitId;
  final VaccinationReminderSettings? reminderSettings;

  const VaccinationModel({
    required this.id,
    required this.petId,
    required this.vaccineName,
    required this.status,
    required this.date,
    this.clinicName,
    this.veterinarianName,
    this.notes,
    this.vetVisitId,
    this.reminderSettings,
  });

  factory VaccinationModel.fromJson(Map<String, dynamic> json) =>
      VaccinationModel(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        vaccineName: json['vaccine_name'] as String,
        status: VaccinationStatus.values.byName(json['status'] as String),
        date: DateTime.parse(json['date'] as String),
        clinicName: json['clinic_name'] as String?,
        veterinarianName: json['veterinarian_name'] as String?,
        notes: json['notes'] as String?,
        vetVisitId: json['vet_visit_id'] as String?,
        reminderSettings: switch (json['reminder_settings']) {
          null => null,
          String value => VaccinationReminderCodec.settingsFromJson(
            jsonDecode(value),
          ),
          _ => throw const FormatException(
            'Invalid vaccination reminder settings',
          ),
        },
      );

  factory VaccinationModel.fromEntity(Vaccination vaccination) =>
      VaccinationModel(
        id: vaccination.id,
        petId: vaccination.petId,
        vaccineName: vaccination.vaccineName,
        status: vaccination.status,
        date: vaccination.date,
        clinicName: vaccination.clinicName,
        veterinarianName: vaccination.veterinarianName,
        notes: vaccination.notes,
        vetVisitId: vaccination.vetVisitId,
        reminderSettings: vaccination.reminderSettings,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pet_id': petId,
    'vaccine_name': vaccineName.trim(),
    'status': status.name,
    // Calendar components preserve the chosen day in every time zone.
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'clinic_name': _optionalText(clinicName),
    'veterinarian_name': _optionalText(veterinarianName),
    'notes': _optionalText(notes),
    'vet_visit_id': vetVisitId,
    'reminder_settings': reminderSettings == null
        ? null
        : jsonEncode(
            VaccinationReminderCodec.settingsToJson(reminderSettings!),
          ),
  };

  Vaccination toEntity() => Vaccination(
    id: id,
    petId: petId,
    vaccineName: vaccineName,
    status: status,
    date: date,
    clinicName: clinicName,
    veterinarianName: veterinarianName,
    notes: notes,
    vetVisitId: vetVisitId,
    reminderSettings: reminderSettings,
  );

  static String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    id,
    petId,
    vaccineName,
    status,
    date,
    clinicName,
    veterinarianName,
    notes,
    vetVisitId,
    reminderSettings,
  ];
}
