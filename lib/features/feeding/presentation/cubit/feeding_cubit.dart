import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_daily_total.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_occurrence.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';
import 'package:petlytics/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:petlytics/features/feeding/domain/use_cases/calculate_feeding_meals.dart';
import 'package:petlytics/features/feeding/domain/use_cases/calculate_feeding_totals.dart';
import 'package:petlytics/features/feeding/domain/utils/feeding_calendar.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_state.dart';

typedef _FeedingQuery = ({
  String? petId,
  DateTime date,
  int historyDays,
  bool followsToday,
});

final class FeedingCubit extends Cubit<FeedingState> {
  final FeedingRepository _repository;
  final IdGenerator _ids;
  final CalculateFeedingMeals _calculateMeals;
  final CalculateFeedingTotals _calculateTotals;
  final DateTime Function() now;
  int _request = 0;
  _FeedingQuery? _failedQuery;
  final _removedPets = <String>{};
  final _removedEntries = <(String, String)>{};

  FeedingCubit(
    this._repository,
    this._ids,
    this._calculateMeals,
    this._calculateTotals, {
    this.now = DateTime.now,
  }) : super(const FeedingInitial());

  Future<void> load({String? petId, DateTime? date, int historyDays = 7}) {
    final current = now();
    final day = date ?? current;
    return _load((
      petId: petId,
      date: DateTime(day.year, day.month, day.day),
      historyDays: historyDays,
      followsToday: feedingDayNumber(day) == feedingDayNumber(current),
    ));
  }

  Future<void> _load(_FeedingQuery query) async {
    if (isClosed ||
        state is FeedingLoaded &&
            (state as FeedingLoaded).pendingAction != null) {
      return;
    }
    assert(query.historyDays == 7 || query.historyDays == 30);
    final request = ++_request;
    final previous =
        state is FeedingLoaded && (state as FeedingLoaded).petId == query.petId
        ? state as FeedingLoaded
        : null;
    _failedQuery = null;
    emit(
      previous == null
          ? const FeedingLoading()
          : previous.copyWith(isRefreshing: true, clearRefreshFailure: true),
    );
    final from = DateTime(
      query.date.year,
      query.date.month,
      query.date.day - query.historyDays + 1,
    );
    final before = DateTime(
      query.date.year,
      query.date.month,
      query.date.day + 1,
    );
    final plansFuture = query.petId == null
        ? _repository.getAllFeedingPlans()
        : _repository.getFeedingPlans(query.petId!);
    final entriesFuture = query.petId == null
        ? _repository.getAllFeedingEntries(from: from, before: before)
        : _repository.getFeedingEntries(
            query.petId!,
            from: from,
            before: before,
          );
    final plannedFuture = query.petId == null
        ? _repository.getAllPlannedFeedingEntries(
            fromDate: query.date,
            toDate: query.date,
          )
        : _repository.getPlannedFeedingEntries(
            query.petId!,
            fromDate: query.date,
            toDate: query.date,
          );
    final plansResult = await plansFuture;
    final entriesResult = await entriesFuture;
    final plannedResult = await plannedFuture;
    if (isClosed || request != _request) return;
    final failure = [
      plansResult,
      entriesResult,
      plannedResult,
    ].whereType<Error>().firstOrNull?.failure;
    if (failure != null) {
      _failedQuery = query;
      final retained = state;
      emit(
        retained is FeedingLoaded
            ? retained.copyWith(isRefreshing: false, refreshFailure: failure)
            : FeedingError(failure),
      );
      return;
    }
    final plans = _remainingPlans(
      (plansResult as Success<List<FeedingPlan>>).data,
    );
    final entries = _remainingEntries(
      (entriesResult as Success<List<FeedingEntry>>).data,
    );
    final planned = _remainingEntries(
      (plannedResult as Success<List<FeedingEntry>>).data,
    );
    emit(
      FeedingLoaded(
        petId: query.petId,
        date: query.date,
        currentTime: now(),
        historyDays: query.historyDays,
        followsToday: query.followsToday,
        plans: plans,
        entries: entries,
        plannedEntries: planned,
        meals: _meals(plans, planned, query.date),
        lastMutation: previous?.lastMutation,
        mutationRevision: previous?.mutationRevision ?? 0,
        failedAction: previous?.date == query.date
            ? previous?.failedAction
            : null,
        actionFailure: previous?.date == query.date
            ? previous?.actionFailure
            : null,
      ),
    );
  }

  Future<void> retryLoad() async {
    final query = _failedQuery;
    if (query != null) await _load(query);
  }

  void dismissActionFailure() {
    final loaded = state;
    if (!isClosed && loaded is FeedingLoaded && loaded.pendingAction == null) {
      emit(loaded.copyWith(clearActionFailure: true));
    }
  }

  List<FeedingDailyTotal> totalsFor(String petId) {
    final loaded = state;
    if (loaded is! FeedingLoaded ||
        loaded.petId != null && loaded.petId != petId) {
      return const [];
    }
    return _calculateTotals(
      petId: petId,
      entries: loaded.entries,
      fromDate: loaded.fromDate,
      toDate: loaded.date,
    );
  }

