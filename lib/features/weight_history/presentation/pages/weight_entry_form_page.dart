import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:patilog/core/l10n/app_number_formats.dart';
import 'package:patilog/core/widgets/app_multi_step_form.dart';
import 'package:patilog/core/widgets/app_detail_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/utils/weight_utils.dart';
import 'package:patilog/core/widgets/app_gap.dart';
import 'package:patilog/core/widgets/app_date_field.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_state.dart';

class WeightEntryFormPage extends StatefulWidget {
  final String petId;
  final WeightEntry? entry;
  final String? petName;

  const WeightEntryFormPage({
    super.key,
    required this.petId,
    this.entry,
    this.petName,
  });

  @override
  State<WeightEntryFormPage> createState() => _WeightEntryFormPageState();
}

class _WeightEntryFormPageState extends State<WeightEntryFormPage> {
  final _weightController = TextEditingController();
  late DateTime _measuredAt;
  late final DateTime _initialMeasuredAt;
  Failure? _saveError;
  bool _allowPop = false;
  bool _confirmingDiscard = false;
  String? _initialWeightText;

  bool get _hasChanges =>
      _weightController.text != _initialWeightText ||
      !DateUtils.isSameDay(_measuredAt, _initialMeasuredAt);

  @override
  void initState() {
    super.initState();
    _measuredAt =
        widget.entry?.measuredAt.toLocal() ??
        DateUtils.dateOnly(DateTime.now());
    _initialMeasuredAt = _measuredAt;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialWeightText != null) return;
    _initialWeightText = widget.entry == null
        ? ''
        : localizedWeight(
            widget.entry!.weight,
            Localizations.localeOf(context),
          );
    _weightController.text = _initialWeightText!;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<WeightHistoryCubit>();
    if (_allowPop ||
        _confirmingDiscard ||
        cubit.state is WeightHistoryLoading) {
      return;
    }
    if (widget.entry != null && !_hasChanges) return;
    setState(() => _saveError = null);
    FocusScope.of(context).unfocus();
    final weight = parseWeight(_weightController.text)!;
    final entry = widget.entry;
    if (entry == null) {
      cubit.createWeightEntry(
        petId: widget.petId,
        weight: weight,
        measuredAt: _measuredAt,
      );
    } else {
      cubit.updateWeightEntry(entry, weight: weight, measuredAt: _measuredAt);
    }
  }

  void _leave({bool? result}) {
    if (_allowPop) return;
    if (result == true) {
      PetCareChanges.recordChanged(
        context,
        widget.petId,
        PetCareTab.weightHistory,
      );
    }
    setState(() => _allowPop = true);
    // Update the pop guard before leaving after save or confirmed discard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pop(result);
    });
  }

  Future<void> _requestExit() async {
    if (_allowPop ||
        _confirmingDiscard ||
        context.read<WeightHistoryCubit>().state is WeightHistoryLoading) {
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

  Widget _measurement() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        controller: _weightController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).weight,
          suffixText: 'kg',
          errorMaxLines: 3,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return AppLocalizations.of(context).weightRequired;
          }
          final weight = parseWeight(value);
          if (weight == null || !weight.isFinite || weight <= 0) {
            return AppLocalizations.of(context).weightGreaterThanZero;
          }
          if (!hasValidWeightPrecision(value)) {
            return AppLocalizations.of(context).weightThreeDecimals;
          }
          return null;
        },
      ),
      VerticalGap.md,
      AppDateField(
        labelText: AppLocalizations.of(context).measurementDate,
        value: _measuredAt,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        onChanged: (date) {
          // Reselecting the same day must not erase the measurement time.
          if (date == null || DateUtils.isSameDay(date, _measuredAt)) {
            return;
          }
          setState(() => _measuredAt = date);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<WeightHistoryCubit, WeightHistoryState>(
        listener: (context, state) {
          if (state case WeightEntryCreated() || WeightEntryUpdated()) {
            _leave(result: true);
          } else if (state case WeightHistoryError(:final failure)) {
            setState(() => _saveError = failure);
          }
        },
        builder: (context, state) => AppMultiStepForm(
          title: PetCareTitle(
            title: widget.entry == null
                ? AppLocalizations.of(context).addMeasurement
                : AppLocalizations.of(context).editMeasurement,
            petName: widget.petName,
          ),
          toolbarHeight: PetCareTitle.toolbarHeight(context),
          editing: widget.entry != null,
          isSaving: () {
            final current = context.read<WeightHistoryCubit>().state;
            return current is WeightHistoryLoading ||
                current is WeightEntryCreated ||
                current is WeightEntryUpdated;
          },
          allowPop: _allowPop,
          canSubmit: widget.entry == null || _hasChanges,
          submitLabel: widget.entry == null
              ? AppLocalizations.of(context).save
              : AppLocalizations.of(context).saveChanges,
          saveError: _saveError == null
              ? null
              : _saveError is NotFoundFailure
              ? AppLocalizations.of(context).measurementNotFound
              : widget.entry == null
              ? AppLocalizations.of(context).measurementCreateFailed
              : AppLocalizations.of(context).measurementUpdateFailed,
          onSubmit: _submit,
          onExit: _requestExit,
          onChanged: () => setState(() {}),
          steps: [
            AppFormStep(
              title: AppLocalizations.of(context).measurement,
              builder: (_, _) => _measurement(),
            ),
            AppFormStep(
              title: AppLocalizations.of(context).review,
              builder: (context, edit) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context).reviewMeasurement,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  VerticalGap.md,
                  AppFormReviewSection(
                    title: AppLocalizations.of(context).measurement,
                    icon: Icons.monitor_weight_outlined,
                    onEdit: () => edit(0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppDetailField(
                          label: AppLocalizations.of(context).weight,
                          value: '${_weightController.text} kg',
                        ),
                        VerticalGap.md,
                        AppDetailField(
                          label: AppLocalizations.of(context).measurementDate,
                          value: MaterialLocalizations.of(
                            context,
                          ).formatShortDate(_measuredAt),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
