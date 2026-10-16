import 'package:equatable/equatable.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

final class VetVisitModel extends Equatable {
  final String id;
  final String petId;
  final DateTime visitedOn;
  final String reason;
  final String? clinicName;
  final String? veterinarianName;
  final String? diagnosis;
  final String? notes;
  final int? costMinorUnits;
  final VetVisitCurrency? currency;

  const VetVisitModel({
    required this.id,
    required this.petId,
    required this.visitedOn,
    required this.reason,
    this.clinicName,
    this.veterinarianName,
    this.diagnosis,
    this.notes,
    this.costMinorUnits,
    this.currency,
  });

  factory VetVisitModel.fromJson(Map<String, dynamic> json) => VetVisitModel(
    id: json['id'] as String,
    petId: json['pet_id'] as String,
    visitedOn: DateTime.parse(json['visited_on'] as String),
    reason: json['reason'] as String,
    clinicName: json['clinic_name'] as String?,
    veterinarianName: json['veterinarian_name'] as String?,
    diagnosis: json['diagnosis'] as String?,
    notes: json['notes'] as String?,
    costMinorUnits: json['cost_minor_units'] as int?,
    currency: json['currency'] == null
        ? null
        : VetVisitCurrency.values.firstWhere(
            (currency) => currency.code == json['currency'],
          ),
  );

  factory VetVisitModel.fromEntity(VetVisit visit) => VetVisitModel(
    id: visit.id,
    petId: visit.petId,
    visitedOn: visit.visitedOn,
    reason: visit.reason,
    clinicName: visit.clinicName,
    veterinarianName: visit.veterinarianName,
    diagnosis: visit.diagnosis,
    notes: visit.notes,
    costMinorUnits: visit.costMinorUnits,
    currency: visit.currency,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pet_id': petId,
    // Persist calendar components, not an instant that can shift with time zones.
    'visited_on':
        '${visitedOn.year.toString().padLeft(4, '0')}-'
        '${visitedOn.month.toString().padLeft(2, '0')}-'
        '${visitedOn.day.toString().padLeft(2, '0')}',
    'reason': reason.trim(),
    'clinic_name': _optionalText(clinicName),
    'veterinarian_name': _optionalText(veterinarianName),
    'diagnosis': _optionalText(diagnosis),
    'notes': _optionalText(notes),
    'cost_minor_units': costMinorUnits,
    'currency': currency?.code,
  };

  VetVisit toEntity() => VetVisit(
    id: id,
    petId: petId,
    visitedOn: visitedOn,
    reason: reason,
    clinicName: clinicName,
    veterinarianName: veterinarianName,
    diagnosis: diagnosis,
    notes: notes,
    costMinorUnits: costMinorUnits,
    currency: currency,
  );

  static String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    id,
    petId,
    visitedOn,
    reason,
    clinicName,
    veterinarianName,
    diagnosis,
    notes,
    costMinorUnits,
    currency,
  ];
}
