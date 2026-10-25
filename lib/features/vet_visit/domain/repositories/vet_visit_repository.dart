import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';

/// Single-visit reads, updates and deletes must match both pet and visit IDs.
/// A missing match returns NotFoundFailure.
/// Writes require a visit date on or before today.
abstract interface class VetVisitRepository {
  /// Returns this pet's visits by date descending, latest insertion first on ties.
  Future<Result<List<VetVisit>>> getVetVisits(String petId);

  /// All pets' visits, date descending, latest insertion first on ties.
  Future<Result<List<VetVisit>>> getAllVetVisits();

  Future<Result<VetVisit>> getVetVisitById(String petId, String visitId);

  Future<Result<void>> createVetVisit(VetVisit visit);

  /// Preserves the existing row's insertion order.
  /// Date corrections atomically update dates of this pet's linked vaccinations.
  Future<Result<void>> updateVetVisit(VetVisit visit);

  Future<Result<void>> deleteVetVisit(String petId, String visitId);

  /// Non-blank names from saved visits and vaccinations across all pets,
  /// deduplicated and sorted case-insensitively using the same shared history.
  /// Returns all clinics; veterinarians match clinicName exactly ignoring case
  /// and normalized whitespace, or include all when clinicName is blank/null.
  /// Names disappear when their last source record is deleted.
  Future<Result<VetVisitSuggestions>> getSuggestions({String? clinicName});
}
