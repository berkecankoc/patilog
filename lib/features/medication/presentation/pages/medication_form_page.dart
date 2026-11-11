import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/core/widgets/app_date_field.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/core/widgets/app_multi_step_form.dart';
import 'package:patilog/core/widgets/app_suggestion_field.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/domain/use_cases/create_medication.dart';
import 'package:patilog/features/medication/domain/utils/medication_calendar.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_form_state.dart';
import 'package:patilog/features/medication/presentation/utils/medication_display.dart';
import 'package:patilog/core/utils/time_input_formatter.dart';

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
  DateTime? _changeStart;
  late final DateTime _defaultChangeStart;
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
          _changeStart != null);
  bool get _successor =>
      widget.newSchedule || (_locked && !_historical && _scheduleChanged);
  DateTime get _saveStart =>
      _successor ? _changeStart ?? _defaultChangeStart : _start;

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
    _defaultChangeStart = DateTime(now.year, now.month, now.day + 1);
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
        builder: (context) => AppConfirmationDialog(
          title: AppLocalizations.of(context).discardChangesTitle,
          message: AppLocalizations.of(context).discardChangesMessage,
          cancelLabel: AppLocalizations.of(context).keepEditing,
          confirmLabel: AppLocalizations.of(context).discardChanges,
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
      ? AppLocalizations.of(context).medicationNameRequired
      : _limit(text, 50);
  String? _limit(String? text, int max) =>
      (text ?? '').trim().characters.length > max
      ? AppLocalizations.of(context).maxCharacters(max)
      : null;
  String? _timeError(String? text) {
    final minute = parseDoseTime(text ?? '');
    if (minute == null) return AppLocalizations.of(context).doseTimeInvalid;
    return _times.where((time) => parseDoseTime(time.text) == minute).length > 1
        ? AppLocalizations.of(context).uniqueDoseTimes
        : null;
  }

  String? get _endError =>
      _end != null && calendarDayNumber(_end!) < calendarDayNumber(_saveStart)
      ? AppLocalizations.of(context).periodEndInvalid
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
      Text(
        AppLocalizations.of(context).whichMedication,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 24),
      AppSuggestionField(
        controller: _name,
        label: AppLocalizations.of(context).medicationName,
        suggestions: state.suggestions.medicationNames,
        loading: state.isLoadingSuggestions,
        validator: _nameError,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      _field(
        _dosage,
        AppLocalizations.of(context).dosageInstructionsOptional,
        hintText: AppLocalizations.of(context).dosageExample,
        validator: (value) => _limit(value, 100),
        readOnly: _historical,
      ),
    ],
  );

  Widget _schedule() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AppLocalizations.of(context).doseScheduleQuestion,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      if (_historical)
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(AppLocalizations.of(context).previousScheduleReadOnly),
        ),
      if (_locked && !_historical || widget.newSchedule)
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(AppLocalizations.of(context).newScheduleEffectiveHint),
        ),
      AppDateField(
        labelText: _successor
            ? AppLocalizations.of(context).changesStart
            : AppLocalizations.of(context).startDate,
        value: _saveStart,
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
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).frequency,
        ),
        items: [
          DropdownMenuItem(
            value: true,
            child: Text(AppLocalizations.of(context).daily),
          ),
          DropdownMenuItem(
            value: false,
            child: Text(AppLocalizations.of(context).everyNDays),
          ),
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
          AppLocalizations.of(context).daysBetweenDoses,
          keyboardType: TextInputType.number,
          readOnly: _historical,
          validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
              ? AppLocalizations.of(context).intervalRequired
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).doseTime,
                  hintText: AppLocalizations.of(context).timeFormatHint,
                ),
                validator: _timeError,
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (!_historical)
              IconButton(
                tooltip: AppLocalizations.of(context).removeDoseTime(time.text),
                onPressed: () => setState(() => _times.remove(time)),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      FormField<bool>(
        validator: (_) => _times.isEmpty
            ? AppLocalizations.of(context).doseTimeRequired
            : null,
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
            child: Text(AppLocalizations.of(context).addAnotherTime),
          ),
        ),
      const SizedBox(height: 16),
      FormField<DateTime>(
        validator: (_) => _endError,
        builder: (_) => AppDateField(
          labelText: AppLocalizations.of(context).endDateOptional,
          value: _end,
          firstDate: _saveStart,
          lastDate: DateTime(2100),
          errorText: _endError,
          clearable: true,
          readOnly: _historical,
          onChanged: (value) => setState(() => _end = value),
        ),
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
      if (id == null) return AppLocalizations.of(context).noLinkedVisit;
      final visit = state.visits.where((visit) => visit.id == id).firstOrNull;
      return visit == null
          ? AppLocalizations.of(context).linkedVisitUnavailable
          : '${dates.formatShortDate(visit.visitedOn)} · ${visit.reason}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).reviewMedication,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_period != null &&
            !widget.newSchedule &&
            calendarDayNumber(_period!.startDate) >
                calendarDayNumber(DateTime.now()))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              AppLocalizations.of(context).editScheduledChangesNotice(
                dates.formatShortDate(_period!.startDate),
              ),
            ),
          ),
        const SizedBox(height: 16),
        AppFormReviewSection(
          title: AppLocalizations.of(context).medication,
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
          title: AppLocalizations.of(context).schedule,
          icon: Icons.schedule_outlined,
          onEdit: () => edit(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).medicationScheduleSummary(
                  _daily
                      ? AppLocalizations.of(context).daily
                      : AppLocalizations.of(context).medicationEveryDays(
                          int.tryParse(_interval.text) ?? 1,
                        ),
                  _times.map((time) => time.text).join(', '),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _successor
                    ? AppLocalizations.of(
                        context,
                      ).changesFromDate(dates.formatShortDate(_saveStart))
                    : AppLocalizations.of(
                        context,
                      ).fromDate(dates.formatShortDate(_saveStart)),
              ),
              if (_end != null) ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(
                    context,
                  ).untilDate(dates.formatShortDate(_end!)),
                ),
              ],
              if (_successor)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    AppLocalizations.of(context).preserveEarlierDoseRecords,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppFormOptionalSection(
          controller: _details,
          initiallyExpanded: _details.isExpanded,
          title: AppLocalizations.of(context).clinicalNotesOptional,
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).vetVisitOptional,
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
                LinearProgressIndicator(
                  semanticsLabel: AppLocalizations.of(context).loadingVisits,
                ),
              if (state.visitsError != null)
                AppErrorFeedback(
                  message: AppLocalizations.of(context).visitsLoadFailed,
                  retryLabel: AppLocalizations.of(context).retryVisits,
                  onRetry: () => context.read<MedicationFormCubit>().loadVisits(
                    widget.petId,
                  ),
                ),
              const SizedBox(height: 16),
              AppSuggestionField(
                controller: _clinic,
                label: AppLocalizations.of(context).clinicOptional,
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
                label: AppLocalizations.of(context).veterinarianOptional,
                suggestions: state.suggestions.veterinarianNames,
                loading: state.isLoadingSuggestions,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _field(
                _notes,
                AppLocalizations.of(context).notesOptional,
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
                  ? AppLocalizations.of(context).scheduleDoses
                  : _editing
                  ? AppLocalizations.of(context).editMedication
                  : AppLocalizations.of(context).addMedication,
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
                ? AppLocalizations.of(context).scheduleDoses
                : _editing
                ? AppLocalizations.of(context).saveChanges
                : AppLocalizations.of(context).addMedication,
            saveError: state.saveError == null
                ? null
                : AppLocalizations.of(context).medicationSaveFailed,
            status: state.periodError != null
                ? AppErrorFeedback(
                    message: AppLocalizations.of(context).periodCheckFailed,
                    retryLabel: AppLocalizations.of(context).retryDoseHistory,
                    onRetry: () =>
                        context.read<MedicationFormCubit>().checkPeriod(
                          widget.petId,
                          widget.medication!.id,
                          _period!.id,
                        ),
                  )
                : checking
                ? LinearProgressIndicator(
                    semanticsLabel: AppLocalizations.of(
                      context,
                    ).checkingDoseHistory,
                  )
                : null,
            onSubmit: _submit,
            onExit: _requestExit,
            onChanged: () => setState(() {}),
            steps: [
              AppFormStep(
                title: AppLocalizations.of(context).medication,
                builder: (_, _) =>
                    _withSuggestionsError(state, _medication(state)),
              ),
              AppFormStep(
                title: AppLocalizations.of(context).schedule,
                builder: (_, _) => _withSuggestionsError(
                  state,
                  AbsorbPointer(absorbing: checking, child: _schedule()),
                ),
              ),
              AppFormStep(
                title: AppLocalizations.of(context).review,
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
              message: AppLocalizations.of(context).suggestionsLoadFailed,
              retryLabel: AppLocalizations.of(context).retrySuggestions,
              onRetry: () => context
                  .read<MedicationFormCubit>()
                  .loadSuggestions(clinicName: _clinic.text),
            ),
        ],
      );
}
