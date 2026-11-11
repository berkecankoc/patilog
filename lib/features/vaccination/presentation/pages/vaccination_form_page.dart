import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:patilog/core/widgets/app_multi_step_form.dart';
import 'package:patilog/core/widgets/app_detail_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/core/widgets/app_date_field.dart';
import 'package:patilog/core/widgets/app_gap.dart';
import 'package:patilog/core/widgets/app_suggestion_field.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';
import 'package:patilog/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_form_state.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';

class VaccinationFormPage extends StatefulWidget {
  final String petId;
  final String? petName;
  final Vaccination? vaccination;
  final bool recordAdministration;

  const VaccinationFormPage({
    super.key,
    required this.petId,
    this.petName,
    this.vaccination,
    this.recordAdministration = false,
  });

  @override
  State<VaccinationFormPage> createState() => _VaccinationFormPageState();
}

class _VaccinationFormPageState extends State<VaccinationFormPage> {
  final _vaccine = TextEditingController();
  final _clinic = TextEditingController();
  final _veterinarian = TextEditingController();
  final _notes = TextEditingController();
  late final Map<TextEditingController, String> _initialText;
  late final DateTime _initialDate;
  late final VaccinationStatus _initialStatus;
  late DateTime _date;
  late VaccinationStatus _status;
  String? _visitId;
  DateTime? _nextDoseDate;
  bool _allowPop = false;
  bool _confirmingDiscard = false;

  bool get _canPlanNextDose =>
      _status == VaccinationStatus.administered &&
      (widget.vaccination == null ||
          widget.vaccination!.status == VaccinationStatus.planned);

  bool get _hasChanges =>
      _initialText.entries.any((entry) => entry.key.text != entry.value) ||
      !DateUtils.isSameDay(_date, _initialDate) ||
      _status != _initialStatus ||
      _visitId != widget.vaccination?.vetVisitId ||
      _nextDoseDate != null;

  @override
  void initState() {
    super.initState();
    final vaccination = widget.vaccination;
    _initialDate = DateUtils.dateOnly(vaccination?.date ?? DateTime.now());
    _initialStatus = vaccination?.status ?? VaccinationStatus.administered;
    _status = widget.recordAdministration
        ? VaccinationStatus.administered
        : _initialStatus;
    _date = widget.recordAdministration
        ? DateUtils.dateOnly(DateTime.now())
        : _initialDate;
    _visitId = vaccination?.vetVisitId;
    _initialText = {
      _vaccine: vaccination?.vaccineName ?? '',
      _clinic: vaccination?.clinicName ?? '',
      _veterinarian: vaccination?.veterinarianName ?? '',
      _notes: vaccination?.notes ?? '',
    };
    for (final entry in _initialText.entries) {
      entry.key.text = entry.value;
    }
    if (_status == VaccinationStatus.administered) {
      context.read<VaccinationFormCubit>().loadVisits(widget.petId);
    }
  }

  @override
  void dispose() {
    for (final controller in _initialText.keys) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changeStatus(VaccinationStatus? status) {
    if (status == null || status == _status) return;
    setState(() {
      _status = status;
      if (status == VaccinationStatus.planned) {
        _visitId = null;
        _nextDoseDate = null;
        final today = DateUtils.dateOnly(DateTime.now());
        if (_date.isBefore(today)) _date = today;
      } else {
        _date = DateUtils.dateOnly(DateTime.now());
      }
    });
    if (status == VaccinationStatus.administered) {
      context.read<VaccinationFormCubit>().loadVisits(widget.petId);
    }
  }

  void _selectVisit(String? id, List<VetVisit> visits) {
    setState(() {
      _visitId = id;
      if (id == null) return;
      final visit = visits.firstWhere((visit) => visit.id == id);
      _date = DateUtils.dateOnly(visit.visitedOn);
      if (_clinic.text.trim().isEmpty) _clinic.text = visit.clinicName ?? '';
      if (_veterinarian.text.trim().isEmpty) {
        _veterinarian.text = visit.veterinarianName ?? '';
      }
    });
    context.read<VaccinationFormCubit>().loadSuggestions(
      clinicName: _clinic.text,
    );
  }

  void _submit() {
    final cubit = context.read<VaccinationFormCubit>();
    if (_allowPop ||
        _confirmingDiscard ||
        cubit.state.isSaving ||
        cubit.state.isSaved) {
      return;
    }
    if (widget.vaccination != null && !_hasChanges) return;
    FocusScope.of(context).unfocus();
    cubit.saveVaccination(
      SaveVaccinationParams(
        petId: widget.petId,
        vaccinationId: widget.vaccination?.id,
        vaccineName: _vaccine.text,
        status: _status,
        date: _date,
        clinicName: _clinic.text,
        veterinarianName: _veterinarian.text,
        notes: _notes.text,
        vetVisitId: _status == VaccinationStatus.administered ? _visitId : null,
        nextDoseDate: _canPlanNextDose ? _nextDoseDate : null,
      ),
    );
  }

  void _leave({bool? result}) {
    if (_allowPop) return;
    if (result == true) {
      PetCareChanges.recordChanged(
        context,
        widget.petId,
        PetCareTab.vaccinations,
      );
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pop(result);
    });
  }

