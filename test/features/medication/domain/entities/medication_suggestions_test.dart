import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/medication/domain/entities/medication_suggestions.dart';

void main() {
  test(
    'reloaded names compare by content, including changed medication names',
    () {
      const original = MedicationSuggestions(
        medicationNames: ['Medicine'],
        clinicNames: ['Clinic'],
        veterinarianNames: ['Dr. Smith'],
      );

      expect(
        MedicationSuggestions(
          medicationNames: ['Medicine'],
          clinicNames: ['Clinic'],
          veterinarianNames: ['Dr. Smith'],
        ),
        original,
      );
      expect(
        const MedicationSuggestions(
          medicationNames: ['Another medicine'],
          clinicNames: ['Clinic'],
          veterinarianNames: ['Dr. Smith'],
        ),
        isNot(original),
      );
    },
  );
}