  Future<void> recordMeal(FeedingOccurrence occurrence) async {
    if (isClosed) return;
    final loaded = state;
    final current = now();
    if (loaded is! FeedingLoaded ||
        loaded.isRefreshing ||
        loaded.refreshFailure != null ||
        loaded.pendingAction != null ||
        feedingDayNumber(loaded.date) != feedingDayNumber(current)) {
      return;
    }
    final canonical = currentMeal(occurrence);
    if (canonical == null || canonical.entry != null) return;
    await saveMeal(
      canonical,
      amountGrams: canonical.meal.amountGrams,
      givenAt: current,
    );
  }

  FeedingOccurrence? currentMeal(FeedingOccurrence occurrence) {
    final loaded = state;
    if (loaded is! FeedingLoaded) return null;
    return loaded.meals
        .where(
          (meal) =>
              meal.plan.petId == occurrence.plan.petId &&
              meal.meal.id == occurrence.meal.id &&
              feedingDayNumber(meal.date) == feedingDayNumber(occurrence.date),
        )
        .firstOrNull;
  }

  Future<bool> saveMeal(
    FeedingOccurrence occurrence, {
    required double amountGrams,
    required DateTime givenAt,
  }) async {
    if (isClosed || state is! FeedingLoaded) return false;
    final loaded = state as FeedingLoaded;
    if (loaded.pendingAction != null ||
        loaded.isRefreshing ||
        loaded.refreshFailure != null) {
      return false;
    }
    final canonical = currentMeal(occurrence);
    if (canonical == null ||
        givenAt.isAfter(now()) ||
        canonical.entry?.id != occurrence.entry?.id ||
        feedingDayNumber(canonical.date) > feedingDayNumber(now())) {
      return false;
    }
    final existing = canonical.entry;
    final entry = FeedingEntry(
      id: existing?.id ?? _ids.generate(),
      petId: canonical.plan.petId,
      amountGrams: amountGrams,
      foodName: existing == null ? canonical.meal.foodName : existing.foodName,
      notes: existing?.notes,
      givenAt: givenAt,
      mealId: canonical.meal.id,
      scheduledDate: canonical.date,
    );
    if (entry == existing) return true;
    final action = existing == null
        ? RecordFeedingMealAction(entry)
        : UpdateFeedingMealAction(entry);
    await performAction(action);
    if (isClosed) return false;
    final after = state;
    return after is FeedingLoaded &&
        after.mutationRevision > loaded.mutationRevision &&
        after.lastMutation == action;
  }

  Future<void> performAction(FeedingAction action) async {
    if (isClosed) return;
    final loaded = state;
    if (loaded is! FeedingLoaded ||
        loaded.pendingAction != null ||
        loaded.isRefreshing ||
        !_canPerform(loaded, action)) {
      return;
    }
    ++_request;
    emit(loaded.copyWith(pendingAction: action, clearActionFailure: true));
    final result = await switch (action) {
      RecordFeedingMealAction(:final entry) => _repository.createFeedingEntry(
        entry,
      ),
      UpdateFeedingMealAction(:final entry) => _repository.updateFeedingEntry(
        entry,
      ),
      DeleteFeedingEntryAction(:final entryId) =>
        _repository.deleteFeedingEntry(action.petId, entryId),
      CancelFeedingPlanAction(:final planId) => _repository.deleteFeedingPlan(
        action.petId,
        planId,
      ),
    };
    if (isClosed) return;
    switch (result) {
      case Error<void>():
        emit(
          loaded.copyWith(failedAction: action, actionFailure: result.failure),
        );
      case Success<void>():
        var entries = loaded.entries.toList();
        final planned = loaded.plannedEntries.toList();
        final plans = loaded.plans.toList();
        switch (action) {
          case RecordFeedingMealAction(:final entry):
            planned.add(entry);
            if (!entry.givenAt.isBefore(loaded.fromDate) &&
                entry.givenAt.isBefore(loaded.before)) {
              entries.insert(0, entry);
              // Stable sorting preserves the newest insertion for equal instants.
              final sorted = entries.indexed.toList()
                ..sort((a, b) {
                  final time = b.$2.givenAt.compareTo(a.$2.givenAt);
                  return time != 0 ? time : a.$1.compareTo(b.$1);
                });
              entries = sorted.map((item) => item.$2).toList();
            }
          case UpdateFeedingMealAction(:final entry):
            final index = entries.indexWhere(
              (e) => e.id == entry.id && e.petId == entry.petId,
            );
            if (!entry.givenAt.isBefore(loaded.fromDate) &&
                entry.givenAt.isBefore(loaded.before)) {
              if (index >= 0) {
                entries[index] = entry;
              } else {
                entries.add(entry);
              }
            } else if (index >= 0) {
              entries.removeAt(index);
            }
            planned.removeWhere(
              (e) => e.id == entry.id && e.petId == entry.petId,
            );
            planned.add(entry);
            // Keep existing ties stable when only amount or clock time is corrected.
            final sorted = entries.indexed.toList()
              ..sort((a, b) {
                final time = b.$2.givenAt.compareTo(a.$2.givenAt);
                return time != 0 ? time : a.$1.compareTo(b.$1);
              });
            entries = sorted.map((e) => e.$2).toList();
          case DeleteFeedingEntryAction(:final entryId):
            entries.removeWhere(
              (e) => e.petId == action.petId && e.id == entryId,
            );
            planned.removeWhere(
              (e) => e.petId == action.petId && e.id == entryId,
            );
          case CancelFeedingPlanAction(:final planId):
            plans.removeWhere((p) => p.petId == action.petId && p.id == planId);
        }
        emit(
          loaded.copyWith(
            plans: plans,
            entries: entries,
            plannedEntries: planned,
            meals: _meals(plans, planned, loaded.date),
            currentTime: now(),
            clearPendingAction: true,
            clearActionFailure: true,
            lastMutation: action,
            mutationRevision: loaded.mutationRevision + 1,
          ),
        );
        await refreshForClockChange();
    }
  }

