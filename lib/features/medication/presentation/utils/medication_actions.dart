import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';
import 'package:patilog/features/medication/domain/utils/medication_calendar.dart';

Future<void> performMedicationAction(
  BuildContext context,
  MedicationCubit cubit,
  MedicationAction action,
) async {
  final state = cubit.state;
  if (state is! MedicationsLoaded || state.pendingAction != null) return;
  final medication = state.medications
      .where((item) => item.id == action.medicationId)
      .firstOrNull;
  if (medication == null) return;
  if (action is SaveMedicationDoseAction) return cubit.performAction(action);
  var resumes = false;
  if (action is DeleteMedicationPeriodAction) {
    final index = medication.periods.indexWhere(
      (period) => period.id == action.periodId,
    );
    if (index < 1) return;
    final previous = medication.periods[index - 1];
    resumes =
        previous.endDate == null ||
        calendarDayNumber(previous.endDate!) >=
            calendarDayNumber(medication.periods[index].startDate);
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AppConfirmationDialog(
      title: action is DeleteMedicationAction
          ? AppLocalizations.of(context).deleteMedicationTitle
          : action is DeleteMedicationPeriodAction
          ? AppLocalizations.of(context).cancelScheduledChangesTitle
          : AppLocalizations.of(context).clearDoseRecordTitle,
      message: action is DeleteMedicationAction
          ? AppLocalizations.of(
              context,
            ).deleteMedicationMessage(medication.name)
          : action is DeleteMedicationPeriodAction
          ? resumes
                ? AppLocalizations.of(context).cancelScheduleResumeMessage
                : AppLocalizations.of(context).cancelScheduleKeepHistoryMessage
          : AppLocalizations.of(context).clearDoseRecordMessage,
      confirmLabel: action is DeleteMedicationAction
          ? AppLocalizations.of(context).deleteAction
          : action is ClearMedicationDoseAction
          ? AppLocalizations.of(context).clearRecord
          : AppLocalizations.of(context).cancelChanges,
    ),
  );
  if (confirmed == true && context.mounted && !cubit.isClosed) {
    await cubit.performAction(action);
  }
}
