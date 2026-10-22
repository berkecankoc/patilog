import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';

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
  final String title;
  final String message;
  switch (action) {
    case DeleteMedicationAction():
      title = 'Delete medication?';
      message =
          'Delete ${medication.name}, all its schedules and dose records?';
    case DeleteMedicationPeriodAction():
      final index = medication.periods.indexWhere(
        (period) => period.id == action.periodId,
      );
      if (index < 1) return;
      final previous = medication.periods[index - 1];
      final resumes =
          previous.endDate == null ||
          calendarDayNumber(previous.endDate!) >=
              calendarDayNumber(medication.periods[index].startDate);
      title = 'Cancel scheduled changes?';
      message =
          'Remove these unstarted changes?${resumes ? ' The previous schedule may continue until its end date or the next change.' : ' Earlier dose records will be kept.'}';
    case ClearMedicationDoseAction():
      title = 'Clear dose record?';
      message =
          'This dose will return to No record. The scheduled dose stays in the plan.';
    case SaveMedicationDoseAction():
      return cubit.performAction(action);
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AppConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: action is DeleteMedicationAction
          ? 'Delete'
          : action is ClearMedicationDoseAction
          ? 'Clear record'
          : 'Cancel changes',
    ),
  );
  if (confirmed == true && context.mounted && !cubit.isClosed) {
    await cubit.performAction(action);
  }
}
