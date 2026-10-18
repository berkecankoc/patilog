abstract final class AppRoutes {
  static const pets = '/pets';
  static const addEditPet = '$pets/form';
  static String petDetail(String petId) => '$pets/$petId';
  static String weightHistory(String petId) =>
      '${petDetail(petId)}/weight-history';
  static String addEditWeightEntry(String petId) =>
      '${weightHistory(petId)}/form';
  static String vetVisits(String petId) => '${petDetail(petId)}/vet-visits';
  static String addEditVetVisit(String petId) => '${vetVisits(petId)}/form';
  static String vetVisitDetail(String petId, String visitId) =>
      '${vetVisits(petId)}/$visitId';
  static String vaccinations(String petId) =>
      '${petDetail(petId)}/vaccinations';
  static String addEditVaccination(String petId) =>
      '${vaccinations(petId)}/form';
  static String vaccinationDetail(String petId, String vaccinationId) =>
      '${vaccinations(petId)}/$vaccinationId';
}
