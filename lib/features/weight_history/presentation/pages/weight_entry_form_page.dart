import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_state.dart';

class WeightEntryFormPage extends StatefulWidget {
  final String petId;
  final WeightEntry? entry;

  const WeightEntryFormPage({super.key, required this.petId, this.entry});

  @override
  State<WeightEntryFormPage> createState() => _WeightEntryFormPageState();
}

class _WeightEntryFormPageState extends State<WeightEntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  late DateTime _measuredAt;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _measuredAt =
        widget.entry?.measuredAt.toLocal() ??
        DateUtils.dateOnly(DateTime.now());
    _weightController.text = widget.entry?.weight.toString() ?? '';
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<WeightHistoryCubit>();
    if (cubit.state is WeightHistoryLoading) return;
    if (!_formKey.currentState!.validate()) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entry == null ? 'Add measurement' : 'Edit measurement',
        ),
      ),
      body: BlocConsumer<WeightHistoryCubit, WeightHistoryState>(
        listener: (context, state) {
          if (state case WeightEntryCreated() || WeightEntryUpdated()) {
            context.pop(true);
          } else if (state case WeightHistoryError(:final message)) {
            setState(() => _saveError = message);
          }
        },
        builder: (context, state) {
          final saving = state is WeightHistoryLoading;
          return SafeArea(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Record the weight and the date it was measured.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          VerticalGap.lg,
                          TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
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
                          if (_saveError != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _saveError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            VerticalGap.md,
                          ],
                          ElevatedButton(
                            onPressed: saving ? null : _submit,
                            child: saving
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      HorizontalGap.sm,
                                      Flexible(child: Text('Saving…')),
                                    ],
                                  )
                                : const Text('Save measurement'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
