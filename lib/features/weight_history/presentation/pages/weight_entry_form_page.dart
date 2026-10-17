import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _saveErrorKey = GlobalKey();
  final _weightController = TextEditingController();
  late DateTime _measuredAt;
  late final DateTime _initialMeasuredAt;
  String? _saveError;
  bool _allowPop = false;
  bool _confirmingDiscard = false;

  bool get _hasChanges =>
      _weightController.text != (widget.entry?.weight.toString() ?? '') ||
      !DateUtils.isSameDay(_measuredAt, _initialMeasuredAt);

  @override
  void initState() {
    super.initState();
    _measuredAt =
        widget.entry?.measuredAt.toLocal() ??
        DateUtils.dateOnly(DateTime.now());
    _weightController.text = widget.entry?.weight.toString() ?? '';
    _initialMeasuredAt = _measuredAt;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<WeightHistoryCubit>();
    if (_allowPop || cubit.state is WeightHistoryLoading) return;
    if (widget.entry != null && !_hasChanges) return;
    final invalidFields = _formKey.currentState!.validateGranularly();
    if (invalidFields.isNotEmpty) {
      Scrollable.ensureVisible(
        invalidFields.first.context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }
    setState(() => _saveError = null);
    FocusScope.of(context).unfocus();
    final weight = double.parse(_weightController.text.trim());
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

  void _leave([bool? result]) {
    setState(() => _allowPop = true);
    // Update the pop guard before leaving after save or confirmed discard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(result);
    });
  }

  Future<void> _requestExit() async {
    if (_allowPop ||
        _confirmingDiscard ||
        context.read<WeightHistoryCubit>().state is WeightHistoryLoading) {
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WeightHistoryCubit, WeightHistoryState>(
      listener: (context, state) {
        if (state case WeightEntryCreated() || WeightEntryUpdated()) {
          _leave(true);
        } else if (state case WeightHistoryError(:final message)) {
          setState(() => _saveError = message);
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
        final saving = state is WeightHistoryLoading;
        return PopScope<bool>(
          canPop: !saving && (_allowPop || !_hasChanges),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !saving) _requestExit();
          },
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: PetCareTitle.toolbarHeight(context),
              title: PetCareTitle(
                title: widget.entry == null
                    ? 'Add measurement'
                    : 'Edit measurement',
                petName: widget.petName,
              ),
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const BackButtonIcon(),
                onPressed: saving ? null : _requestExit,
              ),
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
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
                            TextFormField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Weight',
                                suffixText: 'kg',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Weight is required';
                                }
                                final weight = double.tryParse(value.trim());
                                if (weight == null ||
                                    !weight.isFinite ||
                                    weight <= 0) {
                                  return 'Enter a weight greater than zero';
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
                                if (date == null ||
                                    DateUtils.isSameDay(date, _measuredAt)) {
                                  return;
                                }
                                setState(() => _measuredAt = date);
                              },
                            ),
                            VerticalGap.lg,
                            AppFormActions(
                              label: widget.entry == null
                                  ? 'Save'
                                  : 'Save changes',
                              saving: saving,
                              onPressed: widget.entry != null && !_hasChanges
                                  ? null
                                  : _submit,
                              feedback: _saveError == null
                                  ? null
                                  : Semantics(
                                      key: _saveErrorKey,
                                      liveRegion: true,
                                      child: Text(
                                        _saveError!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