  Future<void> _requestExit() async {
    if (_allowPop ||
        _confirmingDiscard ||
        context.read<VaccinationFormCubit>().state.isSaving) {
      return;
    }
    if (!_hasChanges) {
      _leave();
      return;
    }
    _confirmingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: AppLocalizations.of(context).discardChangesTitle,
        message: AppLocalizations.of(context).discardChangesMessage,
        cancelLabel: AppLocalizations.of(context).keepEditing,
        confirmLabel: AppLocalizations.of(context).discardChanges,
      ),
    );
    _confirmingDiscard = false;
    if (discard == true && mounted) _leave();
  }

  Widget _error(String message) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  List<Widget> _visitOptions(VaccinationFormState state) => [
    DropdownButtonFormField<String>(
      key: ValueKey(_visitId),
      initialValue: _visitId,
      isExpanded: true,
      itemHeight: null,
      menuMaxHeight: MediaQuery.sizeOf(context).height * 0.5,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).vetVisitOptional,
      ),
      hint: Text(
        AppLocalizations.of(context).noLinkedVisit,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      selectedItemBuilder: (context) => [
        Text(
          AppLocalizations.of(context).noLinkedVisit,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_visitId != null &&
            !state.visits.any((visit) => visit.id == _visitId))
          Text(
            AppLocalizations.of(context).linkedVisitUnavailable,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        for (final visit in state.visits)
          Text(
            '${MaterialLocalizations.of(context).formatShortDate(visit.visitedOn)} · ${visit.reason}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(AppLocalizations.of(context).noLinkedVisit),
        ),
        if (_visitId != null &&
            !state.visits.any((visit) => visit.id == _visitId))
          DropdownMenuItem(
            value: _visitId,
            enabled: false,
            child: Text(AppLocalizations.of(context).linkedVisitUnavailable),
          ),
        for (final visit in state.visits)
          DropdownMenuItem(
            value: visit.id,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                '${MaterialLocalizations.of(context).formatShortDate(visit.visitedOn)} · ${visit.reason}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
      onChanged: (value) => _selectVisit(value, state.visits),
    ),
    if (state.isLoadingVisits) ...[
      VerticalGap.sm,
      LinearProgressIndicator(
        semanticsLabel: AppLocalizations.of(context).loadingVisits,
      ),
    ],
    if (state.visitsError != null) ...[
      VerticalGap.sm,
      _error(AppLocalizations.of(context).visitsLoadFailed),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            alignment: AlignmentDirectional.centerStart,
          ),
          onPressed: () =>
              context.read<VaccinationFormCubit>().loadVisits(widget.petId),
          child: Text(AppLocalizations.of(context).retryVisits),
        ),
      ),
    ],
    VerticalGap.md,
  ];

  Widget _vaccinationDetails(VaccinationFormState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSuggestionField(
        key: const Key('vaccination-name'),
        label: AppLocalizations.of(context).vaccineName,
        controller: _vaccine,
        suggestions: state.suggestions.vaccineNames,
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) {
            return AppLocalizations.of(context).vaccineNameRequired;
          }
          return text.characters.length > 50
              ? AppLocalizations.of(context).vaccineNameLimit
              : null;
        },
      ),
      VerticalGap.md,
      DropdownButtonFormField<VaccinationStatus>(
        initialValue: _status,
        isExpanded: true,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).status,
        ),
        items: [
          DropdownMenuItem(
            value: VaccinationStatus.administered,
            child: Text(AppLocalizations.of(context).administered),
          ),
          DropdownMenuItem(
            value: VaccinationStatus.planned,
            child: Text(AppLocalizations.of(context).planned),
          ),
        ],
        onChanged: _changeStatus,
      ),
      VerticalGap.md,
      FormField<DateTime>(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (_) {
          final today = DateUtils.dateOnly(DateTime.now());
          if (_status == VaccinationStatus.planned && _date.isBefore(today)) {
            return AppLocalizations.of(context).dateTodayOrFuture;
          }
          if (_status == VaccinationStatus.administered &&
              _date.isAfter(today)) {
            return AppLocalizations.of(context).dateTodayOrPast;
          }
          return null;
        },
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDateField(
              key: const Key('vaccination-date'),
              labelText: _status == VaccinationStatus.planned
                  ? AppLocalizations.of(context).plannedDate
                  : AppLocalizations.of(context).administrationDate,
              value: _date,
              readOnly: _visitId != null,
              firstDate: _status == VaccinationStatus.planned
                  ? DateUtils.dateOnly(DateTime.now())
                  : DateTime(1900),
              lastDate: _status == VaccinationStatus.planned
                  ? DateTime(2100, 12, 31)
                  : DateTime.now(),
              errorText: field.errorText,
              onChanged: (date) {
                if (date == null) return;
                setState(() => _date = date);
                field.didChange(date);
              },
            ),
            if (_visitId != null) ...[
              VerticalGap.xs,
              Text(
                AppLocalizations.of(context).dateFromLinkedVisit,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      VerticalGap.xl,
    ],
  );

  Widget _review(VaccinationFormState state, ValueChanged<int> edit) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AppLocalizations.of(context).reviewVaccination,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      VerticalGap.md,
      AppFormReviewSection(
        title: AppLocalizations.of(context).vaccineDetails,
        icon: Icons.vaccines_outlined,
        onEdit: () => edit(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailField(
              label: AppLocalizations.of(context).vaccineName,
              value: _vaccine.text,
            ),
            VerticalGap.md,
            AppDetailField(
              label: AppLocalizations.of(context).status,
              value: _status == VaccinationStatus.planned
                  ? AppLocalizations.of(context).planned
                  : AppLocalizations.of(context).administered,
            ),
            VerticalGap.md,
            AppDetailField(
              label: _status == VaccinationStatus.planned
                  ? AppLocalizations.of(context).plannedDate
                  : AppLocalizations.of(context).administrationDate,
              value: MaterialLocalizations.of(context).formatShortDate(_date),
            ),
            if (_visitId != null) ...[
              VerticalGap.sm,
              Text(AppLocalizations.of(context).dateFromLinkedVisit),
            ],
          ],
        ),
      ),
      VerticalGap.md,
      AppFormOptionalSection(
        title: AppLocalizations.of(context).clinicalOptional,
        icon: Icons.local_hospital_outlined,
        initiallyExpanded: widget.vaccination != null || _visitId != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status == VaccinationStatus.administered)
              ..._visitOptions(state),
            AppSuggestionField(
              key: const Key('vaccination-clinic'),
              label: AppLocalizations.of(context).clinicOptional,
              loading: state.isLoadingSuggestions,
              controller: _clinic,
              suggestions: state.suggestions.clinicNames,
              onChanged: (value) => context
                  .read<VaccinationFormCubit>()
                  .loadSuggestions(clinicName: value),
            ),
            VerticalGap.md,
            AppSuggestionField(
              key: const Key('vaccination-veterinarian'),
              label: AppLocalizations.of(context).veterinarianOptional,
              controller: _veterinarian,
              suggestions: state.suggestions.veterinarianNames,
            ),
            if (state.suggestionsError != null) ...[
              VerticalGap.sm,
              _error(AppLocalizations.of(context).suggestionsLoadFailed),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  onPressed: () => context
                      .read<VaccinationFormCubit>()
                      .loadSuggestions(clinicName: _clinic.text),
                  child: Text(AppLocalizations.of(context).retrySuggestions),
                ),
              ),
            ],
            VerticalGap.xl,
          ],
        ),
      ),
      VerticalGap.md,
      AppFormOptionalSection(
        title: AppLocalizations.of(context).notesOptional,
        icon: Icons.notes_outlined,
        initiallyExpanded: widget.vaccination?.notes != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('vaccination-notes'),
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).notesOptional,
              ),
              minLines: 1,
              maxLines: 4,
              validator: (value) => (value?.characters.length ?? 0) > 200
                  ? AppLocalizations.of(context).notesLimit200
                  : null,
            ),
          ],
        ),
      ),
      if (_canPlanNextDose) ...[
        VerticalGap.md,
        AppFormOptionalSection(
          title: AppLocalizations.of(context).nextDoseOptional,
          icon: Icons.event_repeat_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppLocalizations.of(context).separateNextDoseHint),
              VerticalGap.md,
              FormField<DateTime>(
                validator: (_) {
                  if (_nextDoseDate == null) return null;
                  if (!_nextDoseDate!.isAfter(_date)) {
                    return AppLocalizations.of(context).dateAfterAdministration;
                  }
                  return _nextDoseDate!.isBefore(
                        DateUtils.dateOnly(DateTime.now()),
                      )
                      ? AppLocalizations.of(context).dateTodayOrFuture
                      : null;
                },
                builder: (field) => AppDateField(
                  key: const Key('vaccination-next-date'),
                  labelText: AppLocalizations.of(context).nextDoseDateOptional,
                  value: _nextDoseDate,
                  firstDate: _nextDoseFirstDate,
                  lastDate: DateTime(2100, 12, 31),
                  clearable: true,
                  errorText: field.errorText,
                  onChanged: (date) {
                    setState(() {
                      _nextDoseDate = date;
                    });
                    field.didChange(date);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
      VerticalGap.md,
      Text(
        AppLocalizations.of(context).remindersSettingsGuidance,
        key: const Key('vaccination-reminder-guidance'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );

  DateTime get _nextDoseFirstDate {
    final afterAdministration = DateTime(
      _date.year,
      _date.month,
      _date.day + 1,
    );
    final today = DateUtils.dateOnly(DateTime.now());
    return afterAdministration.isAfter(today) ? afterAdministration : today;
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<VaccinationFormCubit, VaccinationFormState>(
        listenWhen: (previous, current) =>
            previous.isSaved != current.isSaved ||
            previous.saveError != current.saveError ||
            (previous.isLoadingVisits && !current.isLoadingVisits),
        listener: (context, state) {
          if (_visitId != null && !state.isSaving && !state.isSaved) {
            for (final visit in state.visits) {
              if (visit.id == _visitId &&
                  visit.petId == widget.petId &&
                  !DateUtils.isSameDay(_date, visit.visitedOn)) {
                setState(() => _date = DateUtils.dateOnly(visit.visitedOn));
                break;
              }
            }
          }
          if (state.isSaved) _leave(result: true);
        },
        builder: (context, state) => AppMultiStepForm(
          title: PetCareTitle(
            title: widget.recordAdministration
                ? AppLocalizations.of(context).recordAdministrationTitle
                : widget.vaccination == null
                ? AppLocalizations.of(context).addVaccination
                : AppLocalizations.of(context).editVaccination,
            petName: widget.petName,
          ),
          toolbarHeight: PetCareTitle.toolbarHeight(context),
          editing: widget.vaccination != null,
          isSaving: () {
            final current = context.read<VaccinationFormCubit>().state;
            return current.isSaving || current.isSaved;
          },
          allowPop: _allowPop,
          canSubmit: widget.vaccination == null || _hasChanges,
          submitLabel: widget.vaccination == null
              ? AppLocalizations.of(context).addVaccination
              : AppLocalizations.of(context).saveChanges,
          saveError: state.saveError == null
              ? null
              : widget.vaccination == null
              ? AppLocalizations.of(context).vaccinationCreateFailed
              : AppLocalizations.of(context).vaccinationUpdateFailed,
          onSubmit: _submit,
          onExit: _requestExit,
          onChanged: () => setState(() {}),
          steps: [
            AppFormStep(
              title: AppLocalizations.of(context).vaccination,
              builder: (_, _) => _vaccinationDetails(state),
            ),
            AppFormStep(
              title: AppLocalizations.of(context).review,
              builder: (_, edit) => _review(state, edit),
            ),
          ],
        ),
      );
}
