import 'package:flutter/material.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:patilog/features/pet/presentation/widgets/pet_avatar.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

/// Chooses from the retained directory without another pet lookup.
Future<Pet?> pickCarePet(
  BuildContext context,
  List<Pet> pets, {
  String? selectedPetId,
}) async {
  final selected = pets.where((pet) => pet.id == selectedPetId).firstOrNull;
  if (selected != null) return selected;
  if (pets.length == 1) return pets.single;
  if (pets.isEmpty) return null;
  return showModalBottomSheet<Pet>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).choosePet,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pets.length,
              itemBuilder: (_, index) {
                final pet = pets[index];
                return ListTile(
                  leading: PetAvatar(pet: pet, size: 40, iconSize: 24),
                  title: Text(pet.name),
                  subtitle: Text(
                    pet.speciesAndBreed(AppLocalizations.of(context)),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(pet),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
