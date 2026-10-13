abstract final class AppRoutes {
  static const pets = '/pets';
  static const addEditPet = '$pets/form';
  static String petDetail(String petId) => '$pets/$petId';
  static String weightHistory(String petId) =>
      '${petDetail(petId)}/weight-history';
  static String addEditWeightEntry(String petId) =>
      '${weightHistory(petId)}/form';
}
