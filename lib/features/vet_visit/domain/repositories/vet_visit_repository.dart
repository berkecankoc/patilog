import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';

/// Single-visit reads, updates and deletes must match both pet and visit IDs.
/// A missing match returns NotFoundFailure.
abstract interface class VetVisitRepository {
  /// Returns this pet's visits by date descending, latest insertion first on ties.
  Future<Result<List<VetVisit>>> getVetVisits(String petId);

  Future<Result<VetVisit>> getVetVisitById(String petId, String visitId);

  Future<Result<void>> createVetVisit(VetVisit visit);

  /// Preserves the existing row's insertion order.
  Future<Result<void>> updateVetVisit(VetVisit visit);

  Future<Result<void>> deleteVetVisit(String petId, String visitId);

  /// Non-blank names from saved visits across all pets, trimmed, deduplicated and
  /// sorted case-insensitively; the latest inserted spelling wins.
  /// Returns all clinics; veterinarians match clinicName exactly ignoring case
  /// and surrounding whitespace, or include all when clinicName is blank/null.
  /// Names disappear when their last source visit is deleted.
  Future<Result<VetVisitSuggestions>> getSuggestions({String? clinicName});
}
