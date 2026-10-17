import 'package:equatable/equatable.dart';

final class VaccinationSuggestions extends Equatable {
  final List<String> vaccineNames;
  final List<String> clinicNames;
  final List<String> veterinarianNames;

  const VaccinationSuggestions({
    required this.vaccineNames,
    required this.clinicNames,
    required this.veterinarianNames,
  });

  @override
  List<Object?> get props => [vaccineNames, clinicNames, veterinarianNames];
}
