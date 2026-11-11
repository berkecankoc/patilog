import 'package:flutter/material.dart';
import 'package:patilog/core/widgets/app_feeding_icon.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/utils/time_input_formatter.dart';
import 'package:patilog/core/widgets/app_date_field.dart';
import 'package:patilog/core/widgets/app_detail_field.dart';
import 'package:patilog/core/widgets/app_multi_step_form.dart';
import 'package:patilog/core/widgets/error_view.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_form_cubit.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_form_state.dart';
import 'package:patilog/features/feeding/presentation/utils/feeding_display.dart';
import 'package:patilog/features/feeding/presentation/widgets/feeding_form_shell.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

class FeedingPlanFormPage extends StatefulWidget {
  final String petId;
  final String? petName;
  final FeedingPlan? plan;
  final FeedingPlan? template;
  final List<FeedingPlan>? plans;
  final DateTime Function() now;
  const FeedingPlanFormPage({
    super.key,
    required this.petId,
    this.petName,
    this.plan,
    this.template,
    this.plans,
    this.now = DateTime.now,
  });
  @override
  State<FeedingPlanFormPage> createState() => _FeedingPlanFormPageState();
}

class _MealFields {
  final key = UniqueKey();
  final String? id;
  final time = TextEditingController();
  final amount = TextEditingController();
  final food = TextEditingController();
  _MealFields({this.id});
  (String?, String, String, String) get snapshot =>
      (id, time.text, amount.text, food.text);
  void dispose() {
    time.dispose();
    amount.dispose();
    food.dispose();
  }
}

class _FeedingPlanFormPageState extends State<FeedingPlanFormPage> {
  final _meals = <_MealFields>[];
  List<FeedingPlan>? _plans;
  late DateTime _start;
  DateTime? _end;
  late DateTime _initialStart;
  DateTime? _initialEnd;
  late List<(String?, String, String, String)> _baseline;
  bool get _locked =>
      widget.plan != null &&
      !DateUtils.dateOnly(
        widget.plan!.startDate,
      ).isAfter(DateUtils.dateOnly(widget.now()));
  DateTime get _minimum => _plans!.isEmpty
      ? DateUtils.dateOnly(widget.now())
      : DateTime(widget.now().year, widget.now().month, widget.now().day + 1);
  bool get _changed =>
      _start != _initialStart ||
      _end != _initialEnd ||
      _meals.length != _baseline.length ||
      _meals.indexed.any((item) => item.$2.snapshot != _baseline[item.$1]);

