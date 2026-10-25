import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';
import 'package:petlytics/core/widgets/app_detail_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/utils/weight_utils.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_state.dart';

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
  String? _saveError;
  bool _allowPop = false;
  bool _confirmingDiscard = false;

  bool get _hasChanges =>
      _weightController.text !=
          (widget.entry == null ? '' : formatWeight(widget.entry!.weight)) ||
      !DateUtils.isSameDay(_measuredAt, _initialMeasuredAt);

  @override
  void initState() {
    super.initState();
    _measuredAt =
        widget.entry?.measuredAt.toLocal() ??
        DateUtils.dateOnly(DateTime.now());
    _weightController.text = widget.entry == null
        ? ''
        : formatWeight(widget.entry!.weight);
    _initialMeasuredAt = _measuredAt;
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

  Widget _measurement() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        controller: _weightController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: const InputDecoration(
          labelText: 'Weight',
          suffixText: 'kg',
          errorMaxLines: 3,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Weight is required';
          }
          final weight = parseWeight(value);
          if (weight == null || !weight.isFinite || weight <= 0) {
            return 'Enter a weight greater than zero';
          }
          if (!hasValidWeightPrecision(value)) {
            return 'Use up to 3 decimal places';
          }
          return null;
        },
      ),
      VerticalGap.md,
      AppDateField(
        labelText: 'Measurement date',
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
  Widget build(
    BuildContext context,
  ) => BlocConsumer<WeightHistoryCubit, WeightHistoryState>(
    listener: (context, state) {
      if (state case WeightEntryCreated() || WeightEntryUpdated()) {
        _leave(result: true);
      } else if (state case WeightHistoryError(:final message)) {
        setState(() => _saveError = message);
      }
    },
    builder: (context, state) => AppMultiStepForm(
      title: PetCareTitle(
        title: widget.entry == null ? 'Add measurement' : 'Edit measurement',
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
      submitLabel: widget.entry == null ? 'Save' : 'Save changes',
      saveError: _saveError,
      onSubmit: _submit,
      onExit: _requestExit,
      onChanged: () => setState(() {}),
      steps: [
        AppFormStep(title: 'Measurement', builder: (_, _) => _measurement()),
        AppFormStep(
          title: 'Review',
          builder: (context, edit) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Review measurement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              VerticalGap.md,
              AppFormReviewSection(
                title: 'Measurement',
                icon: Icons.monitor_weight_outlined,
                onEdit: () => edit(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppDetailField(
                      label: 'Weight',
                      value: '${_weightController.text} kg',
                    ),
                    VerticalGap.md,
                    AppDetailField(
                      label: 'Measurement date',
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
