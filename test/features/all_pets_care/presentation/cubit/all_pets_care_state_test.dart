import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';

void main() {
  const pet = Pet(
    id: 'a',
    name: 'Toby',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  test('the shared directory owns an immutable snapshot keyed by identity', () {
    final source = [pet];
    final state = AllPetsCareState(pets: CareRecords(records: source));
    source.clear();
    expect(state.pets.records, [pet]);
    expect(state.petsById['a'], pet);
    expect(() => state.pets.records.clear(), throwsUnsupportedError);
    expect(() => state.petsById.clear(), throwsUnsupportedError);
  });
  test('changing destinations and load errors preserves the directory', () {
    final state = AllPetsCareState(
      pets: CareRecords(records: [pet], hasLoaded: true),
    );
    final failed = state.copyWith(
      activeSection: AllPetsCareSection.vaccinations,
      pets: state.pets.copyWith(error: 'Try again'),
    );
    expect(failed.pets.records, [pet]);
    expect(failed.pets.hasLoaded, isTrue);
    expect(failed.pets.copyWith(clearError: true).error, isNull);
    expect(failed.activeSection, AllPetsCareSection.vaccinations);
  });
}
