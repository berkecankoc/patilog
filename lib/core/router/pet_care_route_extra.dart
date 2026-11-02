import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';

final class FeedingRouteExtra extends PetCareRouteExtra {
  final DateTime date;
  const FeedingRouteExtra({
    required super.petId,
    super.petName,
    required this.date,
  });
}

final class FeedingEntryFormExtra extends PetCareRouteExtra {
  final FeedingEntry? entry;
  const FeedingEntryFormExtra({
    required super.petId,
    super.petName,
    this.entry,
  });
}

final class FeedingPlanFormExtra extends PetCareRouteExtra {
  final FeedingPlan? plan;
  final FeedingPlan? template;
  final List<FeedingPlan>? plans;
  FeedingPlanFormExtra({
    required super.petId,
    super.petName,
    this.plan,
    this.template,
    List<FeedingPlan>? plans,
  }) : plans = plans == null ? null : List.unmodifiable(plans);
}

class PetCareRouteExtra {
  final String petId;
  final String? petName;

  const PetCareRouteExtra({required this.petId, this.petName});
}

final class MedicationFormExtra extends PetCareRouteExtra {
  final Medication? medication;
  final String? periodId;
  final bool newSchedule;
  const MedicationFormExtra({
    required super.petId,
    super.petName,
    this.medication,
    this.periodId,
    this.newSchedule = false,
  });
}

final class MedicationDetailExtra extends PetCareRouteExtra {
  final String medicationId;
  final DateTime doseDate;
  const MedicationDetailExtra({
    required super.petId,
    super.petName,
    required this.medicationId,
    required this.doseDate,
  });
}

final class WeightEntryFormExtra extends PetCareRouteExtra {
  final WeightEntry? entry;

  const WeightEntryFormExtra({required super.petId, super.petName, this.entry});
}

final class VetVisitFormExtra extends PetCareRouteExtra {
  final VetVisit? visit;

  const VetVisitFormExtra({required super.petId, super.petName, this.visit});
}

final class VaccinationFormExtra extends PetCareRouteExtra {
  final Vaccination? vaccination;
  final bool recordAdministration;

  const VaccinationFormExtra({
    required super.petId,
    super.petName,
    this.vaccination,
    this.recordAdministration = false,
  });
}
