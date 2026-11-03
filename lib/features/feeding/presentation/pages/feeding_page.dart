import 'dart:async';
import 'package:petlytics/core/widgets/app_view_selector.dart';
import 'package:petlytics/core/widgets/app_pet_filter.dart';
import 'package:petlytics/features/feeding/presentation/widgets/feeding_meal_sheet.dart';
import 'package:petlytics/core/widgets/app_feeding_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_occurrence.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_state.dart';
import 'package:petlytics/features/feeding/presentation/utils/feeding_display.dart';
import 'package:petlytics/features/feeding/presentation/widgets/feeding_chart.dart';
import 'package:petlytics/features/all_pets_care/presentation/widgets/care_record_card.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_avatar.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

/// Embedded in either retained navigation root; names come from that root.
class FeedingPage extends StatefulWidget {
  final String? petId;
  final String? petName;
  final List<Pet> pets;
  final FeedingRouteExtra? reminder;
  const FeedingPage({
    super.key,
    this.petId,
    this.petName,
    this.pets = const [],
    this.reminder,
  });
  @override
  State<FeedingPage> createState() => _FeedingPageState();
}

class _FeedingPageState extends State<FeedingPage> with WidgetsBindingObserver {
  GoRouter? _router;
  CareRecordChanges? _changes;
  Timer? _timer;
  bool _dirty = false;
  bool _queued = false;
  bool _confirming = false;
  bool _mealPanelOpen = false;
  String? _filter;
  int _view = 0;
  DateTime? _requestedDate;
  FeedingCubit get _cubit => context.read<FeedingCubit>();
  bool get _global => widget.petId == null;
  bool get _visible =>
      _router?.state.uri.path ==
      (_global ? AppRoutes.allFeeding : AppRoutes.feeding(widget.petId!));
  bool get _busy =>
      _cubit.state is FeedingLoaded &&
      (_cubit.state as FeedingLoaded).pendingAction != null;
  String? get _owner =>
      widget.petId ??
      (_filter != null && widget.pets.any((p) => p.id == _filter)
          ? _filter
          : widget.pets.length == 1
          ? widget.pets.single.id
          : null);
  String? _name(String id) => widget.petId == id
      ? widget.petName
      : widget.pets.where((p) => p.id == id).firstOrNull?.name;
  bool _ownerAvailable(String id) =>
      !_global || widget.pets.any((p) => p.id == id);

