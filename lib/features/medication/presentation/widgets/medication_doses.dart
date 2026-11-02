import 'package:petlytics/l10n/generated/app_localizations.dart';
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
import 'package:petlytics/core/utils/time_input_formatter.dart';

typedef DoseRecordState = ({
  MedicationDose? dose,
  bool known,
  bool busy,
  String? error,
});

/// The same editor works with pet-scoped and all-pets state; each caller keeps
/// ownership checks and writes in its own Cubit.
class MedicationDoseEditor {
  final Stream<Object?> changes;
  final DoseRecordState Function() read;
  final DateTime Function() now;
  final Future<void> Function(MedicationDoseLog) save;
  final Future<void> Function(MedicationDoseLog) clear;
  const MedicationDoseEditor({
    required this.changes,
    required this.read,
    required this.now,
    required this.save,
    required this.clear,
  });

  factory MedicationDoseEditor.forCubit(
    BuildContext context,
    MedicationDose dose,
  ) {
    final cubit = context.read<MedicationCubit>();
    return MedicationDoseEditor(
      changes: cubit.stream,
      now: cubit.now,
      read: () {
        final state = cubit.state;
        if (state is! MedicationsLoaded) {
          return (dose: null, known: false, busy: false, error: null);
        }
        return (
          dose: state.doses.doses
              .where(
                (row) =>
                    row.period.id == dose.period.id &&
                    row.scheduledMinute == dose.scheduledMinute &&
                    DateUtils.isSameDay(row.scheduledDate, dose.scheduledDate),
              )
              .firstOrNull,
          known:
              state.doses.hasLoaded &&
              !state.doses.isLoading &&
              state.doses.error == null &&
              !state.isRefreshing,
          busy: state.pendingAction != null,
          error: state.actionError,
        );
      },
      save: (log) => cubit.performAction(
        SaveMedicationDoseAction(dose.medication.id, log),
      ),
      clear: (log) => performMedicationAction(
        context,
        cubit,
        ClearMedicationDoseAction(dose.medication.id, log),
      ),
    );
  }
}

