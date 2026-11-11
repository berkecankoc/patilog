import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:patilog/core/l10n/app_number_formats.dart';
import 'package:patilog/core/widgets/app_multi_step_form.dart';
import 'package:patilog/core/widgets/app_detail_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/widgets/app_gap.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/core/widgets/app_date_field.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_form_state.dart';
import 'package:patilog/features/vet_visit/presentation/utils/vet_visit_cost.dart';
import 'package:patilog/core/widgets/app_suggestion_field.dart';

class VetVisitFormPage extends StatefulWidget {
  final String petId;
  final VetVisit? visit;
  final String? petName;

  const VetVisitFormPage({
    super.key,
    required this.petId,
    this.visit,
    this.petName,
  });

  @override
  State<VetVisitFormPage> createState() => _VetVisitFormPageState();
}

class _VetVisitFormPageState extends State<VetVisitFormPage> {
  static const _medicalTextMaxLength = 200;

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
  bool _localizedAmount = false;

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
      _amount: '',
    };
    for (final entry in _initialText.entries) {
      entry.key.text = entry.value;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localizedAmount) return;
    _localizedAmount = true;
    final cost = widget.visit?.costMinorUnits;
    final value = cost == null
        ? ''
        : localizedAmount(cost, Localizations.localeOf(context));
    _amount.text = value;
    _initialText[_amount] = value;
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

  void _leave({bool? result}) {
    if (_allowPop) return;
    if (result == true) {
      PetCareChanges.recordChanged(context, widget.petId, PetCareTab.vetVisits);
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
        context.read<VetVisitFormCubit>().state.isSaving) {
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

  Widget _visitDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        key: const Key('visit-reason'),
        controller: _reason,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).visitReason,
        ),
        minLines: 1,
        maxLines: 3,
        validator: (value) {
          final reason = value?.trim() ?? '';
          if (reason.isEmpty) {
            return AppLocalizations.of(context).visitReasonRequired;
          }
          return reason.characters.length > 100
              ? AppLocalizations.of(context).visitReasonLimit
              : null;
        },
      ),
      VerticalGap.md,
      AppDateField(
        labelText: AppLocalizations.of(context).visitDate,
        value: _visitedOn,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        onChanged: (date) {
          if (date != null) {
            setState(() => _visitedOn = date);
          }
        },
      ),
      if (widget.visit != null &&
          !DateUtils.isSameDay(_visitedOn, _initialDate)) ...[
        VerticalGap.xs,
        Text(
          AppLocalizations.of(context).linkedVaccinationDateNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      VerticalGap.xl,
    ],
  );

  Widget _review(VetVisitFormState state, ValueChanged<int> edit) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AppLocalizations.of(context).reviewVisit,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      VerticalGap.md,
      AppFormReviewSection(
        title: AppLocalizations.of(context).visitDetails,
        icon: Icons.event_note_outlined,
        onEdit: () => edit(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailField(
              label: AppLocalizations.of(context).visitReasonSummary,
              value: _reason.text,
            ),
            VerticalGap.md,
            AppDetailField(
              label: AppLocalizations.of(context).visitDate,
              value: MaterialLocalizations.of(
                context,
              ).formatShortDate(_visitedOn),
            ),
            if (widget.visit != null &&
                !DateUtils.isSameDay(_visitedOn, _initialDate)) ...[
              VerticalGap.sm,
              Text(AppLocalizations.of(context).linkedVaccinationDateNotice),
            ],
          ],
        ),
      ),
      VerticalGap.md,
      AppFormOptionalSection(
        title: AppLocalizations.of(context).clinicalOptional,
        icon: Icons.local_hospital_outlined,
        initiallyExpanded: widget.visit != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSuggestionField(
              label: AppLocalizations.of(context).clinicOptional,
              loading: state.isLoadingSuggestions,
              controller: _clinic,
              suggestions: state.suggestions.clinicNames,
              onChanged: (value) => context
                  .read<VetVisitFormCubit>()
                  .loadSuggestions(clinicName: value),
            ),
            VerticalGap.md,
            AppSuggestionField(
              label: AppLocalizations.of(context).veterinarianOptional,
              controller: _veterinarian,
              suggestions: state.suggestions.veterinarianNames,
            ),
            if (state.suggestionsError != null) ...[
              VerticalGap.sm,
              Semantics(
                liveRegion: true,
                child: Text(
                  AppLocalizations.of(context).suggestionsLoadFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
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
                      .read<VetVisitFormCubit>()
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
        title: AppLocalizations.of(context).medicalNotesOptional,
        icon: Icons.medical_information_outlined,
        initiallyExpanded: widget.visit != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('visit-diagnosis'),
              controller: _diagnosis,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).diagnosisOptional,
              ),
              minLines: 1,
              maxLines: 4,
              maxLength: _medicalTextMaxLength,
              validator: (value) =>
                  (value?.characters.length ?? 0) > _medicalTextMaxLength
                  ? AppLocalizations.of(
                      context,
                    ).diagnosisLimit(_medicalTextMaxLength)
                  : null,
            ),
            VerticalGap.md,
            TextFormField(
              key: const Key('visit-notes'),
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).notesOptional,
              ),
              minLines: 1,
              maxLines: 6,
              maxLength: _medicalTextMaxLength,
              validator: (value) =>
                  (value?.characters.length ?? 0) > _medicalTextMaxLength
                  ? AppLocalizations.of(
                      context,
                    ).notesLimit(_medicalTextMaxLength)
                  : null,
            ),
            VerticalGap.xl,
          ],
        ),
      ),
      VerticalGap.md,
      AppFormOptionalSection(
        title: AppLocalizations.of(context).costOptional,
        icon: Icons.payments_outlined,
        initiallyExpanded: widget.visit != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('visit-cost'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).amountOptional,
              ),
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      parseVetVisitCost(value) != null
                  ? null
                  : AppLocalizations.of(context).costInvalid,
            ),
            VerticalGap.md,
            DropdownButtonFormField<VetVisitCurrency>(
              initialValue: _currency,
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).currency,
              ),
              items: [
                for (final currency in VetVisitCurrency.values)
                  DropdownMenuItem(value: currency, child: Text(currency.code)),
              ],
              onChanged: _amount.text.trim().isEmpty
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _currency = value);
                      }
                    },
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<VetVisitFormCubit, VetVisitFormState>(
        listener: (context, state) {
          if (state.isSaved) _leave(result: true);
        },
        builder: (context, state) => AppMultiStepForm(
          title: PetCareTitle(
            title: widget.visit == null
                ? AppLocalizations.of(context).addVisit
                : AppLocalizations.of(context).editVisit,
            petName: widget.petName,
          ),
          toolbarHeight: PetCareTitle.toolbarHeight(context),
          editing: widget.visit != null,
          isSaving: () {
            final current = context.read<VetVisitFormCubit>().state;
            return current.isSaving || current.isSaved;
          },
          allowPop: _allowPop,
          canSubmit: widget.visit == null || _hasChanges,
          submitLabel: widget.visit == null
              ? AppLocalizations.of(context).addVisit
              : AppLocalizations.of(context).saveChanges,
          saveError: state.saveError == null
              ? null
              : widget.visit == null
              ? AppLocalizations.of(context).visitCreateFailed
              : AppLocalizations.of(context).visitUpdateFailed,
          onSubmit: _submit,
          onExit: _requestExit,
          onChanged: () => setState(() {}),
          steps: [
            AppFormStep(
              title: AppLocalizations.of(context).visit,
              builder: (_, _) => _visitDetails(),
            ),
            AppFormStep(
              title: AppLocalizations.of(context).review,
              builder: (_, edit) => _review(state, edit),
            ),
          ],
        ),
      );
}