  @override
  void initState() {
    super.initState();
    _requestedDate = widget.reminder?.date;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_visible &&
          !_mealPanelOpen &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _cubit.refreshForClockChange();
      }
    });
  }

  @override
  void didUpdateWidget(FeedingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh extra is a new intent, including repeated taps for the same day.
    if (widget.reminder != oldWidget.reminder && widget.reminder != null) {
      _requestedDate = widget.reminder!.date;
      _view = 0;
      _scheduleSync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_scheduleSync);
      _router = router;
      router.routerDelegate.addListener(_scheduleSync);
    }
    final changes = _global ? CareRecordChanges.maybeOf(context) : null;
    if (changes != _changes) {
      _changes?.removeListener(_changed);
      _changes = changes;
      changes?.addListener(_changed);
    }
    _scheduleSync();
  }

  void _changed() {
    final change = _changes?.last;
    if (change == null || change.globalListIsCurrent) return;
    if (change.petDeleted && change.petId != null) {
      _cubit.removeDeletedPet(change.petId!);
    } else if (change.tab == PetCareTab.feeding) {
      if (change.deletedId != null && change.petId != null) {
        _cubit.removeDeletedEntry(change.petId!, change.deletedId!);
      } else {
        _dirty = true;
      }
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || !_visible || _busy || _mealPanelOpen) return;
      final current = _cubit.state;
      if (_requestedDate != null &&
          current is FeedingLoaded &&
          !current.isRefreshing) {
        final date = _requestedDate!;
        _requestedDate = null;
        if (!DateUtils.isSameDay(current.date, date)) {
          _cubit.load(
            petId: widget.petId,
            date: date,
            historyDays: current.historyDays,
          );
          return;
        }
      }
      if (_global && (_dirty || _cubit.state is FeedingInitial)) {
        _dirty = false;
        _reload();
      } else {
        _cubit.refreshForClockChange();
      }
    });
  }

  Future<void> _reload() {
    final state = _cubit.state;
    return _cubit.load(
      petId: widget.petId,
      date: state is FeedingLoaded && !state.followsToday ? state.date : null,
      historyDays: state is FeedingLoaded ? state.historyDays : 7,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _visible &&
        !_busy &&
        !_mealPanelOpen) {
      _reload();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_scheduleSync);
    _changes?.removeListener(_changed);
    super.dispose();
  }

  Future<Pet?> _choosePet() async {
    if (!_global || _busy) return null;
    final selected = widget.pets.where((p) => p.id == _owner).firstOrNull;
    if (selected != null) return selected;
    return showModalBottomSheet<Pet>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context).choosePet,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.pets.length,
                itemBuilder: (_, index) {
                  final pet = widget.pets[index];
                  return ListTile(
                    leading: PetAvatar(pet: pet, size: 40, iconSize: 24),
                    title: Text(pet.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(pet),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _entry([FeedingEntry? entry]) async {
    if (_busy || _confirming) return;
    if (_global && widget.pets.isEmpty) {
      await context.push(AppRoutes.addEditPet);
      return;
    }
    final pet = entry == null && _global ? await _choosePet() : null;
    if (!mounted || _busy) return;
    final id = entry?.petId ?? widget.petId ?? pet?.id;
    if (id == null || !_ownerAvailable(id)) return;
    await context.push(
      AppRoutes.addEditFeedingEntry(id),
      extra: FeedingEntryFormExtra(petId: id, petName: _name(id), entry: entry),
    );
  }

  void _plan(
    FeedingLoaded state,
    String petId, {
    FeedingPlan? plan,
    FeedingPlan? template,
  }) {
    if (_busy || !_ownerAvailable(petId)) return;
    context.push(
      AppRoutes.addEditFeedingPlan(petId),
      extra: FeedingPlanFormExtra(
        petId: petId,
        petName: _name(petId),
        plan: plan,
        template: template,
        plans: state.plans.where((p) => p.petId == petId).toList(),
      ),
    );
  }

  Future<void> _perform(FeedingAction action) async {
    if (_busy || _confirming || !_ownerAvailable(action.petId)) return;
    if (action is DeleteFeedingEntryAction ||
        action is CancelFeedingPlanAction) {
      _confirming = true;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final s = AppLocalizations.of(context);
          final state = _cubit.state;
          final previous =
              state is FeedingLoaded &&
              action is CancelFeedingPlanAction &&
              state.plans.any(
                (p) => p.petId == action.petId && p.id != action.planId,
              );
          return AppConfirmationDialog(
            title: action is DeleteFeedingEntryAction
                ? s.feedingDeleteTitle
                : s.feedingCancelPlanTitle,
            message: action is DeleteFeedingEntryAction
                ? s.feedingDeleteMessage
                : previous
                ? s.feedingCancelPlanMessage
                : s.feedingCancelFirstPlanMessage,
            confirmLabel: action is DeleteFeedingEntryAction
                ? s.deleteAction
                : s.cancelChanges,
          );
        },
      );
      _confirming = false;
      if (!mounted || confirmed != true || _busy) return;
    }
    await _cubit.performAction(action);
  }

  void _publish(FeedingLoaded state) {
    final action = state.lastMutation;
    if (action == null) return;
    final deleted = action is DeleteFeedingEntryAction ? action.entryId : null;
    if (_global) {
      CareRecordChanges.maybeOf(context)?.changed(
        action.petId,
        PetCareTab.feeding,
        deletedId: deleted,
        globalListIsCurrent: true,
      );
    } else {
      PetCareChanges.recordChanged(
        context,
        action.petId,
        PetCareTab.feeding,
        deletedId: deleted,
        listIsCurrent: true,
      );
    }
  }

  Future<void> _date(FeedingLoaded state) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: state.date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (chosen != null && mounted && !_busy) {
      await _cubit.load(
        petId: widget.petId,
        date: chosen,
        historyDays: state.historyDays,
      );
    }
  }

  Widget _heading(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: AppSectionHeading(title: title, icon: icon),
  );
  Widget _empty(String title, String message) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    ),
  );

  Widget _meal(FeedingLoaded state, FeedingOccurrence meal, bool busy) {
    final s = AppLocalizations.of(context);
    final record = meal.entry;
    final canRecord = DateUtils.isSameDay(state.date, state.currentTime);
    final canEdit =
        !busy &&
        !DateUtils.dateOnly(
          meal.date,
        ).isAfter(DateUtils.dateOnly(_cubit.now())) &&
        _ownerAvailable(meal.plan.petId);
    return Card(
      key: ValueKey((meal.plan.petId, meal.meal.id, meal.date)),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit ? () => _openMeal(meal) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_global) ...[
                CarePetIdentity(
                  pet: widget.pets
                      .where((p) => p.id == meal.plan.petId)
                      .firstOrNull,
                ),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final style = Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600);
                  final time = Text(
                    feedingTime(meal.meal.scheduledMinute),
                    style: style,
                  );
                  final amount = Text(
                    s.feedingGrams(
                      feedingAmount(
                        context,
                        record?.amountGrams ?? meal.meal.amountGrams,
                      ),
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  );
                  return constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [time, const SizedBox(height: 8), amount],
                        )
                      : Row(
                          children: [
                            time,
                            const SizedBox(width: 12),
                            Expanded(child: amount),
                          ],
                        );
                },
              ),
              if ((record?.foodName ?? meal.meal.foodName) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text((record?.foodName ?? meal.meal.foodName)!),
                ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: record != null
                      ? TextButton.icon(
                          onPressed: busy || !_ownerAvailable(record.petId)
                              ? null
                              : () => _openMeal(meal),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 20,
                          ),
                          label: Text(
                            s.givenAtEdit(
                              feedingTime(
                                record.givenAt.toLocal().hour * 60 +
                                    record.givenAt.toLocal().minute,
                              ),
                            ),
                          ),
                        )
                      : canRecord
                      ? FilledButton(
                          onPressed: busy || !_ownerAvailable(meal.plan.petId)
                              ? null
                              : () => _cubit.recordMeal(meal),
                          child: Text(s.feedingGiven),
                        )
                      : DateUtils.dateOnly(
                          state.date,
                        ).isAfter(DateUtils.dateOnly(state.currentTime))
                      ? Text(s.scheduled)
                      : Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(s.noDoseRecord),
                            TextButton(
                              onPressed: canEdit ? () => _openMeal(meal) : null,
                              child: Text(s.recordMeal),
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

  Future<void> _openMeal(FeedingOccurrence meal) async {
    if (_busy || _confirming || _mealPanelOpen) return;
    if (!_ownerAvailable(meal.plan.petId) ||
        DateUtils.dateOnly(
          meal.date,
        ).isAfter(DateUtils.dateOnly(_cubit.now()))) {
      return;
    }
    _mealPanelOpen = true;
    try {
      await showFeedingMealSheet(
        context,
        cubit: _cubit,
        meal: meal,
        petIdentity: _global
            ? CarePetIdentity(
                pet: widget.pets
                    .where((p) => p.id == meal.plan.petId)
                    .firstOrNull,
              )
            : null,
      );
    } finally {
      _mealPanelOpen = false;
      if (mounted) _scheduleSync();
    }
  }

  Widget _planCard(FeedingLoaded state, String owner, bool busy) {
    final s = AppLocalizations.of(context);
    final plans = state.plans.where((p) => p.petId == owner).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final today = DateUtils.dateOnly(state.currentTime);
    final started = plans
        .where((p) => !DateUtils.dateOnly(p.startDate).isAfter(today))
        .lastOrNull;
    final current = started != null && started.isActiveOn(today)
        ? started
        : null;
    final pending = plans
        .where((p) => DateUtils.dateOnly(p.startDate).isAfter(today))
        .firstOrNull;
    final visible = current ?? pending ?? plans.lastOrNull;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppSectionHeading(
                    title: s.feedingPlan,
                    leading: AppFeedingIcon(
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (current != null || pending != null)
                  IconButton(
                    tooltip: s.editFeedingPlan,
                    onPressed: busy
                        ? null
                        : () => _plan(
                            state,
                            owner,
                            plan: pending,
                            template: visible,
                          ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (visible == null) ...[
              Text(s.feedingPlanEmptyMessage),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _plan(state, owner),
                icon: const Icon(Icons.add),
                label: Text(s.createFeedingPlan),
              ),
            ] else ...[
              Text(
                current != null
                    ? s.fromDate(
                        MaterialLocalizations.of(
                          context,
                        ).formatShortDate(current.startDate),
                      )
                    : pending != null
                    ? s.startsOn(
                        MaterialLocalizations.of(
                          context,
                        ).formatShortDate(pending.startDate),
                      )
                    : s.endedOn(
                        MaterialLocalizations.of(
                          context,
                        ).formatShortDate(visible.endDate ?? visible.startDate),
                      ),
              ),
              if (current != null || pending != null) ...[
                for (final meal in visible.meals)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${feedingTime(meal.scheduledMinute)} · ${s.feedingGrams(feedingAmount(context, meal.amountGrams))}',
                    ),
                  ),
                if (current?.endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      s.untilDate(
                        MaterialLocalizations.of(
                          context,
                        ).formatShortDate(current!.endDate!),
                      ),
                    ),
                  ),
              ],
              if (pending != null) ...[
                if (current != null) ...[
                  const Divider(height: 32),
                  Text(
                    s.changesFromDate(
                      MaterialLocalizations.of(
                        context,
                      ).formatShortDate(pending.startDate),
                    ),
                  ),
                  for (final meal in pending.meals)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${feedingTime(meal.scheduledMinute)} · ${s.feedingGrams(feedingAmount(context, meal.amountGrams))}',
                      ),
                    ),
                ],
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => _perform(
                          CancelFeedingPlanAction(owner, pending.id),
                        ),
                  icon: const Icon(Icons.close, size: 20),
                  label: Text(s.cancelChanges),
                ),
              ],
              if (current != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _plan(state, owner, plan: current),
                  child: Text(
                    current.endDate == null
                        ? s.endFeedingPlan
                        : s.feedingEditEndDate,
                  ),
                )
              else if (pending == null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _plan(state, owner, template: visible),
                    icon: const Icon(Icons.add),
                    label: Text(s.createFeedingPlan),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateControls(FeedingLoaded state, bool busy) {
    final s = AppLocalizations.of(context);
    final today = DateUtils.isSameDay(state.date, state.currentTime);
    void move(int delta) => _cubit.load(
      petId: widget.petId,
      date: DateTime(state.date.year, state.date.month, state.date.day + delta),
      historyDays: state.historyDays,
    );
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: s.previousDay,
              onPressed: busy ? null : () => move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton(
                onPressed: busy ? null : () => _date(state),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      today
                          ? s.today
                          : MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(state.date),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (today)
                      Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(state.date),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: s.nextDay,
              onPressed: busy ? null : () => move(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (!today)
          TextButton(
            onPressed: busy
                ? null
                : () => _cubit.load(
                    petId: widget.petId,
                    historyDays: state.historyDays,
                  ),
            child: Text(s.backToToday),
          ),
      ],
    );
  }

  Widget _historyEntry(FeedingEntry entry, bool busy) {
    final s = AppLocalizations.of(context);
    final time = entry.givenAt.toLocal();
    return ListTile(
      key: ValueKey(entry.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(s.feedingGrams(feedingAmount(context, entry.amountGrams))),
      subtitle: Text(
        [
          if (_global) _name(entry.petId) ?? s.petUnavailable,
          feedingTime(time.hour * 60 + time.minute),
          if (entry.foodName != null) entry.foodName!,
        ].join('\n'),
      ),
      onTap: busy || !_ownerAvailable(entry.petId) ? null : () => _entry(entry),
      trailing: IconButton(
        tooltip: s.feedingDeleteTitle,
        onPressed: busy
            ? null
            : () => _perform(DeleteFeedingEntryAction(entry.petId, entry.id)),
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }

  Widget _views(bool busy) {
    final s = AppLocalizations.of(context);
    return AppViewSelector(
      labels: [s.dailyMeals, s.feedingPlans, s.history],
      selectedIndex: _view,
      onSelected: busy
          ? null
          : (index) {
              if (!_busy) setState(() => _view = index);
            },
    );
  }

  Widget _content(FeedingLoaded state, bool busy) {
    final s = AppLocalizations.of(context);
    if (_global && widget.pets.isEmpty) {
      return CareEmptyView(
        icon: Icons.pets_outlined,
        title: s.noPetsYet,
        message: s.petsEmptyDescription,
      );
    }
    final owner = _owner;
    final meals = state.meals
        .where((m) => owner == null || m.plan.petId == owner)
        .toList();
    final entries = state.entries
        .where((e) => owner == null || e.petId == owner)
        .toList();
    final otherToday = entries
        .where(
          (e) =>
              e.mealId == null &&
              DateUtils.isSameDay(e.givenAt.toLocal(), state.date),
        )
        .toList();
    final byDay = <DateTime, List<FeedingEntry>>{};
    for (final entry in entries) {
      (byDay[DateUtils.dateOnly(entry.givenAt.toLocal())] ??= []).add(entry);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return CustomScrollView(
      key: PageStorageKey(('feeding', widget.petId, _view)),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_global && widget.pets.length > 1) ...[
                  AppPetFilter(
                    pets: widget.pets,
                    selectedPetId: _filter,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_global) ...[_views(busy), const SizedBox(height: 16)],
                if (_view != 1) _dateControls(state, busy),
              ],
            ),
          ),
        ),
        if (_view == 0) ...[
          if (meals.isEmpty && otherToday.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppFeedingIcon(
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.feedingNoMeals,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.feedingNoMealsDescription,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: meals.length,
                itemBuilder: (_, i) => _meal(state, meals[i], busy),
              ),
            ),
            if (otherToday.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: _heading(s.feedingExtraRecords, Icons.history),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList.builder(
                  itemCount: otherToday.length,
                  itemBuilder: (_, i) =>
                      Card(child: _historyEntry(otherToday[i], busy)),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 128)),
          ],
        ],
        if (_view == 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 128),
            sliver: SliverList.list(
              children: [
                for (final id
                    in owner == null
                        ? widget.pets.map((p) => p.id)
                        : [owner]) ...[
                  if (_global)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CarePetIdentity(
                        pet: widget.pets.where((p) => p.id == id).firstOrNull,
                      ),
                    ),
                  _planCard(state, id, busy),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        if (_view == 2) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            sliver: SliverToBoxAdapter(
              child: owner == null
                  ? _empty(s.feedingTrend, s.feedingChartSelectPet)
                  : FeedingChart(
                      totals: _cubit.totalsFor(owner),
                      days: state.historyDays,
                      busy: busy,
                      onRangeChanged: (days) => _cubit.load(
                        petId: widget.petId,
                        date: state.followsToday ? null : state.date,
                        historyDays: days,
                      ),
                    ),
            ),
          ),
          if (days.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 128),
              sliver: SliverToBoxAdapter(
                child: _empty(
                  s.feedingNoRecords,
                  s.feedingNoRecordsDescription,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 128),
            sliver: SliverList.builder(
              itemCount: days.length,
              itemBuilder: (_, i) {
                final day = days[i];
                final records = byDay[day]!;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    key: PageStorageKey((
                      'feeding-history',
                      widget.petId,
                      owner,
                      day,
                    )),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    initiallyExpanded: false,
                    title: Text(
                      MaterialLocalizations.of(context).formatMediumDate(day),
                    ),
                    subtitle: Text(s.feedingRecordsCount(records.length)),
                    children: [
                      for (final entry in records) _historyEntry(entry, busy),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<FeedingCubit, FeedingState>(
    listenWhen: (before, after) =>
        after is FeedingLoaded &&
        after.mutationRevision !=
            (before is FeedingLoaded ? before.mutationRevision : 0),
    listener: (_, state) => _publish(state as FeedingLoaded),
    builder: (context, state) {
      final s = AppLocalizations.of(context);
      final busy =
          state is FeedingLoaded &&
          (state.pendingAction != null ||
              state.isRefreshing ||
              state.refreshFailure != null);
      if (_requestedDate != null &&
          state is FeedingLoaded &&
          !state.isRefreshing) {
        _scheduleSync();
      }
      return PopScope(
        canPop: !_busy,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          floatingActionButton:
              state is FeedingLoaded &&
                  (_view != 1 || _global && widget.pets.isEmpty)
              ? FloatingActionButton.extended(
                  heroTag: ('feeding-add', widget.petId),
                  onPressed: busy ? null : () => _entry(),
                  icon: const Icon(Icons.add),
                  isExtended: MediaQuery.textScalerOf(context).scale(14) <= 21,
                  tooltip: _global && widget.pets.isEmpty
                      ? s.addPet
                      : s.addFeeding,
                  label: Text(
                    _global && widget.pets.isEmpty ? s.addPet : s.addFeeding,
                  ),
                )
              : null,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (state is FeedingLoaded && state.refreshFailure != null)
                  Flexible(
                    child: AppErrorFeedback(
                      message: s.feedingLoadFailed,
                      onRetry: _busy ? null : _cubit.retryLoad,
                    ),
                  ),
                if (state is FeedingLoaded && state.actionFailure != null)
                  Flexible(
                    child: AppErrorFeedback(
                      message: switch (state.failedAction) {
                        DeleteFeedingEntryAction() => s.feedingDeleteFailed,
                        CancelFeedingPlanAction() => s.feedingPlanCancelFailed,
                        _ => s.feedingSaveFailed,
                      },
                      onRetry: _busy || state.isRefreshing
                          ? null
                          : () {
                              final action =
                                  (_cubit.state as FeedingLoaded).failedAction;
                              if (action != null) _perform(action);
                            },
                    ),
                  ),
                if (state is FeedingLoaded && !_global)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: _views(busy),
                  ),
                Expanded(
                  child: state is FeedingLoaded
                      ? Stack(
                          children: [
                            _content(state, busy),
                            if (state.isRefreshing ||
                                state.pendingAction != null)
                              const Align(
                                alignment: Alignment.topCenter,
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                          ],
                        )
                      : state is FeedingError
                      ? ErrorView(
                          message: s.feedingLoadFailed,
                          onRetry: _cubit.retryLoad,
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
