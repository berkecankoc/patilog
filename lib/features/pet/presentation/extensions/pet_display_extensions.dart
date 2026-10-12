import 'package:petlytics/features/pet/domain/entities/pet.dart';

extension PetSpeciesLabel on PetSpecies {
  String get label => switch (this) {
    PetSpecies.dog => 'Dog',
    PetSpecies.cat => 'Cat',
    PetSpecies.bird => 'Bird',
    PetSpecies.other => 'Other',
  };
}

extension PetSexLabel on PetSex {
  String get label => switch (this) {
    PetSex.male => 'Male',
    PetSex.female => 'Female',
    PetSex.unknown => 'Unknown',
  };
}

extension ReproductiveStatusLabel on ReproductiveStatus {
  String get label => switch (this) {
    ReproductiveStatus.intact => 'Intact',
    ReproductiveStatus.sterilized => 'Sterilized',
    ReproductiveStatus.unknown => 'Unknown',
  };
}

extension PetDisplay on Pet {
  String get speciesAndBreed => [
    species.label,
    if (breed?.trim().isNotEmpty ?? false) breed!,
  ].join(' · ');
}