class MedicationDoseTile extends StatelessWidget {
  final MedicationDose dose;
  final bool known;
  final bool loading;
  final bool busy;
  final MedicationDoseEditor? editor;
  final Widget? petIdentity;
  final VoidCallback? onRecord;
  const MedicationDoseTile({
    super.key,
    required this.dose,
    required this.known,
    required this.loading,
    required this.busy,
    this.editor,
    this.petIdentity,
    this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final actions = editor ?? MedicationDoseEditor.forCubit(context, dose);
    final now = actions.now();
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
    void record() {
      final current = actions.read();
      if (!current.known ||
          current.busy ||
          current.dose == null ||
          DateUtils.dateOnly(
            dose.scheduledDate,
          ).isAfter(DateUtils.dateOnly(actions.now()))) {
        return;
      }
      if (onRecord != null) {
        onRecord!();
      } else {
        showMedicationDoseSheet(context, dose, editor: actions);
      }
    }

    void save(MedicationDoseStatus status, {DateTime? givenAt}) => actions.save(
      MedicationDoseLog(
        periodId: dose.period.id,
        scheduledDate: dose.scheduledDate,
        scheduledMinute: dose.scheduledMinute,
        status: status,
        givenAt: givenAt,
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: !known || loading || busy || future ? null : record,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (petIdentity != null) ...[
                petIdentity!,
                const SizedBox(height: 12),
              ],
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
                              ? AppLocalizations.of(context).loadingDoseRecord
                              : AppLocalizations.of(
                                  context,
                                ).doseRecordUnavailable,
                        )
                      : future
                      ? Text(AppLocalizations.of(context).scheduled)
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
                                ? AppLocalizations.of(context).givenAtEdit(
                                    formatDoseTime(
                                      log.givenAt!.toLocal().hour * 60 +
                                          log.givenAt!.toLocal().minute,
                                    ),
                                  )
                                : AppLocalizations.of(context).skippedEdit,
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
                                  : () => save(MedicationDoseStatus.skipped),
                              child: Text(
                                AppLocalizations.of(context).skipDose,
                              ),
                            ),
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () {
                                      final instant = actions.now();
                                      if (!DateUtils.isSameDay(
                                        dose.scheduledDate,
                                        instant,
                                      )) {
                                        record();
                                        return;
                                      }
                                      save(
                                        MedicationDoseStatus.given,
                                        givenAt: instant,
                                      );
                                    },
                              child: Text(
                                AppLocalizations.of(context).doseGiven,
                              ),
                            ),
                          ],
                        )
                      : Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(AppLocalizations.of(context).noDoseRecord),
                            TextButton(
                              onPressed: busy ? null : record,
                              child: Text(
                                AppLocalizations.of(context).recordDose,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMedicationDoseSheet(
  BuildContext context,
  MedicationDose dose, {
  MedicationDoseEditor? editor,
  Widget? petIdentity,
}) async {
  if (ModalRoute.of(context)?.isCurrent == false) return;
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => _DoseSheet(
      dose: dose,
      editor: editor ?? MedicationDoseEditor.forCubit(context, dose),
      petIdentity: petIdentity,
    ),
  );
}

class _DoseSheet extends StatefulWidget {
  final MedicationDose dose;
  final MedicationDoseEditor editor;
  final Widget? petIdentity;
  const _DoseSheet({
    required this.dose,
    required this.editor,
    this.petIdentity,
  });
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
    final time = log?.givenAt?.toLocal() ?? widget.editor.now();
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
      setState(() => _confirming = true);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AppConfirmationDialog(
          title: AppLocalizations.of(context).discardChangesTitle,
          message: AppLocalizations.of(context).unsavedDoseRecord,
          cancelLabel: AppLocalizations.of(context).keepEditing,
          confirmLabel: AppLocalizations.of(context).discardChanges,
        ),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (discard != true) return;
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
    final state = widget.editor.read();
    if (state.busy || !state.known) {
      return;
    }
    final dose = state.dose;
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
        await widget.editor.clear(dose.log!);
      }
    } else {
      await widget.editor.save(log!);
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _confirming = false;
    });
    final current = widget.editor.read();
    if (current.error == null && !current.busy) {
      final result = current.dose;
      if (result != null && (clear ? result.log == null : result.log == log)) {
        _leave(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Object?>(
    stream: widget.editor.changes,
    builder: (context, snapshot) {
      final current = widget.editor.read();
      final busy = _working || current.busy;
      final blocked = busy || _confirming;
      final known = current.known;
      final currentDose = current.dose;
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
                    autovalidateMode: AutovalidateMode.onUserInteractionIfError,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.dose.log == null
                                    ? AppLocalizations.of(context).recordDose
                                    : AppLocalizations.of(
                                        context,
                                      ).editDoseRecord,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (MediaQuery.viewInsetsOf(context).bottom > 0)
                              const AppHideKeyboardButton(),
                            IconButton(
                              tooltip: AppLocalizations.of(context).close,
                              onPressed: blocked ? null : _close,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (widget.petIdentity != null) ...[
                          widget.petIdentity!,
                          const SizedBox(height: 8),
                        ],
                        Text(
                          AppLocalizations.of(context).doseWithNameAndTime(
                            widget.dose.medication.name,
                            formatDoseTime(widget.dose.scheduledMinute),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatShortDate(widget.dose.scheduledDate),
                        ),
                        const SizedBox(height: 24),
                        SegmentedButton<MedicationDoseStatus>(
                          segments: [
                            ButtonSegment(
                              value: MedicationDoseStatus.given,
                              label: Text(
                                AppLocalizations.of(context).doseGiven,
                              ),
                            ),
                            ButtonSegment(
                              value: MedicationDoseStatus.skipped,
                              label: Text(
                                AppLocalizations.of(context).doseSkipped,
                              ),
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
                            inputFormatters: const [TimeInputFormatter()],
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).givenAt,
                              hintText: AppLocalizations.of(context).time24Hint,
                            ),
                            validator: (value) {
                              final minute = parseDoseTime(value ?? '');
                              if (minute == null) {
                                return AppLocalizations.of(
                                  context,
                                ).doseTimeInvalid;
                              }
                              final day = widget.dose.scheduledDate;
                              return DateTime(
                                    day.year,
                                    day.month,
                                    day.day,
                                    minute ~/ 60,
                                    minute % 60,
                                  ).isAfter(widget.editor.now())
                                  ? AppLocalizations.of(context).givenTimeFuture
                                  : null;
                            },
                          ),
                        ],
                        if (current.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                AppLocalizations.of(context).doseUpdateFailed,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        if (!known || currentDose == null)
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).doseNoLongerAvailable,
                            ),
                          ),
                        const SizedBox(height: 24),
                        AppFormActions(
                          label: widget.dose.log == null
                              ? AppLocalizations.of(context).save
                              : AppLocalizations.of(context).saveChanges,
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
                            child: Text(
                              AppLocalizations.of(context).clearRecord,
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
      );
    },
  );
}
