import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/theme/app_theme.dart';
import 'package:patilog/features/medication/domain/repositories/medication_repository.dart';
import 'package:patilog/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/widgets/visit_medications_section.dart';
import 'package:patilog/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/widgets/visit_vaccinations_section.dart';

class _Medications extends Mock implements MedicationRepository {}

class _Vaccinations extends Mock implements VaccinationRepository {}

void main() {
  Future<void> pumpSections(
    WidgetTester tester,
    TextDirection direction, {
    bool failed = false,
  }) async {
    final medications = _Medications();
    final vaccinations = _Vaccinations();
    when(
      () => medications.getMedications('pet', vetVisitId: 'visit'),
    ).thenAnswer(
      (_) async => failed
          ? const Error(LocalDatabaseFailure('Medications unavailable'))
          : const Success([]),
    );
    when(
      () => vaccinations.getVaccinations('pet', vetVisitId: 'visit'),
    ).thenAnswer(
      (_) async => failed
          ? const Error(LocalDatabaseFailure('Vaccinations unavailable'))
          : const Success([]),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.dark,
        home: Directionality(
          textDirection: direction,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => MedicationCubit(
                  medications,
                  const CalculateMedicationDoses(),
                ),
              ),
              BlocProvider(create: (_) => VaccinationCubit(vaccinations)),
            ],
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    VisitVaccinationsSection(
                      petId: 'pet',
                      visitId: 'visit',
                      onOpen: null,
                    ),
                    SizedBox(height: 16),
                    VisitMedicationsSection(petId: 'pet', visitId: 'visit'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Linked vaccinations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Linked medications'));
    await tester.pumpAndSettle();
  }

  for (final direction in TextDirection.values) {
    testWidgets('linked empty states share their content inset in $direction', (
      tester,
    ) async {
      await pumpSections(tester, direction);
      final vaccines = tester.getRect(
        find.text('No vaccinations linked to this visit.'),
      );
      final medications = tester.getRect(
        find.text('No medications linked to this visit.'),
      );
      expect(vaccines.left, closeTo(medications.left, 0.01));
      expect(vaccines.right, closeTo(medications.right, 0.01));
    });
    testWidgets(
      'linked errors and retry labels use the card content inset in $direction',
      (tester) async {
        await pumpSections(tester, direction, failed: true);
        for (final (message, retry, cardIndex) in [
          ('Failed to load vaccinations', 'Retry vaccinations', 0),
          ('Failed to load medications', 'Retry medications', 1),
        ]) {
          final card = tester.getRect(find.byType(Card).at(cardIndex));
          final text = tester.getRect(find.text(message));
          final action = tester.getRect(find.text(retry));
          if (direction == TextDirection.ltr) {
            expect(text.left, closeTo(card.left + 16, 0.01));
            expect(action.left, closeTo(text.left, 0.01));
          } else {
            expect(text.right, closeTo(card.right - 16, 0.01));
            expect(action.right, closeTo(text.right, 0.01));
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
