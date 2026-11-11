import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination_suggestions.dart';

/// Single-record reads, updates and deletes must match both pet and record IDs.
/// A missing match returns NotFoundFailure. Linked visits must belong to the pet.
/// Linked administration and visit dates must be the same calendar day.
/// Writes require planned dates on/after today and administered dates on/before
/// today. Existing overdue plans can still be read.
/// Reminder settings are saved atomically with their vaccination.
abstract interface class VaccinationRepository {
  /// Planned records first (date ascending), then history (date descending).
  /// Ties use newest insertion first; content edits do not change insertion order.
  Future<Result<List<Vaccination>>> getVaccinations(
    String petId, {
    String? vetVisitId,
  });

  /// All pets' records, using the same planned/history order as getVaccinations.
  Future<Result<List<Vaccination>>> getAllVaccinations();

  Future<Result<Vaccination>> getVaccinationById(
    String petId,
    String vaccinationId,
  );

  /// Saves both records atomically when [nextDose] is supplied.
  /// The next dose must be a distinct planned record for the same pet and vaccine,
  /// dated after an administered [vaccination]; it stays independent afterwards.
  Future<Result<void>> createVaccination(
    Vaccination vaccination, {
    Vaccination? nextDose,
  });

  /// Preserves insertion order. An optional [nextDose] follows the creation rules
  /// and is saved atomically, only when changing a planned record to administered.
  Future<Result<void>> updateVaccination(
    Vaccination vaccination, {
    Vaccination? nextDose,
  });

  Future<Result<void>> deleteVaccination(String petId, String vaccinationId);

  /// Saved vaccine names across all pets; clinic/vet names also include vet visits.
  /// Non-blank names are deduplicated and sorted case-insensitively.
  /// Returns all vaccines and clinics; vets match the clinic ignoring case and
  /// normalized whitespace, or include all when [clinicName] is blank/null.
  Future<Result<VaccinationSuggestions>> getSuggestions({String? clinicName});
}