  bool _canPerform(FeedingLoaded loaded, FeedingAction action) {
    if (loaded.refreshFailure != null) return false;
    if (loaded.petId != null && loaded.petId != action.petId) return false;
    switch (action) {
      case UpdateFeedingMealAction(:final entry):
        return !entry.givenAt.isAfter(now()) &&
            loaded.meals.any(
              (meal) =>
                  meal.plan.petId == entry.petId &&
                  meal.meal.id == entry.mealId &&
                  meal.entry?.id == entry.id &&
                  entry.scheduledDate != null &&
                  feedingDayNumber(meal.date) ==
                      feedingDayNumber(entry.scheduledDate!) &&
                  feedingDayNumber(meal.date) <= feedingDayNumber(now()),
            );
      case RecordFeedingMealAction(:final entry):
        return !entry.givenAt.isAfter(now()) &&
            loaded.meals.any(
              (meal) =>
                  meal.plan.petId == entry.petId &&
                  meal.meal.id == entry.mealId &&
                  entry.scheduledDate != null &&
                  feedingDayNumber(meal.date) ==
                      feedingDayNumber(entry.scheduledDate!) &&
                  feedingDayNumber(meal.date) <= feedingDayNumber(now()) &&
                  meal.entry == null,
            );
      case DeleteFeedingEntryAction(:final entryId):
        return [
          ...loaded.entries,
          ...loaded.plannedEntries,
        ].any((e) => e.petId == action.petId && e.id == entryId);
      case CancelFeedingPlanAction(:final planId):
        return loaded.plans.any(
          (p) =>
              p.petId == action.petId &&
              p.id == planId &&
              feedingDayNumber(p.startDate) > feedingDayNumber(now()),
        );
    }
  }

  /// Called only by an active screen's clock/lifecycle observer.
  Future<void> refreshForClockChange() async {
    if (isClosed) return;
    final loaded = state;
    if (loaded is! FeedingLoaded ||
        loaded.pendingAction != null ||
        loaded.isRefreshing) {
      return;
    }
    final current = now();
    final dayChanged =
        feedingDayNumber(loaded.currentTime) != feedingDayNumber(current);
    if (loaded.failedAction == null &&
        (dayChanged ||
            loaded.followsToday &&
                feedingDayNumber(loaded.date) != feedingDayNumber(current))) {
      await load(
        petId: loaded.petId,
        historyDays: loaded.historyDays,
        date: loaded.followsToday ? null : loaded.date,
      );
    } else {
      emit(loaded.copyWith(currentTime: current));
    }
  }

  void removeDeletedPet(String petId) {
    _removedPets.add(petId);
    _removeKnown();
  }

  void removeDeletedEntry(String petId, String entryId) {
    _removedEntries.add((petId, entryId));
    _removeKnown();
  }

  void _removeKnown() {
    if (isClosed || state is! FeedingLoaded) return;
    final loaded = state as FeedingLoaded;
    final plans = _remainingPlans(loaded.plans);
    final entries = _remainingEntries(loaded.entries);
    final planned = _remainingEntries(loaded.plannedEntries);
    emit(
      loaded.copyWith(
        plans: plans,
        entries: entries,
        plannedEntries: planned,
        meals: _meals(plans, planned, loaded.date),
      ),
    );
  }

  List<FeedingPlan> _remainingPlans(List<FeedingPlan> plans) =>
      plans.where((p) => !_removedPets.contains(p.petId)).toList();
  List<FeedingEntry> _remainingEntries(List<FeedingEntry> entries) => entries
      .where(
        (e) =>
            !_removedPets.contains(e.petId) &&
            !_removedEntries.contains((e.petId, e.id)),
      )
      .toList();

  List<FeedingOccurrence> _meals(
    List<FeedingPlan> plans,
    List<FeedingEntry> entries,
    DateTime date,
  ) => _calculateMeals(
    plans: plans,
    entries: entries,
    fromDate: date,
    toDate: date,
  );
}