  @override
  void initState() {
    super.initState();
    if (widget.plans == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<FeedingFormCubit>().loadPlans(widget.petId);
      });
    }
  }

  void _initialize(List<FeedingPlan> plans) {
    if (_plans != null) return;
    _plans = List.unmodifiable(plans);
    _start = widget.plan == null
        ? _minimum
        : DateUtils.dateOnly(widget.plan!.startDate);
    _end = widget.plan?.endDate == null
        ? null
        : DateUtils.dateOnly(widget.plan!.endDate!);
    _initialStart = _start;
    _initialEnd = _end;
    final template = widget.plan ?? widget.template;
    for (final meal in template?.meals ?? []) {
      final fields = _MealFields(id: widget.plan == null ? null : meal.id);
      fields.time.text = feedingTime(meal.scheduledMinute);
      fields.amount.text = feedingAmount(context, meal.amountGrams);
      fields.food.text = meal.foodName ?? '';
      _meals.add(fields);
    }
    if (_meals.isEmpty) _meals.add(_MealFields()..time.text = '09:00');
    _baseline = _meals.map((meal) => meal.snapshot).toList();
  }

  @override
  void dispose() {
    for (final meal in _meals) {
      meal.dispose();
    }
    super.dispose();
  }

  Widget _meal(_MealFields meal, int index) {
    final s = AppLocalizations.of(context);
    final time = TextFormField(
      controller: meal.time,
      readOnly: _locked,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: const [TimeInputFormatter()],
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: s.feedingMealTime,
        helperText: s.time24Hint,
        errorMaxLines: 3,
      ),
      validator: (value) => parseFeedingTime(value ?? '') == null
          ? s.timeRangeInvalid
          : _meals.any(
              (other) =>
                  other != meal &&
                  parseFeedingTime(other.time.text) == parseFeedingTime(value!),
            )
          ? s.feedingDuplicateTime
          : null,
    );
    final amount = TextFormField(
      controller: meal.amount,
      readOnly: _locked,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: s.feedingAmount,
        suffixText: 'g',
        errorMaxLines: 3,
      ),
      validator: (v) => validateFeedingAmount(context, v),
    );
    return Padding(
      key: meal.key,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.feedingMealNumber(index + 1),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (!_locked)
                IconButton(
                  tooltip: s.removeFeedingMeal(index + 1),
                  onPressed: _meals.length <= 1
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          setState(() => _meals.remove(meal));
                          // The old field detaches during this frame before its controller is disposed.
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => meal.dispose(),
                          );
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20
                ? Column(children: [time, const SizedBox(height: 16), amount])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: time),
                      const SizedBox(width: 16),
                      Expanded(child: amount),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<FeedingFormCubit, FeedingFormState>(
    builder: (context, state) {
      final s = AppLocalizations.of(context);
      final options =
          widget.plans ??
          (state.hasLoadedPlans && state.plansPetId == widget.petId
              ? state.plans
              : null);
      if (options == null) {
        return Scaffold(
          appBar: AppBar(
            title: PetCareTitle(title: s.feedingPlan, petName: widget.petName),
            toolbarHeight: PetCareTitle.toolbarHeight(context),
          ),
          body: state.plansFailure != null
              ? ErrorView(
                  message: s.feedingLoadFailed,
                  onRetry: () =>
                      context.read<FeedingFormCubit>().loadPlans(widget.petId),
                )
              : Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: s.feedingPlanLoading,
                  ),
                ),
        );
      }
      _initialize(options);
      return FeedingFormShell(
        petId: widget.petId,
        petName: widget.petName,
        isPlan: true,
        title: widget.plan == null ? s.createFeedingPlan : s.editFeedingPlan,
        editing: widget.plan != null,
        hasChanges: () => _changed,
        onChanged: () => setState(() {}),
        onSubmit: () => context.read<FeedingFormCubit>().savePlan(
          petId: widget.petId,
          existing: widget.plan,
          startDate: _start,
          endDate: _end,
          meals: [
            for (final meal in _meals)
              FeedingMealDraft(
                id: meal.id,
                scheduledMinute: parseFeedingTime(meal.time.text)!,
                amountGrams: parseFeedingAmount(meal.amount.text)!,
                foodName: meal.food.text,
              ),
          ],
        ),
        steps: [
          AppFormStep(
            title: s.feedingPlan,
            builder: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _locked
                      ? s.feedingPlanEndHint
                      : _plans!.isEmpty
                      ? s.feedingFirstPlanHint
                      : s.feedingChangesHint,
                ),
                const SizedBox(height: 16),
                FormField<DateTime>(
                  validator: (_) => !_locked && _start.isBefore(_minimum)
                      ? s.feedingPlanDateRequired
                      : null,
                  builder: (field) => AppDateField(
                    labelText: s.startDate,
                    value: _start,
                    firstDate: _locked ? _start : _minimum,
                    lastDate: DateTime(2100),
                    readOnly: _locked,
                    errorText: field.errorText,
                    onChanged: (date) {
                      if (date != null) {
                        field.didChange(date);
                        setState(() => _start = date);
                      }
                    },
                  ),
                ),
                for (final (index, meal) in _meals.indexed) _meal(meal, index),
                if (!_locked) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _meals.add(_MealFields())),
                    icon: const Icon(Icons.add),
                    label: Text(s.addMeal),
                  ),
                ],
              ],
            ),
          ),
          AppFormStep(
            title: s.review,
            builder: (_, edit) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_locked ? s.feedingPlanEndHint : s.feedingPlanReview),
                const SizedBox(height: 16),
                AppFormReviewSection(
                  title: s.feedingPlan,
                  leading: const AppFeedingIcon(size: 20),
                  onEdit: () => edit(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppDetailField(
                        label: s.startDate,
                        value: MaterialLocalizations.of(
                          context,
                        ).formatShortDate(_start),
                      ),
                      for (final meal in _meals)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${meal.time.text} · ${s.feedingGrams(parseFeedingAmount(meal.amount.text) == null ? meal.amount.text : feedingAmount(context, parseFeedingAmount(meal.amount.text)!))}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppFormOptionalSection(
                  title: s.endDateOptional,
                  icon: Icons.event_outlined,
                  initiallyExpanded: _locked || _end != null,
                  child: FormField<DateTime>(
                    validator: (_) =>
                        _end != null &&
                            (_end!.isBefore(_start) ||
                                _locked &&
                                    _end!.isBefore(
                                      DateUtils.dateOnly(widget.now()),
                                    ))
                        ? s.feedingEndBeforeStart
                        : null,
                    builder: (field) => AppDateField(
                      labelText: s.endDateOptional,
                      value: _end,
                      firstDate: _locked
                          ? DateUtils.dateOnly(widget.now())
                          : _start,
                      lastDate: DateTime(2100),
                      clearable: true,
                      errorText: field.errorText,
                      onChanged: (date) {
                        field.didChange(date);
                        setState(() => _end = date);
                      },
                    ),
                  ),
                ),
                if (!_locked) ...[
                  const SizedBox(height: 16),
                  AppFormOptionalSection(
                    title: s.foodOptional,
                    icon: Icons.restaurant_menu_outlined,
                    initiallyExpanded: _meals.any(
                      (meal) => meal.food.text.isNotEmpty,
                    ),
                    child: Column(
                      children: [
                        for (final (index, meal) in _meals.indexed)
                          Padding(
                            key: ValueKey(meal.key),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: meal.food,
                              decoration: InputDecoration(
                                labelText: s.feedingMealNumber(index + 1),
                                hintText: s.foodOptional,
                                errorMaxLines: 3,
                              ),
                              validator: (v) =>
                                  (v?.trim().characters.length ?? 0) > 50
                                  ? s.foodNameLimit
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}
