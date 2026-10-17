import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';

class PetCareRouteExtra {
  final String petId;
  final String? petName;

  const PetCareRouteExtra({required this.petId, this.petName});
}

final class WeightEntryFormExtra extends PetCareRouteExtra {
  final WeightEntry? entry;

  const WeightEntryFormExtra({required super.petId, super.petName, this.entry});
}

final class VetVisitFormExtra extends PetCareRouteExtra {
  final VetVisit? visit;

  const VetVisitFormExtra({required super.petId, super.petName, this.visit});
}
