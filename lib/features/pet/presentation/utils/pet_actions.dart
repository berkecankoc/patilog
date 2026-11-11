import 'package:flutter/material.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_cubit.dart';

Future<void> deletePetWithConfirmation(BuildContext context, Pet pet) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AppConfirmationDialog(
      title: AppLocalizations.of(context).deletePetTitle,
      message: AppLocalizations.of(context).deletePetMessage(pet.name),
      confirmLabel: AppLocalizations.of(context).deleteAction,
    ),
  );
  if (confirmed == true && context.mounted) {
    await context.read<PetCubit>().deletePet(pet);
  }
}
