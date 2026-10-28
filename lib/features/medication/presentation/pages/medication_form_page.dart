import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';
import 'package:petlytics/core/widgets/app_suggestion_field.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/use_cases/create_medication.dart';
import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_form_state.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_display.dart';
import 'package:petlytics/core/utils/time_input_formatter.dart';

class MedicationFormPage extends StatefulWidget {
  final String petId;
  final String? petName;
  final Medication? medication;
  final String? periodId;
  final bool newSchedule;

  const MedicationFormPage({
    super.key,
    required this.petId,
    this.petName,
    this.medication,
    this.periodId,
    this.newSchedule = false,
  });

  @override
  State<MedicationFormPage> createState() => _MedicationFormPageState();
}

class _MedicationFormPageState extends State<MedicationFormPage> {
  final _details = ExpansibleController();
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  final _interval = TextEditingController();
  final _clinic = TextEditingController();
  final _vet = TextEditingController();
  final _notes = TextEditingController();
  final _times = <TextEditingController>[];
  final _allocatedTimes = <TextEditingController>[];
  MedicationPeriod? _period;
  late DateTime _start;
  late DateTime _changeStart;
  late DateTime _initialChangeStart;
  DateTime? _end;
  String? _visitId;
  late String _initial;
  bool _daily = true;
  bool _allowPop = false;
  bool _confirming = false;
  bool _optionsRequested = false;

