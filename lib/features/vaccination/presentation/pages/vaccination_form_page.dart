import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _saveErrorKey = GlobalKey();
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
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      Scrollable.ensureVisible(
        invalid.first.context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }
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

  void _leave([bool? result]) {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(result);
    });
  }

  Future<void> _requestExit() async {
    if (_allowPop ||
        _confirmingDiscard ||
        context.read<VaccinationFormCubit>().state.isSaving) {
      return;
    }
    if (!_hasChanges) {
      context.pop();
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

  Widget _saveActions(bool saving) => AppFormActions(
    label: widget.vaccination == null ? 'Add vaccination' : 'Save changes',
    saving: saving,
    fixed: widget.vaccination != null,
    onPressed: widget.vaccination != null && !_hasChanges ? null : _submit,
  );

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
          onPressed: () =>
              context.read<VaccinationFormCubit>().loadVisits(widget.petId),
          child: const Text('Retry visits'),
        ),
      ),
    ],
    VerticalGap.md,
  ];

  List<Widget> _fields(
    VaccinationFormState state,
    bool saving,
    double feedbackHeight,
  ) => [
    if (state.saveError != null) ...[
      ConstrainedBox(
        key: _saveErrorKey,
        constraints: BoxConstraints(maxHeight: feedbackHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _error(state.saveError!),
              if (widget.vaccination == null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _submit,
                    child: const Text('Retry save'),
                  ),
                ),
            ],
          ),
        ),
      ),
      VerticalGap.md,
    ],
    const AppSectionHeading(
      title: 'Vaccine details',
      icon: Icons.vaccines_outlined,
    ),
    VerticalGap.md,
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
        if (_status == VaccinationStatus.administered && _date.isAfter(today)) {
          return 'Choose today or an earlier date';
        }
        return null;
      },
      builder: (field) => AppDateField(
        key: const Key('vaccination-date'),
        labelText: _status == VaccinationStatus.planned
            ? 'Planned date'
            : 'Administration date',
        value: _date,
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
    ),
    VerticalGap.xl,
    const AppSectionHeading(
      title: 'Clinic & veterinarian',
      icon: Icons.local_hospital_outlined,
    ),
    VerticalGap.md,
    if (_status == VaccinationStatus.administered) ..._visitOptions(state),
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
          onPressed: () => context.read<VaccinationFormCubit>().loadSuggestions(
            clinicName: _clinic.text,
          ),
          child: const Text('Retry suggestions'),
        ),
      ),
    ],
    VerticalGap.xl,
    const AppSectionHeading(title: 'Notes', icon: Icons.notes_outlined),
    VerticalGap.md,
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
    if (_canPlanNextDose) ...[
      VerticalGap.xl,
      const AppSectionHeading(
        title: 'Next dose',
        icon: Icons.event_repeat_outlined,
      ),
      VerticalGap.sm,
      const Text('Optionally create a separate plan for the next dose.'),
      VerticalGap.md,
      FormField<DateTime>(
        validator: (_) {
          if (_nextDoseDate == null) return null;
          if (!_nextDoseDate!.isAfter(_date)) {
            return 'Choose a date after the administration date';
          }
          return _nextDoseDate!.isBefore(DateUtils.dateOnly(DateTime.now()))
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
    if (widget.vaccination == null) ...[VerticalGap.xl, _saveActions(saving)],
  ];

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
            previous.saveError != current.saveError,
        listener: (context, state) {
          if (state.isSaved) {
            _leave(true);
          } else if (state.saveError != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final errorContext = _saveErrorKey.currentContext;
              if (mounted && errorContext != null) {
                Scrollable.ensureVisible(
                  errorContext,
                  alignment: 0,
                  duration: const Duration(milliseconds: 200),
                );
              }
            });
          }
        },
        builder: (context, state) {
          final saving = state.isSaving || state.isSaved;
          return PopScope<bool>(
            canPop: !state.isSaving && (_allowPop || !_hasChanges),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !saving) _requestExit();
            },
            child: Scaffold(
              appBar: AppBar(
                toolbarHeight: PetCareTitle.toolbarHeight(context),
                title: PetCareTitle(
                  title: widget.recordAdministration
                      ? 'Record administration'
                      : widget.vaccination == null
                      ? 'Add vaccination'
                      : 'Edit vaccination',
                  petName: widget.petName,
                ),
                leading: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: saving ? null : _requestExit,
                  icon: const BackButtonIcon(),
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: widget.vaccination == null,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: AbsorbPointer(
                                    absorbing: saving,
                                    child: Form(
                                      key: _formKey,
                                      onChanged: () => setState(() {}),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: _fields(
                                          state,
                                          saving,
                                          constraints.maxHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.vaccination != null) _saveActions(saving),
                ],
              ),
            ),
          );
        },
      );
}
