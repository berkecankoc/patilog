import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_meal.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_plan.dart';
import 'package:patilog/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_form_state.dart';

final class FeedingMealDraft {
  final String? id;
  final int scheduledMinute;
  final double amountGrams;
  final String? foodName;

  const FeedingMealDraft({
    this.id,
    required this.scheduledMinute,
    required this.amountGrams,
    this.foodName,
  });
}

final class FeedingFormCubit extends Cubit<FeedingFormState> {
  final FeedingRepository _repository;
  final IdGenerator _ids;
  int _plansRequest = 0;

  FeedingFormCubit(this._repository, this._ids)
    : super(const FeedingFormState());

  bool get _canSave => !isClosed && !state.isSaving && !state.isSaved;

  Future<void> loadPlans(String petId) async {
    if (!_canSave) return;
    final request = ++_plansRequest;
    emit(
      state.copyWith(
        plansPetId: petId,
        plans: const [],
        hasLoadedPlans: false,
        isLoadingPlans: true,
        clearPlansFailure: true,
      ),
    );
    final result = await _repository.getFeedingPlans(petId);
    if (isClosed || state.isSaved || request != _plansRequest) return;
    switch (result) {
      case Success<List<FeedingPlan>>():
        emit(
          state.copyWith(
            plans: List.unmodifiable(result.data),
            hasLoadedPlans: true,
            isLoadingPlans: false,
          ),
        );
      case Error<List<FeedingPlan>>():
        emit(
          state.copyWith(isLoadingPlans: false, plansFailure: result.failure),
        );
    }
  }

  Future<void> savePlan({
    required String petId,
    FeedingPlan? existing,
    required DateTime startDate,
    DateTime? endDate,
    required List<FeedingMealDraft> meals,
  }) async {
    if (!_canSave) return;
    if (existing != null &&
        (existing.petId != petId ||
            meals.any(
              (meal) =>
                  meal.id != null &&
                  !existing.meals.any((old) => old.id == meal.id),
            ))) {
      emit(
        const FeedingFormState(
          saveFailure: NotFoundFailure('Feeding plan not found'),
        ),
      );
      return;
    }
    final id = existing?.id ?? _ids.generate();
    final plan = FeedingPlan(
      id: id,
      petId: petId,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: endDate == null
          ? null
          : DateTime(endDate.year, endDate.month, endDate.day),
      meals: [
        for (final meal in meals)
          FeedingMeal(
            id: existing == null ? _ids.generate() : meal.id ?? _ids.generate(),
            planId: id,
            scheduledMinute: meal.scheduledMinute,
            amountGrams: meal.amountGrams,
            foodName: _optionalText(meal.foodName),
          ),
      ],
    );
    await _save(
      () => existing == null
          ? _repository.createFeedingPlan(plan)
          : _repository.updateFeedingPlan(plan),
      plan: plan,
    );
  }

  Future<void> saveEntry({
    required String petId,
    FeedingEntry? existing,
    required double amountGrams,
    required DateTime givenAt,
    String? foodName,
    String? notes,
  }) async {
    if (!_canSave) return;
    if (existing != null && existing.petId != petId) {
      emit(
        const FeedingFormState(
          saveFailure: NotFoundFailure('Feeding entry not found'),
        ),
      );
      return;
    }
    final entry = FeedingEntry(
      id: existing?.id ?? _ids.generate(),
      petId: petId,
      amountGrams: amountGrams,
      givenAt: givenAt,
      foodName: _optionalText(foodName),
      notes: _optionalText(notes),
      mealId: existing?.mealId,
      scheduledDate: existing?.scheduledDate,
    );
    await _save(
      () => existing == null
          ? _repository.createFeedingEntry(entry)
          : _repository.updateFeedingEntry(entry),
      entry: entry,
    );
  }

  Future<void> _save(
    Future<Result<void>> Function() write, {
    FeedingPlan? plan,
    FeedingEntry? entry,
  }) async {
    emit(state.copyWith(isSaving: true, clearSaveFailure: true));
    final result = await write();
    if (isClosed) return;
    switch (result) {
      case Success<void>():
        ++_plansRequest;
        emit(
          state.copyWith(
            isSaving: false,
            savedPlan: plan,
            savedEntry: entry,
            isLoadingPlans: false,
          ),
        );
      case Error<void>():
        emit(state.copyWith(isSaving: false, saveFailure: result.failure));
    }
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
