import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit_suggestions.dart';

void main() {
  const suggestions = VetVisitSuggestions(
    clinicNames: ['Clinic'],
    veterinarianNames: ['Dr. Smith'],
  );

  test('equivalent suggestions compare by names rather than list identity', () {
    expect(
      VetVisitSuggestions(
        clinicNames: ['Clinic'],
        veterinarianNames: ['Dr. Smith'],
      ),
      suggestions,
    );
  });

  test('changed clinic or veterinarian options change equality', () {
    expect(
      const VetVisitSuggestions(
        clinicNames: ['Another clinic'],
        veterinarianNames: ['Dr. Smith'],
      ),
      isNot(suggestions),
    );
    expect(
      const VetVisitSuggestions(clinicNames: ['Clinic'], veterinarianNames: []),
      isNot(suggestions),
    );
  });
}
