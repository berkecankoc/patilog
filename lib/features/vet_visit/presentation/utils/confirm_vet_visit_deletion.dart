import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

Future<bool> confirmVetVisitDeletion(
  BuildContext context,
  VetVisit visit,
) async {
  final date = MaterialLocalizations.of(
    context,
  ).formatShortDate(visit.visitedOn);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AppConfirmationDialog(
      title: 'Delete visit?',
      message:
          'Remove “${visit.reason}” from $date? Linked medications and their dose records will be kept without this visit link. This cannot be undone.',
      confirmLabel: 'Delete',
    ),
  );
  return confirmed == true;
}
