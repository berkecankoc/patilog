import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';
import 'package:petlytics/core/widgets/app_detail_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_suggestion_field.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_state.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

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
      builder: (_) => const AppConfirmationDialog(
        title: 'Discard changes?',
        message: 'Your changes have not been saved. Leave without saving?',
        cancelLabel: 'Keep editing',
        confirmLabel: 'Discard changes',
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
      decoration: const InputDecoration(labelText: 'Vet visit (optional)'),
      hint: const Text(
        'No linked visit',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      selectedItemBuilder: (context) => [
        const Text(
          'No linked visit',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_visitId != null &&
            !state.visits.any((visit) => visit.id == _visitId))
          const Text(
            'Linked visit unavailable',
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
        const DropdownMenuItem(value: null, child: Text('No linked visit')),
        if (_visitId != null &&
            !state.visits.any((visit) => visit.id == _visitId))
          DropdownMenuItem(
            value: _visitId,
            enabled: false,
            child: const Text('Linked visit unavailable'),
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
      const LinearProgressIndicator(semanticsLabel: 'Loading visits'),
    ],
    if (state.visitsError != null) ...[
      VerticalGap.sm,
      _error(state.visitsError!),
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
          child: const Text('Retry visits'),
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
        label: 'Vaccine name',
        controller: _vaccine,
        suggestions: state.suggestions.vaccineNames,
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Enter a vaccine name';
          return text.characters.length > 50
              ? 'Keep vaccine name within 50 characters'
              : null;
        },
      ),
      VerticalGap.md,
      DropdownButtonFormField<VaccinationStatus>(
        initialValue: _status,
        isExpanded: true,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        decoration: const InputDecoration(labelText: 'Status'),
        items: const [
          DropdownMenuItem(
            value: VaccinationStatus.administered,
            child: Text('Administered'),
          ),
          DropdownMenuItem(
            value: VaccinationStatus.planned,
            child: Text('Planned'),
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
            return 'Choose today or a future date';
          }
          if (_status == VaccinationStatus.administered &&
              _date.isAfter(today)) {
            return 'Choose today or an earlier date';
          }
          return null;
        },
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDateField(
              key: const Key('vaccination-date'),
              labelText: _status == VaccinationStatus.planned
                  ? 'Planned date'
                  : 'Administration date',
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
                'Date from linked vet visit',
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
      Text('Review vaccination', style: Theme.of(context).textTheme.titleLarge),
      VerticalGap.md,
      AppFormReviewSection(
        title: 'Vaccine details',
        icon: Icons.vaccines_outlined,
        onEdit: () => edit(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailField(label: 'Vaccine name', value: _vaccine.text),
            VerticalGap.md,
            AppDetailField(
              label: 'Status',
              value: _status == VaccinationStatus.planned
                  ? 'Planned'
                  : 'Administered',
            ),
            VerticalGap.md,
            AppDetailField(
              label: _status == VaccinationStatus.planned
                  ? 'Planned date'
                  : 'Administration date',
              value: MaterialLocalizations.of(context).formatShortDate(_date),
            ),
            if (_visitId != null) ...[
              VerticalGap.sm,
              const Text('Date from linked vet visit'),
            ],
          ],
        ),
      ),
      VerticalGap.md,
      AppFormOptionalSection(
        title: 'Clinic & veterinarian (optional)',
        icon: Icons.local_hospital_outlined,
        initiallyExpanded: widget.vaccination != null || _visitId != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status == VaccinationStatus.administered)
              ..._visitOptions(state),
            AppSuggestionField(
              key: const Key('vaccination-clinic'),
              label: 'Clinic (optional)',
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
              label: 'Veterinarian (optional)',
              controller: _veterinarian,
              suggestions: state.suggestions.veterinarianNames,
            ),
            if (state.suggestionsError != null) ...[
              VerticalGap.sm,
              _error(state.suggestionsError!),
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
                  child: const Text('Retry suggestions'),
                ),
              ),
            ],
            VerticalGap.xl,
          ],
        ),
      ),
      VerticalGap.md,
      AppFormOptionalSection(
        title: 'Notes (optional)',
        icon: Icons.notes_outlined,
        initiallyExpanded: widget.vaccination?.notes != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('vaccination-notes'),
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              minLines: 1,
              maxLines: 4,
              validator: (value) => (value?.characters.length ?? 0) > 200
                  ? 'Keep notes within 200 characters'
                  : null,
            ),
          ],
        ),
      ),
      if (_canPlanNextDose) ...[
        VerticalGap.md,
        AppFormOptionalSection(
          title: 'Next dose (optional)',
          icon: Icons.event_repeat_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Optionally create a separate plan for the next dose.',
              ),
              VerticalGap.md,
              FormField<DateTime>(
                validator: (_) {
                  if (_nextDoseDate == null) return null;
                  if (!_nextDoseDate!.isAfter(_date)) {
                    return 'Choose a date after the administration date';
                  }
                  return _nextDoseDate!.isBefore(
                        DateUtils.dateOnly(DateTime.now()),
                      )
                      ? 'Choose today or a future date'
                      : null;
                },
                builder: (field) => AppDateField(
                  key: const Key('vaccination-next-date'),
                  labelText: 'Next dose date (optional)',
                  value: _nextDoseDate,
                  firstDate: _nextDoseFirstDate,
                  lastDate: DateTime(2100, 12, 31),
                  clearable: true,
                  errorText: field.errorText,
                  onChanged: (date) {
                    setState(() => _nextDoseDate = date);
                    field.didChange(date);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
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
                ? 'Record administration'
                : widget.vaccination == null
                ? 'Add vaccination'
                : 'Edit vaccination',
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
              ? 'Add vaccination'
              : 'Save changes',
          saveError: state.saveError,
          onSubmit: _submit,
          onExit: _requestExit,
          onChanged: () => setState(() {}),
          steps: [
            AppFormStep(
              title: 'Vaccination',
              builder: (_, _) => _vaccinationDetails(state),
            ),
            AppFormStep(
              title: 'Review',
              builder: (_, edit) => _review(state, edit),
            ),
          ],
        ),
      );
}
