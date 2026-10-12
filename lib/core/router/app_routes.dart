abstract final class AppRoutes {
  static const pets = '/pets';
  static const addEditPet = '$pets/form';
  static String petDetail(String petId) => '$pets/$petId';
}
