import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_entry.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';

/// Writes validate pet/plan/meal ownership transactionally; missing or foreign
/// records return NotFoundFailure. Amounts are finite, positive grams with at
/// most one decimal. Food names (50 graphemes) and notes (200) are trimmed;
/// blank optional text is stored as null.
/// Deleting a pet removes its plans, meals and entries.
abstract interface class FeedingRepository {
  /// All versions, start date ascending, with meals ordered by local minute.
  Future<Result<List<FeedingPlan>>> getFeedingPlans(String petId);

  /// All pets' versions, pet ID then start date ascending.
  Future<Result<List<FeedingPlan>>> getAllFeedingPlans();

  Future<Result<FeedingPlan>> getFeedingPlanById(String petId, String planId);

  /// Atomically saves the plan and its matching meals. The first plan starts
  /// today or later; successors start after today, with a unique start per pet.
  /// Meals require unique IDs/minutes, at least one meal and minutes in 0–1439.
  /// A successor ends the preceding version's effective window permanently.
  Future<Result<void>> createFeedingPlan(FeedingPlan plan);

  /// Unstarted plans can be edited; started versions retain their start/meals.
  /// The current plan can end today or later, retaining every recorded meal.
  /// An explicit end must be on/after the start. Insertion order is preserved.
  Future<Result<void>> updateFeedingPlan(FeedingPlan plan);

  /// Cancels only an unstarted version; earlier versions and all entries remain.
  Future<Result<void>> deleteFeedingPlan(String petId, String planId);

  /// Actual givenAt instants in [from, before), newest first. Ties prefer latest
  /// insertion; correcting content does not change insertion order. Requires
  /// from < before; callers supply instants bounding the desired local days.
  Future<Result<List<FeedingEntry>>> getFeedingEntries(
    String petId, {
    required DateTime from,
    required DateTime before,
  });

  Future<Result<List<FeedingEntry>>> getAllFeedingEntries({
    required DateTime from,
    required DateTime before,
  });

  /// Linked entries in an inclusive scheduled calendar-day range, using the
  /// same entry ordering. Requires fromDate <= toDate. Completion/reminders
  /// follow this day, not givenAt; absence means no record, never zero food.
  Future<Result<List<FeedingEntry>>> getPlannedFeedingEntries(
    String petId, {
    required DateTime fromDate,
    required DateTime toDate,
  });

  Future<Result<List<FeedingEntry>>> getAllPlannedFeedingEntries({
    required DateTime fromDate,
    required DateTime toDate,
  });

  /// givenAt cannot be future. mealId/scheduledDate must be paired; a linked
  /// meal must be scheduled for this pet on/before today. A second entry for
  /// the same meal/day fails without overwriting the existing result.
  Future<Result<void>> createFeedingEntry(FeedingEntry entry);

  /// Retains pet, ID, mealId/scheduledDate and insertion order. Amount, actual
  /// time and text snapshots can be corrected without changing the plan.
  Future<Result<void>> updateFeedingEntry(FeedingEntry entry);

  Future<Result<void>> deleteFeedingEntry(String petId, String entryId);
}