  List<TextEditingController> get _fields => [
    _name,
    _dosage,
    _interval,
    _clinic,
    _vet,
    _notes,
  ];
  String get _snapshot => [
    for (final controller in _fields) controller.text,
    _daily,
    _start,
    _changeStart,
    _end,
    _visitId,
    for (final time in _times) time.text,
  ].join('|');
  bool get _dirty => _snapshot != _initial;
  bool get _editing => widget.medication != null;
  bool get _historical =>
      _period != null &&
      !widget.newSchedule &&
      calendarDayNumber(_period!.startDate) <=
          calendarDayNumber(DateTime.now()) &&
      widget.medication!.periodOn(DateTime.now())?.id != _period!.id;
  bool get _locked =>
      context.read<MedicationFormCubit>().state.hasDoseLogs == true;
  List<int> get _minutes =>
      _times.map((time) => parseDoseTime(time.text) ?? -1).toList()..sort();
  bool get _scheduleChanged =>
      _period != null &&
      (_dosage.text.trim() != (_period!.dosageInstructions ?? '') ||
          (_daily ? 1 : int.tryParse(_interval.text)) !=
              _period!.intervalDays ||
          _minutes.join(',') != _period!.doseTimes.join(',') ||
          _start != _period!.startDate ||
          _changeStart != _initialChangeStart);
  bool get _successor =>
      widget.newSchedule || (_locked && !_historical && _scheduleChanged);
  DateTime get _saveStart => _successor ? _changeStart : _start;

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    final now = DateTime.now();
    _period = medication == null
        ? null
        : widget.periodId == null
        ? medication.periodToEdit(now)
        : medication.periods.firstWhere(
            (period) => period.id == widget.periodId,
          );
    _name.text = medication?.name ?? '';
    _dosage.text = _period?.dosageInstructions ?? '';
    _interval.text = (_period?.intervalDays ?? 1).toString();
    _daily = (_period?.intervalDays ?? 1) == 1;
    _clinic.text = _period?.clinicName ?? '';
    _vet.text = _period?.veterinarianName ?? '';
    _notes.text = _period?.notes ?? '';
    _visitId = _period?.vetVisitId;
    _start = _period?.startDate ?? DateUtils.dateOnly(now);
    _changeStart = DateTime(now.year, now.month, now.day + 1);
    _initialChangeStart = _changeStart;
    _end = widget.newSchedule ? null : _period?.endDate;
    for (final minute in _period?.doseTimes ?? [now.hour * 60 + now.minute]) {
      _addTime(formatDoseTime(minute));
    }
    _initial = _snapshot;
    context.read<MedicationFormCubit>().loadSuggestions(
      clinicName: _clinic.text,
    );
    if (_period != null && !widget.newSchedule) {
      context.read<MedicationFormCubit>().checkPeriod(
        widget.petId,
        medication!.id,
        _period!.id,
      );
    }
  }

  void _addTime([String text = '']) {
    final controller = TextEditingController(text: text);
    _times.add(controller);
    _allocatedTimes.add(controller);
  }

  @override
  void dispose() {
    _details.dispose();
    for (final controller in [..._fields, ..._allocatedTimes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _requestExit() async {
    if (_allowPop ||
        _confirming ||
        context.read<MedicationFormCubit>().state.isSaving) {
      return;
    }
    if (_dirty) {
      _confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (_) => const AppConfirmationDialog(
          title: 'Discard changes?',
          message: 'Your changes have not been saved. Leave without saving?',
          cancelLabel: 'Keep editing',
          confirmLabel: 'Discard changes',
        ),
      );
      _confirming = false;
      if (!mounted || discard != true) return;
    }
    _leave();
  }

  void _leave([bool? saved]) {
    if (_allowPop) return;
    if (saved == true) {
      PetCareChanges.recordChanged(
        context,
        widget.petId,
        PetCareTab.medications,
      );
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(saved);
    });
  }

  String? _nameError(String? text) => (text ?? '').trim().isEmpty
      ? 'Enter a medication name.'
      : _limit(text, 50);
  String? _limit(String? text, int max) =>
      (text ?? '').trim().characters.length > max
      ? 'Use $max characters or fewer.'
      : null;
  String? _timeError(String? text) {
    final minute = parseDoseTime(text ?? '');
    if (minute == null) return 'Use HH:mm, from 00:00 to 23:59.';
    return _times.where((time) => parseDoseTime(time.text) == minute).length > 1
        ? 'Each time must be different.'
        : null;
  }

  String? get _scheduleError => _times.isEmpty
      ? 'Add at least one dose time.'
      : _end != null && calendarDayNumber(_end!) < calendarDayNumber(_saveStart)
      ? 'End date must be on or after the start date.'
      : null;

  void _submit() {
    final cubit = context.read<MedicationFormCubit>();
    final state = cubit.state;
    if (_allowPop ||
        _confirming ||
        state.isSaving ||
        state.isSaved ||
        (_editing &&
            !widget.newSchedule &&
            (state.isCheckingPeriod || state.hasDoseLogs == null)) ||
        (_editing && !_dirty && !widget.newSchedule)) {
      return;
    }
    if (!_editing) {
      cubit.createMedication(
        CreateMedicationParams(
          petId: widget.petId,
          name: _name.text,
          startDate: _start,
          endDate: _end,
          intervalDays: _daily ? 1 : int.parse(_interval.text),
          doseTimes: _minutes,
          dosageInstructions: _dosage.text,
          clinicName: _clinic.text,
          veterinarianName: _vet.text,
          notes: _notes.text,
          vetVisitId: _visitId,
        ),
      );
    } else {
      cubit.savePeriod(
        petId: widget.petId,
        medicationId: widget.medication!.id,
        medicationName: _name.text,
        periodId: _successor ? null : _period!.id,
        startDate: _saveStart,
        endDate: _end,
        intervalDays: _daily ? 1 : int.parse(_interval.text),
        doseTimes: _minutes,
        dosageInstructions: _dosage.text,
        clinicName: _clinic.text,
        veterinarianName: _vet.text,
        notes: _notes.text,
        vetVisitId: _visitId,
      );
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    String? hintText,
    TextInputType? keyboardType,
  }) => TextFormField(
    key: ValueKey(controller),
    controller: controller,
    validator: validator,
    readOnly: readOnly,
    minLines: 1,
    maxLines: maxLines,
    keyboardType: keyboardType,
    textInputAction: maxLines == 1
        ? TextInputAction.done
        : TextInputAction.newline,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(labelText: label, hintText: hintText),
  );

  Widget _medication(MedicationFormState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Which medication?', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 24),
      AppSuggestionField(
        controller: _name,
        label: 'Medication name',
        suggestions: state.suggestions.medicationNames,
        loading: state.isLoadingSuggestions,
        validator: _nameError,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      _field(
        _dosage,
        'Dosage instructions (optional)',
        hintText: 'e.g. half a tablet',
        validator: (value) => _limit(value, 100),
        readOnly: _historical,
      ),
    ],
  );

  Widget _schedule() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'When are the doses?',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      if (_historical)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'This previous schedule is read-only. You can still correct its clinic information and notes.',
          ),
        ),
      if (_locked && !_historical || widget.newSchedule)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Schedule changes start tomorrow or later. Earlier dose records stay unchanged.',
          ),
        ),
      AppDateField(
        labelText: _locked && !_historical || widget.newSchedule
            ? 'Changes start'
            : 'Start date',
        value: _locked && !_historical || widget.newSchedule
            ? _changeStart
            : _start,
        firstDate:
            _locked ||
                widget.newSchedule ||
                (_period != null &&
                    widget.medication!.periods.first.id != _period!.id)
            ? DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day + 1,
              )
            : DateTime(2000),
        lastDate: DateTime(2100),
        readOnly: _historical,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              if (_locked || widget.newSchedule) {
                _changeStart = value;
              } else {
                _start = value;
              }
            });
          }
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<bool>(
        initialValue: _daily,
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        decoration: const InputDecoration(labelText: 'Frequency'),
        items: const [
          DropdownMenuItem(value: true, child: Text('Daily')),
          DropdownMenuItem(value: false, child: Text('Every N days')),
        ],
        onChanged: _historical
            ? null
            : (value) {
                if (value != null) setState(() => _daily = value);
              },
      ),
      if (!_daily) ...[
        const SizedBox(height: 16),
        _field(
          _interval,
          'Days between doses',
          keyboardType: TextInputType.number,
          readOnly: _historical,
          validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
              ? 'Enter at least 1 day.'
              : null,
        ),
      ],
      const SizedBox(height: 24),
      for (final time in _times) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey(time),
                controller: time,
                readOnly: _historical,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                inputFormatters: const [TimeInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Dose time',
                  hintText: 'HH:mm',
                ),
                validator: _timeError,
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (!_historical)
              IconButton(
                tooltip: 'Remove ${time.text} dose time',
                onPressed: () => setState(() => _times.remove(time)),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      FormField<bool>(
        validator: (_) => _scheduleError,
        builder: (field) => field.hasError
            ? Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            : const SizedBox.shrink(),
      ),
      if (!_historical)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _addTime()),
            child: const Text('Add another time'),
          ),
        ),
      const SizedBox(height: 16),
      AppDateField(
        labelText: 'End date (optional)',
        value: _end,
        firstDate: _saveStart,
        lastDate: DateTime(2100),
        clearable: true,
        readOnly: _historical,
        onChanged: (value) => setState(() => _end = value),
      ),
    ],
  );

  void _loadOptions() {
    if (_optionsRequested) return;
    _optionsRequested = true;
    context.read<MedicationFormCubit>().loadVisits(widget.petId);
  }

  Widget _review(MedicationFormState state, ValueChanged<int> edit) {
    final dates = MaterialLocalizations.of(context);
    final ids = state.visits.map((visit) => visit.id).toSet();
    final options = <String?>[
      null,
      if (_visitId != null && !ids.contains(_visitId)) _visitId,
      ...state.visits.map((visit) => visit.id),
    ];
    String visitLabel(String? id) {
      if (id == null) return 'No linked visit';
      final visit = state.visits.where((visit) => visit.id == id).firstOrNull;
      return visit == null
          ? 'Linked visit unavailable'
          : '${dates.formatShortDate(visit.visitedOn)} · ${visit.reason}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review medication',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_period != null &&
            !widget.newSchedule &&
            calendarDayNumber(_period!.startDate) >
                calendarDayNumber(DateTime.now()))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Editing scheduled changes from ${dates.formatShortDate(_period!.startDate)}. Current usage stays unchanged until then.',
            ),
          ),
        const SizedBox(height: 16),
        AppFormReviewSection(
          title: 'Medication',
          icon: Icons.medication_outlined,
          onEdit: () => edit(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_name.text, style: Theme.of(context).textTheme.titleMedium),
              if (_dosage.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_dosage.text),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppFormReviewSection(
          title: 'Schedule',
          icon: Icons.schedule_outlined,
          onEdit: () => edit(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_daily ? 'Daily' : 'Every ${_interval.text} days'} · ${_times.map((time) => time.text).join(', ')}',
              ),
              const SizedBox(height: 8),
              Text(
                '${_successor ? 'Changes from' : 'From'} ${dates.formatShortDate(_saveStart)}',
              ),
              if (_end != null) ...[
                const SizedBox(height: 8),
                Text('Until ${dates.formatShortDate(_end!)}'),
              ],
              if (_successor)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Earlier dose records stay unchanged.'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppFormOptionalSection(
          controller: _details,
          initiallyExpanded: _details.isExpanded,
          title: 'Clinic & notes (optional)',
          icon: Icons.local_hospital_outlined,
          onExpansionChanged: (expanded) {
            if (expanded) _loadOptions();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey((_visitId, options.join('|'))),
                initialValue: _visitId,
                isExpanded: true,
                itemHeight: null,
                menuMaxHeight: MediaQuery.sizeOf(context).height * 0.5,
                borderRadius: BorderRadius.circular(16),
                decoration: const InputDecoration(
                  labelText: 'Vet visit (optional)',
                ),
                selectedItemBuilder: (_) => options
                    .map(
                      (id) => Text(
                        visitLabel(id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                    .toList(),
                items: options
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(visitLabel(id)),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  setState(() {
                    _visitId = id;
                    final visit = state.visits
                        .where((visit) => visit.id == id)
                        .firstOrNull;
                    if (visit != null) {
                      if (_clinic.text.trim().isEmpty) {
                        _clinic.text = visit.clinicName ?? '';
                      }
                      if (_vet.text.trim().isEmpty) {
                        _vet.text = visit.veterinarianName ?? '';
                      }
                    }
                  });
                  context.read<MedicationFormCubit>().loadSuggestions(
                    clinicName: _clinic.text,
                  );
                },
              ),
              if (state.isLoadingVisits)
                const LinearProgressIndicator(semanticsLabel: 'Loading visits'),
              if (state.visitsError != null)
                AppErrorFeedback(
                  message: state.visitsError!,
                  retryLabel: 'Retry visits',
                  onRetry: () => context.read<MedicationFormCubit>().loadVisits(
                    widget.petId,
                  ),
                ),
              const SizedBox(height: 16),
              AppSuggestionField(
                controller: _clinic,
                label: 'Clinic (optional)',
                suggestions: state.suggestions.clinicNames,
                loading: state.isLoadingSuggestions,
                onChanged: (_) {
                  setState(() {});
                  context.read<MedicationFormCubit>().loadSuggestions(
                    clinicName: _clinic.text,
                  );
                },
              ),
              const SizedBox(height: 16),
              AppSuggestionField(
                controller: _vet,
                label: 'Veterinarian (optional)',
                suggestions: state.suggestions.veterinarianNames,
                loading: state.isLoadingSuggestions,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _field(
                _notes,
                'Notes (optional)',
                maxLines: 3,
                validator: (value) => _limit(value, 200),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MedicationFormCubit, MedicationFormState>(
        listener: (_, state) {
          if (state.isSaved) _leave(true);
        },
        builder: (context, state) {
          final checking =
              _editing &&
              !widget.newSchedule &&
              (state.isCheckingPeriod || state.hasDoseLogs == null);
          return AppMultiStepForm(
            title: PetCareTitle(
              title: widget.newSchedule
                  ? 'Schedule doses'
                  : _editing
                  ? 'Edit medication'
                  : 'Add medication',
              petName: widget.petName,
            ),
            toolbarHeight: PetCareTitle.toolbarHeight(context),
            editing: _editing,
            initialStep: widget.newSchedule ? 1 : null,
            isSaving: () {
              final current = context.read<MedicationFormCubit>().state;
              return current.isSaving || current.isSaved;
            },
            allowPop: _allowPop,
            canSubmit: !checking && (_dirty || !_editing || widget.newSchedule),
            submitLabel: widget.newSchedule
                ? 'Schedule doses'
                : _editing
                ? 'Save changes'
                : 'Add medication',
            saveError: state.saveError,
            status: state.periodError != null
                ? AppErrorFeedback(
                    message: state.periodError!,
                    retryLabel: 'Retry dose history',
                    onRetry: () =>
                        context.read<MedicationFormCubit>().checkPeriod(
                          widget.petId,
                          widget.medication!.id,
                          _period!.id,
                        ),
                  )
                : checking
                ? const LinearProgressIndicator(
                    semanticsLabel: 'Checking dose history',
                  )
                : null,
            onSubmit: _submit,
            onExit: _requestExit,
            onChanged: () => setState(() {}),
            steps: [
              AppFormStep(
                title: 'Medication',
                builder: (_, _) =>
                    _withSuggestionsError(state, _medication(state)),
              ),
              AppFormStep(
                title: 'Schedule',
                builder: (_, _) => _withSuggestionsError(
                  state,
                  AbsorbPointer(absorbing: checking, child: _schedule()),
                ),
              ),
              AppFormStep(
                title: 'Review',
                builder: (_, edit) =>
                    _withSuggestionsError(state, _review(state, edit)),
              ),
            ],
          );
        },
      );

  Widget _withSuggestionsError(MedicationFormState state, Widget child) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          if (state.suggestionsError != null)
            AppErrorFeedback(
              message: state.suggestionsError!,
              retryLabel: 'Retry suggestions',
              onRetry: () => context
                  .read<MedicationFormCubit>()
                  .loadSuggestions(clinicName: _clinic.text),
            ),
        ],
      );
}
