import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_keyboard.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_actions.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_display.dart';
import 'package:petlytics/features/medication/presentation/utils/dose_time_input_formatter.dart';

class MedicationDoseTile extends StatelessWidget {
  final MedicationDose dose;
  final bool known;
  final bool loading;
  final bool busy;
  const MedicationDoseTile({
    super.key,
    required this.dose,
    required this.known,
    required this.loading,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MedicationCubit>();
    final now = cubit.now();
    final future = DateUtils.dateOnly(
      dose.scheduledDate,
    ).isAfter(DateUtils.dateOnly(now));
    final today = DateUtils.isSameDay(dose.scheduledDate, now);
    final log = dose.log;
    final style = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final time = Text(formatDoseTime(dose.scheduledMinute), style: style);
    final name = Text(dose.medication.name, style: style);
    void record() => showMedicationDoseSheet(context, dose);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (MediaQuery.textScalerOf(context).scale(16) > 24 &&
                    constraints.maxWidth < 320) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [time, const SizedBox(height: 8), name],
                  );
                }
                return Row(
                  children: [
                    time,
                    const SizedBox(width: 12),
                    Expanded(child: name),
                  ],
                );
              },
            ),
            if (dose.period.dosageInstructions != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(dose.period.dosageInstructions!),
              ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: !known
                    ? Text(
                        loading
                            ? 'Loading dose record…'
                            : 'Dose record unavailable',
                      )
                    : future
                    ? const Text('Scheduled')
                    : log != null
                    ? TextButton.icon(
                        onPressed: busy ? null : record,
                        icon: Icon(
                          log.status == MedicationDoseStatus.given
                              ? Icons.check_circle_outline
                              : Icons.remove_circle_outline,
                          size: 20,
                        ),
                        label: Text(
                          log.status == MedicationDoseStatus.given
                              ? 'Given at ${formatDoseTime(log.givenAt!.toLocal().hour * 60 + log.givenAt!.toLocal().minute)} · Edit'
                              : 'Skipped · Edit',
                        ),
                      )
                    : today
                    ? Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => cubit.saveDose(
                                    dose,
                                    MedicationDoseStatus.skipped,
                                  ),
                            child: const Text('Skip'),
                          ),
                          FilledButton(
                            onPressed: busy
                                ? null
                                : () {
                                    final instant = cubit.now();
                                    if (!DateUtils.isSameDay(
                                      dose.scheduledDate,
                                      instant,
                                    )) {
                                      record();
                                      return;
                                    }
                                    cubit.saveDose(
                                      dose,
                                      MedicationDoseStatus.given,
                                      givenAt: instant,
                                    );
                                  },
                            child: const Text('Given'),
                          ),
                        ],
                      )
                    : Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('No record'),
                          TextButton(
                            onPressed: busy ? null : record,
                            child: const Text('Record dose'),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showMedicationDoseSheet(
  BuildContext context,
  MedicationDose dose,
) async {
  final cubit = context.read<MedicationCubit>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _DoseSheet(dose: dose),
    ),
  );
}

class _DoseSheet extends StatefulWidget {
  final MedicationDose dose;
  const _DoseSheet({required this.dose});
  @override
  State<_DoseSheet> createState() => _DoseSheetState();
}

