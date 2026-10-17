import 'package:equatable/equatable.dart';

enum VaccinationStatus { planned, administered }

final class Vaccination extends Equatable {
  final String id;
  final String petId;
  final String vaccineName;
  final VaccinationStatus status;

  /// Planned or actual administration day, according to [status].
  /// Preserve its year/month/day without UTC conversion.
  final DateTime date;
  final String? clinicName;
  final String? veterinarianName;
  final String? notes;

  /// Optional visit belonging to the same pet; only for administered records.
  final String? vetVisitId;

  const Vaccination({
    required this.id,
    required this.petId,
    required this.vaccineName,
    required this.status,
    required this.date,
    this.clinicName,
    this.veterinarianName,
    this.notes,
    this.vetVisitId,
  });

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
  ];
}
