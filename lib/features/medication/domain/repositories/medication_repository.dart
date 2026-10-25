import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_suggestions.dart';

/// Record operations must match the pet, medication, period and scheduled dose.
/// A missing match returns NotFoundFailure. Writes validate ownership and rules
/// transactionally, including visits belonging to the same pet.
/// Medication names are trimmed, nonempty and at most 50 characters. Optional text is
/// trimmed to null when blank; dosage instructions allow 100 characters and
/// notes 200. Limits count user-perceived characters.
abstract interface class MedicationRepository {
  /// Newest insertion first; edits preserve insertion order. Each medication
  /// includes all periods, start date ascending, even when filtered by visit.
  Future<Result<List<Medication>>> getMedications(
    String petId, {
    String? vetVisitId,
  });

  /// All pets' medications, newest insertion first, with all ordered periods.
  Future<Result<List<Medication>>> getAllMedications();

  Future<Result<Medication>> getMedicationById(
    String petId,
    String medicationId,
  );

  /// Atomically creates the medication and exactly one matching initial period.
  /// Initial use may start in the past. Periods require a positive day interval,
  /// nonempty unique minutes in 0–1439 and an end on/after their start, if set.
  Future<Result<void>> createMedication(Medication medication);

  Future<Result<void>> renameMedication(
    String petId,
    String medicationId,
    String name,
  );

  /// Removes its periods and dose results; deleting a pet removes all three.
  Future<Result<void>> deleteMedication(String petId, String medicationId);

  /// Additional periods start after today with a unique start per medication.
  /// Effective end is the earlier of the stored end and the day before the next
  /// period; calendar-day intervals are anchored to each period's own start.
  /// When supplied, the medication name changes in the same transaction.
  Future<Result<void>> createPeriod(
    String petId,
    MedicationPeriod period, {
    String? medicationName,
  });

  /// A period with dose results locks its start, interval, times and dosage.
  /// Other details can be corrected; all results must remain valid scheduled
  /// doses after any update. Moving an additional period into the past is not
  /// allowed. Changing a linked visit never moves the medication's dates/logs.
  Future<Result<void>> updatePeriod(
    String petId,
    MedicationPeriod period, {
    String? medicationName,
  });

  /// Checks the period's edit lock without loading its dose history.
  Future<Result<bool>> hasDoseLogs(
    String petId,
    String medicationId,
    String periodId,
  );

  /// Only unstarted periods can be removed, with at least one period remaining.
  /// Removing a later period may allow the previous plan to continue; existing
  /// dose results must be preserved.
  Future<Result<void>> deletePeriod(
    String petId,
    String medicationId,
    String periodId,
  );

  /// Inclusive scheduled calendar-day range, ordered by day, minute and period
  /// ID. Only saved results are returned; absence never implies skipped.
  /// fromDate must be on/before toDate. Omitting medicationId reads this pet's
  /// results across all medications.
  Future<Result<List<MedicationDoseLog>>> getDoseLogs(
    String petId, {
    String? medicationId,
    required DateTime fromDate,
    required DateTime toDate,
  });

  /// All pets' saved results in the inclusive calendar-day range. Uses the same
  /// ordering/range rules as getDoseLogs; periodId identifies the owning plan.
  Future<Result<List<MedicationDoseLog>>> getAllDoseLogs({
    required DateTime fromDate,
    required DateTime toDate,
  });

  /// Inserts or corrects the unique period/day/minute result of a valid dose.
  /// Only scheduled days on/before today can be recorded. Given requires a
  /// nonfuture givenAt; skipped requires null. No result means "No record".
  Future<Result<void>> saveDoseLog(
    String petId,
    String medicationId,
    MedicationDoseLog log,
  );

  /// Removes the result, leaving the scheduled dose in the plan.
  Future<Result<void>> clearDoseLog(
    String petId,
    String medicationId, {
    required String periodId,
    required DateTime scheduledDate,
    required int scheduledMinute,
  });

  /// Saved names across pets. Medication names come from medications; clinic
  /// and vet names share the visit/vaccination/medication-period pool. Deduplicate
  /// case/whitespace variants and sort by name; vets match the clinic, or all
  /// if blank/null.
  Future<Result<MedicationSuggestions>> getSuggestions({String? clinicName});
}
