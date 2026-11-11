import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/utils/time_input_formatter.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/core/widgets/app_form_actions.dart';
import 'package:patilog/core/widgets/app_form_scroll_view.dart';
import 'package:patilog/core/widgets/app_keyboard.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_occurrence.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_state.dart';
import 'package:patilog/features/feeding/presentation/utils/feeding_display.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

Future<void> showFeedingMealSheet(
  BuildContext context, {
  required FeedingCubit cubit,
  required FeedingOccurrence meal,
  Widget? petIdentity,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) =>
      _MealSheet(cubit: cubit, meal: meal, petIdentity: petIdentity),
);

class _MealSheet extends StatefulWidget {
  final FeedingCubit cubit;
  final FeedingOccurrence meal;
  final Widget? petIdentity;
  const _MealSheet({required this.cubit, required this.meal, this.petIdentity});

  @override
  State<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends State<_MealSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _time = TextEditingController();
  late final DateTime _initialInstant;
  late final String _initialTime;
  String? _initialAmount;
  bool _working = false;
  bool _confirming = false;
  bool _allowPop = false;
  bool _attempted = false;

  bool get _dirty =>
      _amount.text != _initialAmount || _time.text != _initialTime;

  @override
  void initState() {
    super.initState();
    final now = widget.cubit.now();
    final date = widget.meal.date;
    _initialInstant =
        widget.meal.entry?.givenAt ??
        (DateUtils.isSameDay(date, now)
            ? now
            : DateTime(date.year, date.month, date.day, now.hour, now.minute));
    final local = _initialInstant.toLocal();
    _initialTime = feedingTime(local.hour * 60 + local.minute);
    _time.text = _initialTime;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialAmount != null) return;
    _initialAmount = feedingAmount(
      context,
      widget.meal.entry?.amountGrams ?? widget.meal.meal.amountGrams,
    );
    _amount.text = _initialAmount!;
  }

  DateTime? get _givenAt {
    final minute = parseFeedingTime(_time.text);
    if (minute == null) return null;
    if (_time.text == _initialTime) return _initialInstant;
    final day = _initialInstant.toLocal();
    return DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
  }

  @override
  void dispose() {
    _amount.dispose();
    _time.dispose();
    super.dispose();
  }

  void _leave() {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _close() async {
    final state = widget.cubit.state;
    if (_working ||
        _confirming ||
        _allowPop ||
        state is FeedingLoaded && state.pendingAction != null) {
      return;
    }
    if (_dirty) {
      setState(() => _confirming = true);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AppConfirmationDialog(
          title: AppLocalizations.of(context).discardChangesTitle,
          message: AppLocalizations.of(context).discardChangesMessage,
          cancelLabel: AppLocalizations.of(context).keepEditing,
          confirmLabel: AppLocalizations.of(context).discardChanges,
        ),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (discard != true) return;
    }
    if (_attempted) widget.cubit.dismissActionFailure();
    _leave();
  }

  bool get _known {
    final state = widget.cubit.state;
    final meal = widget.cubit.currentMeal(widget.meal);
    return state is FeedingLoaded &&
        !state.isRefreshing &&
        state.refreshFailure == null &&
        state.pendingAction == null &&
        meal != null &&
        meal.entry?.id == widget.meal.entry?.id &&
        !DateUtils.dateOnly(
          meal.date,
        ).isAfter(DateUtils.dateOnly(widget.cubit.now()));
  }

  Future<void> _save() async {
    if (_working || _confirming || !_known || !_form.currentState!.validate()) {
      return;
    }
    if (widget.meal.entry != null && !_dirty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _attempted = true;
    });
    final saved = await widget.cubit.saveMeal(
      widget.meal,
      amountGrams: parseFeedingAmount(_amount.text)!,
      givenAt: _givenAt!,
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (saved) _leave();
  }

  Future<void> _clear() async {
    if (_working || _confirming || !_known) return;
    final entry = widget.cubit.currentMeal(widget.meal)?.entry;
    if (entry == null) return;
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: AppLocalizations.of(context).feedingDeleteTitle,
        message: AppLocalizations.of(context).feedingDeleteMessage,
        confirmLabel: AppLocalizations.of(context).clearRecord,
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true || !_known) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _attempted = true;
    });
    await widget.cubit.performAction(
      DeleteFeedingEntryAction(entry.petId, entry.id),
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (widget.cubit.currentMeal(widget.meal)?.entry == null) _leave();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<FeedingState>(
    stream: widget.cubit.stream,
    builder: (context, snapshot) {
      final s = AppLocalizations.of(context);
      final state = widget.cubit.state;
      final busy =
          _working || state is FeedingLoaded && state.pendingAction != null;
      final blocked = busy || _confirming || _allowPop;
      final refreshing =
          state is FeedingLoading ||
          state is FeedingLoaded && state.isRefreshing;
      final readFailed =
          state is FeedingError ||
          state is FeedingLoaded && state.refreshFailure != null;
      final error = _attempted && state is FeedingLoaded
          ? state.actionFailure
          : null;
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: AppFormScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                onChanged: () => setState(() {}),
                autovalidateMode: AutovalidateMode.onUserInteractionIfError,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.meal.entry == null
                                ? s.recordMeal
                                : s.editFeeding,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (MediaQuery.viewInsetsOf(context).bottom > 0)
                          const AppHideKeyboardButton(),
                        IconButton(
                          tooltip: s.close,
                          onPressed: blocked ? null : _close,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (widget.petIdentity != null) ...[
                      const SizedBox(height: 8),
                      widget.petIdentity!,
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${s.feedingMealTime} · ${feedingTime(widget.meal.meal.scheduledMinute)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatShortDate(_initialInstant.toLocal()),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _amount,
                      enabled: !blocked,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        labelText: s.feedingAmount,
                        suffixText: 'g',
                        errorMaxLines: 3,
                      ),
                      validator: (value) =>
                          validateFeedingAmount(context, value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _time,
                      enabled: !blocked,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: const [TimeInputFormatter()],
                      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        labelText: s.feedingTime,
                        helperText: s.time24Hint,
                        helperMaxLines: 2,
                        errorMaxLines: 3,
                      ),
                      validator: (_) => _givenAt == null
                          ? s.timeRangeInvalid
                          : _givenAt!.isAfter(widget.cubit.now())
                          ? s.givenTimeFuture
                          : null,
                    ),
                    if (refreshing)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                    if (readFailed) ...[
                      const SizedBox(height: 16),
                      Text(
                        s.feedingLoadFailed,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(48, 48),
                            alignment: AlignmentDirectional.centerStart,
                          ),
                          onPressed: blocked ? null : widget.cubit.retryLoad,
                          child: Text(s.retry),
                        ),
                      ),
                    ],
                    if (!_known &&
                        !busy &&
                        !_allowPop &&
                        !refreshing &&
                        !readFailed)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(s.feedingRecordNotFound),
                      ),
                    const SizedBox(height: 24),
                    AppFormActions(
                      label: widget.meal.entry == null ? s.save : s.saveChanges,
                      saving: busy,
                      onPressed:
                          blocked ||
                              !_known ||
                              widget.meal.entry != null && !_dirty
                          ? null
                          : _save,
                      feedback: error == null
                          ? null
                          : Semantics(
                              liveRegion: true,
                              child: Text(
                                state is FeedingLoaded &&
                                        state.failedAction
                                            is DeleteFeedingEntryAction
                                    ? s.feedingDeleteFailed
                                    : s.feedingSaveFailed,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                    ),
                    if (widget.meal.entry != null)
                      TextButton(
                        onPressed: blocked || !_known ? null : _clear,
                        child: Text(s.clearRecord),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
