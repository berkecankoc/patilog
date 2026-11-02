import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_form_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_form_state.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

/// Shared draft exit/save behavior for the record and plan forms.
class FeedingFormShell extends StatefulWidget {
  final String petId;
  final String? petName;
  final String title;
  final bool editing;
  final bool Function() hasChanges;
  final bool isPlan;
  final List<AppFormStep> steps;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;

  const FeedingFormShell({
    super.key,
    required this.petId,
    this.petName,
    required this.title,
    required this.editing,
    required this.hasChanges,
    this.isPlan = false,
    required this.steps,
    required this.onSubmit,
    required this.onChanged,
  });

  @override
  State<FeedingFormShell> createState() => _FeedingFormShellState();
}

class _FeedingFormShellState extends State<FeedingFormShell> {
  bool _allowPop = false;
  bool _confirming = false;
  bool get _busy =>
      context.read<FeedingFormCubit>().state.isSaving ||
      context.read<FeedingFormCubit>().state.isSaved;

  void _leave({bool? result}) {
    if (_allowPop) return;
    if (result == true) {
      PetCareChanges.recordChanged(context, widget.petId, PetCareTab.feeding);
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(result);
    });
  }

  Future<void> _exit() async {
    if (_busy || _confirming || _allowPop) return;
    if (!widget.hasChanges()) {
      _leave();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: AppLocalizations.of(context).discardChangesTitle,
        message: AppLocalizations.of(context).discardChangesMessage,
        cancelLabel: AppLocalizations.of(context).keepEditing,
        confirmLabel: AppLocalizations.of(context).discardChanges,
      ),
    );
    _confirming = false;
    if (mounted && discard == true) _leave();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<FeedingFormCubit, FeedingFormState>(
        listenWhen: (before, after) => !before.isSaved && after.isSaved,
        listener: (_, _) => _leave(result: true),
        builder: (context, state) {
          final strings = AppLocalizations.of(context);
          return AppMultiStepForm(
            title: PetCareTitle(title: widget.title, petName: widget.petName),
            toolbarHeight: PetCareTitle.toolbarHeight(context),
            steps: widget.steps,
            editing: widget.editing,
            isSaving: () => _busy,
            allowPop: _allowPop,
            canSubmit: !widget.editing || widget.hasChanges(),
            submitLabel: widget.editing ? strings.saveChanges : strings.save,
            saveError: state.saveFailure == null
                ? null
                : state.saveFailure is NotFoundFailure
                ? (widget.isPlan
                      ? strings.feedingPlanNotFound
                      : strings.feedingRecordNotFound)
                : (widget.isPlan
                      ? strings.feedingPlanSaveFailed
                      : strings.feedingSaveFailed),
            onSubmit: () {
              if (!_busy && !_confirming && !_allowPop) widget.onSubmit();
            },
            onExit: _exit,
            onChanged: widget.onChanged,
          );
        },
      );
}
