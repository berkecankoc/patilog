import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_state.dart';
import 'package:petlytics/features/vet_visit/presentation/utils/vet_visit_cost.dart';
import 'package:petlytics/features/vet_visit/presentation/widgets/vet_visit_name_field.dart';

class VetVisitFormPage extends StatefulWidget {
  final String petId;
  final VetVisit? visit;

  const VetVisitFormPage({super.key, required this.petId, this.visit});

  @override
  State<VetVisitFormPage> createState() => _VetVisitFormPageState();
}

class _VetVisitFormPageState extends State<VetVisitFormPage> {
  static const _medicalTextMaxLength = 200;

  final _formKey = GlobalKey<FormState>();
  final _saveErrorKey = GlobalKey();
  final _reason = TextEditingController();
  final _clinic = TextEditingController();
  final _veterinarian = TextEditingController();
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final _amount = TextEditingController();
  late final Map<TextEditingController, String> _initialText;
  late final DateTime _initialDate;
  late final VetVisitCurrency _initialCurrency;
  late DateTime _visitedOn;
  late VetVisitCurrency _currency;
  bool _allowPop = false;
  bool _confirmingDiscard = false;

  bool get _hasChanges =>
      _initialText.entries.any((entry) => entry.key.text != entry.value) ||
      !DateUtils.isSameDay(_visitedOn, _initialDate) ||
      (_amount.text.trim().isNotEmpty && _currency != _initialCurrency);

  @override
  void initState() {
    super.initState();
    final visit = widget.visit;
    _visitedOn = DateUtils.dateOnly(visit?.visitedOn ?? DateTime.now());
    _initialDate = _visitedOn;
    _currency = visit?.currency ?? VetVisitCurrency.turkishLira;
    _initialCurrency = _currency;
    _initialText = {
      _reason: visit?.reason ?? '',
      _clinic: visit?.clinicName ?? '',
      _veterinarian: visit?.veterinarianName ?? '',
      _diagnosis: visit?.diagnosis ?? '',
      _notes: visit?.notes ?? '',
      _amount: visit?.costMinorUnits == null
          ? ''
          : formatVetVisitCost(visit!.costMinorUnits!),
    };
    for (final entry in _initialText.entries) {
      entry.key.text = entry.value;
    }
  }

