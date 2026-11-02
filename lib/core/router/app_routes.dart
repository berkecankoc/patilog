abstract final class AppRoutes {
  static const settings = '/settings';
  static const notificationSettings = '$settings/notifications';
  static const pets = '/pets';
  static const allVetVisits = '/vet-visits';
  static const allVaccinations = '/vaccinations';
  static const allMedications = '/medications';
  static const allFeeding = '/feeding';
  static String feeding(String petId) => '${petDetail(petId)}/feeding';
  static String addEditFeedingEntry(String petId) => '${feeding(petId)}/form';
  static String addEditFeedingPlan(String petId) =>
      '${feeding(petId)}/plan/form';
  static String medications(String petId) => '${petDetail(petId)}/medications';
  static String addEditMedication(String petId) => '${medications(petId)}/form';
  static String medicationDetail(String petId, String medicationId) =>
      '${medications(petId)}/$medicationId';
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
