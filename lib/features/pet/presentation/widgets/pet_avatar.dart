import 'package:flutter/material.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_image.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_species_icon.dart';

class PetAvatar extends StatelessWidget {
  final Pet pet;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const PetAvatar({
    super.key,
    required this.pet,
    this.size = 56,
    this.iconSize = 32,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: backgroundColor ?? colors.surfaceContainerHighest,
      child: Center(
        child: PetSpeciesIcon(
          species: pet.species,
          size: iconSize,
          color: foregroundColor ?? colors.onSurfaceVariant,
        ),
      ),
    );
    final imagePath = pet.imagePath;

    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: PetImage(
          imagePath: imagePath,
          size: size,
          builder: (photo) => photo ?? placeholder,
        ),
      ),
    );
  }
}
