import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';

Future<bool> confirmVaccinationDeletion(
  BuildContext context,
  Vaccination vaccination, {
  String? petName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AppConfirmationDialog(
      title: AppLocalizations.of(context).deleteVaccinationTitle,
      message: petName != null
          ? AppLocalizations.of(context).deleteGlobalVaccinationMessage(petName)
          : AppLocalizations.of(context).deleteVaccinationMessage(
              vaccination.vaccineName,
              MaterialLocalizations.of(context)
                  .formatShortDate(vaccination.date),
            ),
      confirmLabel: AppLocalizations.of(context).deleteAction,
    ),
  );
  return confirmed == true;
}
