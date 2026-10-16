import 'package:equatable/equatable.dart';

final class VetVisitSuggestions extends Equatable {
  final List<String> clinicNames;
  final List<String> veterinarianNames;

  const VetVisitSuggestions({
    required this.clinicNames,
    required this.veterinarianNames,
  });

  @override
  List<Object?> get props => [clinicNames, veterinarianNames];
}