class _DoseSheetState extends State<_DoseSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _time;
  late MedicationDoseStatus _status;
  bool _working = false;
  bool _allowPop = false;
  bool _confirming = false;
  late String _initialTime;
  late MedicationDoseStatus _initialStatus;
  bool get _dirty => _status != _initialStatus || _time.text != _initialTime;
  @override
  void initState() {
    super.initState();
    final log = widget.dose.log;
    final time =
        log?.givenAt?.toLocal() ?? context.read<MedicationCubit>().now();
    _time = TextEditingController(
      text: formatDoseTime(time.hour * 60 + time.minute),
    );
    _status = log?.status ?? MedicationDoseStatus.given;
    _initialStatus = _status;
    _initialTime = _time.text;
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  bool _sameDose(MedicationDose dose) =>
      dose.period.id == widget.dose.period.id &&
      DateUtils.isSameDay(dose.scheduledDate, widget.dose.scheduledDate) &&
      dose.scheduledMinute == widget.dose.scheduledMinute;

  void _leave([bool? saved]) {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(saved);
    });
  }

  Future<void> _close() async {
    if (_working || _confirming || _allowPop) return;
    if (_dirty) {
      _confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (_) => const AppConfirmationDialog(
          title: 'Discard changes?',
          message: 'Your dose record changes have not been saved.',
          cancelLabel: 'Keep editing',
          confirmLabel: 'Discard changes',
        ),
      );
      _confirming = false;
      if (!mounted || discard != true) return;
    }
    _leave();
  }

  Future<void> _save({bool clear = false}) async {
    if (!clear && widget.dose.log != null && !_dirty) return;
    if (_working ||
        _confirming ||
        (!clear && !_form.currentState!.validate())) {
      return;
    }
    final cubit = context.read<MedicationCubit>();
    final state = cubit.state;
    if (state is! MedicationsLoaded ||
        state.pendingAction != null ||
        state.doses.isLoading ||
        !state.doses.hasLoaded) {
      return;
    }
    final dose = state.doses.doses.where(_sameDose).firstOrNull;
    if (dose == null) return;
    setState(() {
      if (clear) {
        _confirming = true;
      } else {
        _working = true;
      }
    });
    final minute = parseDoseTime(_time.text);
    final day = dose.scheduledDate;
    final log = clear
        ? null
        : MedicationDoseLog(
            periodId: dose.period.id,
            scheduledDate: day,
            scheduledMinute: dose.scheduledMinute,
            status: _status,
            givenAt: _status == MedicationDoseStatus.given
                ? DateTime(
                    day.year,
                    day.month,
                    day.day,
                    minute! ~/ 60,
                    minute % 60,
                  )
                : null,
          );
    if (clear) {
      if (dose.log != null) {
        await performMedicationAction(
          context,
          cubit,
          ClearMedicationDoseAction(dose.medication.id, dose.log!),
        );
      }
    } else {
      await cubit.performAction(
        SaveMedicationDoseAction(dose.medication.id, log!),
      );
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _confirming = false;
    });
    final current = cubit.state;
    if (current is MedicationsLoaded &&
        current.actionError == null &&
        current.pendingAction == null) {
      final result = current.doses.doses.where(_sameDose).firstOrNull;
      if (result != null && (clear ? result.log == null : result.log == log)) {
        _leave(true);
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<MedicationCubit, MedicationState>(
    builder: (context, state) {
      final current = state is MedicationsLoaded ? state : null;
      final busy = _working || current?.pendingAction != null;
      final blocked = busy || _confirming;
      final known =
          current?.doses.hasLoaded == true && current?.doses.isLoading == false;
      final currentDose = current?.doses.doses.where(_sameDose).firstOrNull;
      return PopScope<bool>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Material(
            child: SafeArea(
              top: false,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(overscroll: false),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.dose.log == null
                                    ? 'Record dose'
                                    : 'Edit dose record',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (MediaQuery.viewInsetsOf(context).bottom > 0)
                              const AppHideKeyboardButton(),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: blocked ? null : _close,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.dose.medication.name} · ${formatDoseTime(widget.dose.scheduledMinute)} dose',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatShortDate(widget.dose.scheduledDate),
                        ),
                        const SizedBox(height: 24),
                        SegmentedButton<MedicationDoseStatus>(
                          segments: const [
                            ButtonSegment(
                              value: MedicationDoseStatus.given,
                              label: Text('Given'),
                            ),
                            ButtonSegment(
                              value: MedicationDoseStatus.skipped,
                              label: Text('Skipped'),
                            ),
                          ],
                          selected: {_status},
                          onSelectionChanged: blocked
                              ? null
                              : (value) =>
                                    setState(() => _status = value.single),
                        ),
                        if (_status == MedicationDoseStatus.given) ...[
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _time,
                            onChanged: (_) => setState(() {}),
                            enabled: !blocked,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            inputFormatters: const [DoseTimeInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Given at',
                              hintText: 'HH:mm · 24-hour',
                            ),
                            validator: (value) {
                              final minute = parseDoseTime(value ?? '');
                              if (minute == null) {
                                return 'Use HH:mm, from 00:00 to 23:59.';
                              }
                              final day = widget.dose.scheduledDate;
                              return DateTime(
                                    day.year,
                                    day.month,
                                    day.day,
                                    minute ~/ 60,
                                    minute % 60,
                                  ).isAfter(
                                    context.read<MedicationCubit>().now(),
                                  )
                                  ? 'Given time cannot be in the future.'
                                  : null;
                            },
                          ),
                        ],
                        if (current?.actionError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                current!.actionError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        if (!known || currentDose == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'This dose is not available for changes. Close and refresh the selected day.',
                            ),
                          ),
                        const SizedBox(height: 24),
                        AppFormActions(
                          label: widget.dose.log == null
                              ? 'Save'
                              : 'Save changes',
                          saving: busy,
                          onPressed:
                              blocked ||
                                  !known ||
                                  currentDose == null ||
                                  (widget.dose.log != null && !_dirty)
                              ? null
                              : () => _save(),
                        ),
                        if (currentDose?.log != null)
                          TextButton(
                            onPressed: blocked
                                ? null
                                : () => _save(clear: true),
                            child: const Text('Clear record'),
                          ),
                      ],
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
