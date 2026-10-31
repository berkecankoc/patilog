import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/widgets/app_related_clinical_details.dart';

void main() {
  testWidgets('hides duplicate clinical names ignoring case and whitespace', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: AppRelatedClinicalDetails(
            clinicName: ' Clinic   A ',
            parentClinicName: 'clinic a',
            veterinarianName: ' Dr.  Smith ',
            parentVeterinarianName: 'dr. smith',
          ),
        ),
      ),
    );
    expect(find.text('Clinic'), findsNothing);
    expect(find.text('Veterinarian'), findsNothing);
  });

  testWidgets(
    'shows only nonempty differences, preserving the displayed spelling',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AppRelatedClinicalDetails(
              clinicName: 'Clinic B',
              parentClinicName: 'Clinic A',
              veterinarianName: 'Dr. Smith',
              parentVeterinarianName: 'dr. smith',
            ),
          ),
        ),
      );
      expect(find.text('Clinic B'), findsOneWidget);
      expect(find.text('Veterinarian'), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AppRelatedClinicalDetails(
              clinicName: '  ',
              parentClinicName: 'Clinic A',
              veterinarianName: 'Dr. Jones',
            ),
          ),
        ),
      );
      expect(find.text('Clinic'), findsNothing);
      expect(find.text('Dr. Jones'), findsOneWidget);
      expect(find.text('Not provided'), findsNothing);
    },
  );
}
