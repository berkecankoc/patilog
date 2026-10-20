import 'package:equatable/equatable.dart';
import 'package:petlytics/features/medication/data/models/medication_period_model.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';

final class MedicationModel extends Equatable {
  final String id;
  final String petId;
  final String name;
  final List<MedicationPeriodModel> periods;

  MedicationModel({
    required this.id,
    required this.petId,
    required this.name,
    required List<MedicationPeriodModel> periods,
  }) : periods = List.unmodifiable(periods);

  factory MedicationModel.fromJson(
    Map<String, dynamic> json, {
    required List<MedicationPeriodModel> periods,
  }) => MedicationModel(
    id: json['id'] as String,
    petId: json['pet_id'] as String,
    name: json['name'] as String,
    periods: periods,
  );

  factory MedicationModel.fromEntity(Medication medication) => MedicationModel(
    id: medication.id,
    petId: medication.petId,
    name: medication.name,
    periods: medication.periods.map(MedicationPeriodModel.fromEntity).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pet_id': petId,
    'name': name.trim(),
  };

  Medication toEntity() => Medication(
    id: id,
    petId: petId,
    name: name,
    periods: periods.map((period) => period.toEntity()).toList(),
  );

  @override
  List<Object?> get props => [id, petId, name, periods];
}
