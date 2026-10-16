import 'package:equatable/equatable.dart';

enum VetVisitCurrency {
  turkishLira('TRY'),
  usDollar('USD'),
  euro('EUR');

  final String code;

  const VetVisitCurrency(this.code);
}

final class VetVisit extends Equatable {
  final String id;
  final String petId;

  /// Calendar date only; preserve its year/month/day without UTC conversion.
  final DateTime visitedOn;
  final String reason;
  final String? clinicName;
  final String? veterinarianName;
  final String? diagnosis;
  final String? notes;

  /// Non-negative amount in kurus/cents; null means no cost was recorded.
  /// For example, 125050 with TRY represents 1250.50 Turkish lira.
  final int? costMinorUnits;

  /// Present exactly when [costMinorUnits] is present, including a zero cost.
  final VetVisitCurrency? currency;

  const VetVisit({
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
