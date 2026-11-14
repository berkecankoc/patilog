import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

extension PetSpeciesLabel on PetSpecies {
  String label(AppLocalizations strings) => switch (this) {
    PetSpecies.dog => strings.speciesDog,
    PetSpecies.cat => strings.speciesCat,
    PetSpecies.bird => strings.speciesBird,
    PetSpecies.other => strings.speciesOther,
  };
}

extension PetSexLabel on PetSex {
  String label(AppLocalizations strings) => switch (this) {
    PetSex.male => strings.sexMale,
    PetSex.female => strings.sexFemale,
    PetSex.unknown => strings.unknown,
  };
}

extension ReproductiveStatusLabel on ReproductiveStatus {
  String label(AppLocalizations strings) => switch (this) {
    ReproductiveStatus.intact => strings.reproductiveIntact,
    ReproductiveStatus.sterilized => strings.reproductiveSterilized,
    ReproductiveStatus.unknown => strings.unknown,
  };
}

extension PetDisplay on Pet {
  String speciesLabel(AppLocalizations strings) =>
      customSpecies ?? species.label(strings);

  String speciesAndBreed(AppLocalizations strings) => [
    speciesLabel(strings),
    if (breed?.trim().isNotEmpty ?? false) breed!,
  ].join(' · ');
}
