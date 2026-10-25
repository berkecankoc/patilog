import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';

Future<void> deletePetWithConfirmation(BuildContext context, Pet pet) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AppConfirmationDialog(
      title: 'Delete pet?',
      message:
          '${pet.name}’s profile, photo, weight history, vet visits, vaccinations, medications and dose records will be removed. This cannot be undone.',
      confirmLabel: 'Delete',
    ),
  );
  if (confirmed == true && context.mounted) {
    await context.read<PetCubit>().deletePet(pet);
  }
}
