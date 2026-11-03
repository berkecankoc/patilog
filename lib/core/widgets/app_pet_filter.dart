import 'package:flutter/material.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

class AppPetFilter extends StatelessWidget {
  final List<Pet> pets;
  final String? selectedPetId;
  final ValueChanged<String?>? onChanged;

  const AppPetFilter({
    super.key,
    required this.pets,
    required this.selectedPetId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final selected = pets.any((pet) => pet.id == selectedPetId)
        ? selectedPetId
        : '';
    return DropdownButtonFormField<String>(
      key: ValueKey(selected),
      initialValue: selected,
      isExpanded: true,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(16),
      decoration: InputDecoration(labelText: strings.petStep),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(
            strings.allPets,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final pet in pets)
          DropdownMenuItem(
            value: pet.id,
            child: Text(
              '${pet.name} · ${pet.species.label(strings)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (value) => onChanged!(value == '' ? null : value),
    );
  }
}
