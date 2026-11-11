import 'package:flutter/material.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';

class PetSpeciesIcon extends StatelessWidget {
  final PetSpecies species;
  final Color color;
  final double size;

  const PetSpeciesIcon({
    super.key,
    required this.species,
    required this.color,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final asset = switch (species) {
      PetSpecies.cat => 'assets/icons/pets/cat.png',
      PetSpecies.dog => 'assets/icons/pets/dog.png',
      PetSpecies.bird => 'assets/icons/pets/bird.png',
      PetSpecies.other => 'assets/icons/pets/other.png',
    };
    return Image.asset(
      asset,
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      excludeFromSemantics: true,
    );
  }
}
