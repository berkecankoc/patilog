import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

enum PetCareTab {
  profile,
  vetVisits,
  vaccinations,
  medications,
  feeding,
  weightHistory,
}

extension PetCareTabNavigation on PetCareTab {
  String label(AppLocalizations strings) => switch (this) {
    PetCareTab.profile => strings.profile,
    PetCareTab.vetVisits => strings.vetVisits,
    PetCareTab.vaccinations => strings.vaccinations,
    PetCareTab.medications => strings.medications,
    PetCareTab.feeding => strings.feeding,
    PetCareTab.weightHistory => strings.weightHistory,
  };

  String location(String petId) => switch (this) {
    PetCareTab.profile => AppRoutes.petDetail(petId),
    PetCareTab.vetVisits => AppRoutes.vetVisits(petId),
    PetCareTab.vaccinations => AppRoutes.vaccinations(petId),
    PetCareTab.medications => AppRoutes.medications(petId),
    PetCareTab.feeding => AppRoutes.feeding(petId),
    PetCareTab.weightHistory => AppRoutes.weightHistory(petId),
  };
}