  @override
  void dispose() {
    for (final controller in _initialText.keys) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<VetVisitFormCubit>();
    if (_allowPop ||
        _confirmingDiscard ||
        cubit.state.isSaving ||
        cubit.state.isSaved) {
      return;
    }
    if (widget.visit != null && !_hasChanges) return;
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
    final cost = parseVetVisitCost(_amount.text);
    cubit.saveVetVisit(
      petId: widget.petId,
      visitId: widget.visit?.id,
      visitedOn: _visitedOn,
      reason: _reason.text,
      clinicName: _clinic.text,
      veterinarianName: _veterinarian.text,
      diagnosis: _diagnosis.text,
      notes: _notes.text,
      costMinorUnits: cost,
      currency: cost == null ? null : _currency,
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
        context.read<VetVisitFormCubit>().state.isSaving) {
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
    label: widget.visit == null ? 'Add visit' : 'Save changes',
    saving: saving,
    fixed: widget.visit != null,
    onPressed: widget.visit != null && !_hasChanges ? null : _submit,
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VetVisitFormCubit, VetVisitFormState>(
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
              title: Text(widget.visit == null ? 'Add visit' : 'Edit visit'),
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
                    bottom: widget.visit == null,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: AbsorbPointer(
                            absorbing: saving,
                            child: Form(
                              key: _formKey,
                              onChanged: () => setState(() {}),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (state.saveError != null) ...[
                                    Semantics(
                                      key: _saveErrorKey,
                                      liveRegion: true,
                                      child: Text(
                                        state.saveError!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                    VerticalGap.md,
                                  ],
                                  const AppSectionHeading(
                                    title: 'Visit details',
                                    icon: Icons.event_note_outlined,
                                  ),
                                  VerticalGap.md,
                                  AppDateField(
                                    labelText: 'Visit date',
                                    value: _visitedOn,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                    onChanged: (date) {
                                      if (date != null) {
                                        setState(() => _visitedOn = date);
                                      }
                                    },
                                  ),
                                  VerticalGap.md,
                                  TextFormField(
                                    key: const Key('visit-reason'),
                                    controller: _reason,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      labelText: 'Reason for visit',
                                    ),
                                    minLines: 1,
                                    maxLines: 3,
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Enter a reason for the visit'
                                        : null,
                                  ),
                                  VerticalGap.xl,
                                  const AppSectionHeading(
                                    title: 'Clinic & veterinarian',
                                    icon: Icons.local_hospital_outlined,
                                  ),
                                  VerticalGap.md,
                                  VetVisitNameField(
                                    label: 'Clinic (optional)',
                                    controller: _clinic,
                                    suggestions: state.suggestions.clinicNames,
                                    onChanged: (value) => context
                                        .read<VetVisitFormCubit>()
                                        .loadSuggestions(clinicName: value),
                                  ),
                                  VerticalGap.md,
                                  VetVisitNameField(
                                    label: 'Veterinarian (optional)',
                                    controller: _veterinarian,
                                    suggestions:
                                        state.suggestions.veterinarianNames,
                                  ),
                                  if (state.isLoadingSuggestions) ...[
                                    VerticalGap.sm,
                                    const LinearProgressIndicator(
                                      semanticsLabel: 'Loading suggestions',
                                    ),
                                  ],
                                  if (state.suggestionsError != null) ...[
                                    VerticalGap.sm,
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        state.suggestionsError!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: TextButton(
                                        onPressed: () => context
                                            .read<VetVisitFormCubit>()
                                            .loadSuggestions(
                                              clinicName: _clinic.text,
                                            ),
                                        child: const Text('Retry suggestions'),
                                      ),
                                    ),
                                  ],
                                  VerticalGap.xl,
                                  const AppSectionHeading(
                                    title: 'Medical notes',
                                    icon: Icons.medical_information_outlined,
                                  ),
                                  VerticalGap.md,
                                  TextFormField(
                                    key: const Key('visit-diagnosis'),
                                    controller: _diagnosis,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      labelText: 'Diagnosis (optional)',
                                    ),
                                    minLines: 1,
                                    maxLines: 4,
                                    maxLength: _medicalTextMaxLength,
                                    validator: (value) =>
                                        (value?.characters.length ?? 0) >
                                            _medicalTextMaxLength
                                        ? 'Keep diagnosis within $_medicalTextMaxLength characters'
                                        : null,
                                  ),
                                  VerticalGap.md,
                                  TextFormField(
                                    key: const Key('visit-notes'),
                                    controller: _notes,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes (optional)',
                                    ),
                                    minLines: 1,
                                    maxLines: 6,
                                    maxLength: _medicalTextMaxLength,
                                    validator: (value) =>
                                        (value?.characters.length ?? 0) >
                                            _medicalTextMaxLength
                                        ? 'Keep notes within $_medicalTextMaxLength characters'
                                        : null,
                                  ),
                                  VerticalGap.xl,
                                  const AppSectionHeading(
                                    title: 'Cost',
                                    icon: Icons.payments_outlined,
                                  ),
                                  VerticalGap.md,
                                  TextFormField(
                                    key: const Key('visit-cost'),
                                    controller: _amount,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: const InputDecoration(
                                      labelText: 'Amount (optional)',
                                    ),
                                    validator: (value) =>
                                        value == null ||
                                            value.trim().isEmpty ||
                                            parseVetVisitCost(value) != null
                                        ? null
                                        : 'Enter a valid amount with up to 2 decimal places',
                                  ),
                                  VerticalGap.md,
                                  DropdownButtonFormField<VetVisitCurrency>(
                                    initialValue: _currency,
                                    isExpanded: true,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.md,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Currency',
                                    ),
                                    items: [
                                      for (final currency
                                          in VetVisitCurrency.values)
                                        DropdownMenuItem(
                                          value: currency,
                                          child: Text(currency.code),
                                        ),
                                    ],
                                    onChanged: _amount.text.trim().isEmpty
                                        ? null
                                        : (value) {
                                            if (value != null) {
                                              setState(() => _currency = value);
                                            }
                                          },
                                  ),
                                  if (widget.visit == null) ...[
                                    VerticalGap.xl,
                                    _saveActions(saving),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.visit != null) _saveActions(saving),
              ],
            ),
          ),
        );
      },
    );
  }
}
