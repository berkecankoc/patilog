import 'package:equatable/equatable.dart';

final class MedicationSuggestions extends Equatable {
  final List<String> medicationNames;
  final List<String> clinicNames;
  final List<String> veterinarianNames;

  const MedicationSuggestions({
    required this.medicationNames,
    required this.clinicNames,
    required this.veterinarianNames,
  });

  @override
  List<Object?> get props => [medicationNames, clinicNames, veterinarianNames];
}
