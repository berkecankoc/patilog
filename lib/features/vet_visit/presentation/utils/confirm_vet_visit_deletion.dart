import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

Future<bool> confirmVetVisitDeletion(
  BuildContext context,
  VetVisit visit, {
  String? petName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AppConfirmationDialog(
      title: AppLocalizations.of(context).deleteVisitTitle,
      message: petName != null
          ? AppLocalizations.of(context).deleteGlobalVisitMessage(petName)
          : AppLocalizations.of(context).deleteVisitMessage(
              visit.reason,
              MaterialLocalizations.of(context)
                  .formatShortDate(visit.visitedOn),
            ),
      confirmLabel: AppLocalizations.of(context).deleteAction,
    ),
  );
  return confirmed == true;
}
