import 'package:petlytics/core/router/app_routes.dart';

enum PetCareTab { profile, vetVisits, vaccinations, medications, weightHistory }

extension PetCareTabNavigation on PetCareTab {
  String get label => switch (this) {
    PetCareTab.profile => 'Profile',
    PetCareTab.vetVisits => 'Vet visits',
    PetCareTab.vaccinations => 'Vaccinations',
    PetCareTab.medications => 'Medications',
    PetCareTab.weightHistory => 'Weight history',
  };

  String location(String petId) => switch (this) {
    PetCareTab.profile => AppRoutes.petDetail(petId),
    PetCareTab.vetVisits => AppRoutes.vetVisits(petId),
    PetCareTab.vaccinations => AppRoutes.vaccinations(petId),
    PetCareTab.medications => AppRoutes.medications(petId),
    PetCareTab.weightHistory => AppRoutes.weightHistory(petId),
  };
}
