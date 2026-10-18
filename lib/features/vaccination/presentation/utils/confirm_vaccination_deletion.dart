import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';

Future<bool> confirmVaccinationDeletion(
  BuildContext context,
  Vaccination vaccination,
) async {
  final date = MaterialLocalizations.of(
    context,
  ).formatShortDate(vaccination.date);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AppConfirmationDialog(
      title: 'Delete vaccination?',
      message:
          'Remove “${vaccination.vaccineName}” from $date? Any separately planned doses will remain. This cannot be undone.',
      confirmLabel: 'Delete',
    ),
  );
  return confirmed == true;
}
