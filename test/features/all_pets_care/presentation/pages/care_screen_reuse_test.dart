import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/app_view_selector.dart';
import 'package:petlytics/core/widgets/care_record_card.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_list_content.dart';
import 'package:petlytics/features/medication/presentation/pages/medication_list_page.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_list_page.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_list_page.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/widgets/vaccination_list_content.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/presentation/widgets/vet_visit_list_content.dart';

import '../../../../helpers/feeding_test_harness.dart';
import '../../../../helpers/multi_step_form_helpers.dart';

void main() {
  late FeedingTestHarness app;
  late List<VetVisit> visits;
  late List<Vaccination> vaccinations;
  const simba = Pet(
    id: 'pet',
    name: 'Simba',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  const buddy = Pet(
    id: 'other',
    name: 'Buddy',
    species: PetSpecies.dog,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.intact,
  );

  Medication medication(String id, String petId) => Medication(
    id: id,
    petId: petId,
    name: 'Medicine $id',
    periods: [
      MedicationPeriod(
        id: 'period-$id',
        medicationId: id,
        startDate: app.today,
        intervalDays: 1,
        doseTimes: [480],
      ),
    ],
  );

  setUpAll(loadFormTestFont);
  setUp(() {
    app = FeedingTestHarness()..register();
    visits = [
      VetVisit(id: 'a', petId: 'pet', visitedOn: app.today, reason: 'Visit A'),
      VetVisit(
        id: 'b',
        petId: 'other',
        visitedOn: app.today,
        reason: 'Visit B',
      ),
    ];
    vaccinations = [
      Vaccination(
        id: 'late',
        petId: 'other',
        vaccineName: 'Late vaccine',
        status: VaccinationStatus.planned,
        date: DateTime(app.today.year, app.today.month, app.today.day - 1),
      ),
      Vaccination(
        id: 'today',
        petId: 'pet',
        vaccineName: 'Today vaccine',
        status: VaccinationStatus.planned,
        date: app.today,
      ),
      Vaccination(
        id: 'next',
        petId: 'other',
        vaccineName: 'Next vaccine',
        status: VaccinationStatus.planned,
        date: DateTime(app.today.year, app.today.month, app.today.day + 1),
      ),
    ];
    app.medications = [medication('a', 'pet'), medication('b', 'other')];
    when(app.pets.getPets)
        .thenAnswer((_) async => const Success([simba, buddy]));
    when(() => app.pets.getPetById(any())).thenAnswer(
      (call) async =>
          Success(call.positionalArguments[0] == 'pet' ? simba : buddy),
    );
    when(app.visits.getAllVetVisits).thenAnswer((_) async => Success(visits));
    when(() => app.visits.getVetVisits(any())).thenAnswer(
      (call) async => Success(
        visits.where((v) => v.petId == call.positionalArguments[0]).toList(),
      ),
    );
    when(() => app.visits.getVetVisitById(any(), any())).thenAnswer(
      (call) async => Success(
        visits.firstWhere(
          (v) =>
              v.petId == call.positionalArguments[0] &&
              v.id == call.positionalArguments[1],
        ),
      ),
    );
    when(app.vaccinations.getAllVaccinations)
        .thenAnswer((_) async => Success(vaccinations));
    when(
      () => app.vaccinations.getVaccinations(
        any(),
        vetVisitId: any(named: 'vetVisitId'),
      ),
    ).thenAnswer(
      (call) async => Success(
        vaccinations
            .where((v) => v.petId == call.positionalArguments[0])
            .toList(),
      ),
    );
  });

  Future<void> catalog(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppViewSelector),
        matching: find.text('Medications'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'visit content keeps the owner and route in both navigation roots',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allVetVisits);
      expect(find.byType(VetVisitListPage), findsOneWidget);
      final globalCubit = tester
          .element(find.byType(VetVisitListPage))
          .read<VetVisitCubit>();
      expect((globalCubit.state as VetVisitsLoaded).petId, isNull);
      expect(find.byType(VetVisitListContent), findsOneWidget);
      expect(find.byType(CarePetIdentity), findsNWidgets(2));
      await tester.tap(find.text('Visit B'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.vetVisitDetail('other', 'b'));
      verifyNever(() => app.pets.getPetById(any()));
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.allVetVisits);
      verify(app.visits.getAllVetVisits).called(1);

      router.go(
        AppRoutes.vetVisits('other'),
        extra: const PetCareRouteExtra(petId: 'other', petName: 'Buddy'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VetVisitListContent), findsOneWidget);
      final scopedCubit = tester
          .element(find.byType(VetVisitListPage))
          .read<VetVisitCubit>();
      expect(scopedCubit, isNot(same(globalCubit)));
      expect((scopedCubit.state as VetVisitsLoaded).petId, 'other');
      expect((globalCubit.state as VetVisitsLoaded).visits, hasLength(2));
      expect(find.byType(CarePetIdentity), findsNothing);
      expect(find.text('Visit B'), findsOneWidget);
      expect(find.text('Visit A'), findsNothing);
      verify(() => app.visits.getVetVisits('other')).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared vaccination list preserves each root grouping and pet scope',
    (tester) async {
      final router = await app.pump(
        tester,
        location: AppRoutes.allVaccinations,
      );
      final globalCubit = tester
          .element(find.byType(VaccinationListPage))
          .read<VaccinationCubit>();
      expect((globalCubit.state as VaccinationsLoaded).petId, isNull);
      expect(find.byType(VaccinationListContent), findsOneWidget);
      for (final heading in ['Overdue', 'Today', 'Upcoming']) {
        final title = find.widgetWithText(AppSectionHeading, heading);
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        expect(title, findsOneWidget);
      }
      router.go(
        AppRoutes.vaccinations('other'),
        extra: const PetCareRouteExtra(petId: 'other', petName: 'Buddy'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationListContent), findsOneWidget);
      final scopedCubit = tester
          .element(find.byType(VaccinationListPage))
          .read<VaccinationCubit>();
      expect(scopedCubit, isNot(same(globalCubit)));
      expect((scopedCubit.state as VaccinationsLoaded).petId, 'other');
      expect(
        (globalCubit.state as VaccinationsLoaded).vaccinations,
        hasLength(3),
      );
      expect(find.widgetWithText(AppSectionHeading, 'Planned'), findsOneWidget);
      expect(find.widgetWithText(AppSectionHeading, 'Overdue'), findsNothing);
      expect(find.text('Late vaccine'), findsOneWidget);
      expect(find.text('Today vaccine'), findsNothing);
      verify(app.vaccinations.getAllVaccinations).called(1);
      verify(() => app.vaccinations.getVaccinations('other')).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'medication content keeps global identities and pet-only doses and catalog',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allMedications);
      final globalCubit = tester
          .element(find.byType(MedicationListPage))
          .read<MedicationCubit>();
      expect((globalCubit.state as MedicationsLoaded).petId, isNull);
      expect(find.byType(MedicationDateSelector), findsOneWidget);
      expect(find.byType(MedicationDoseListContent), findsOneWidget);
      expect(find.byType(CarePetIdentity), findsNWidgets(2));
      await catalog(tester);
      expect(find.byType(MedicationCatalogContent), findsOneWidget);
      expect(find.text('Medicine b'), findsOneWidget);
      await tester.tap(find.text('Medicine b'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.medicationDetail('other', 'b'));
      verifyNever(() => app.pets.getPetById(any()));

      router.go(
        AppRoutes.medications('other'),
        extra: const PetCareRouteExtra(petId: 'other', petName: 'Buddy'),
      );
      await tester.pumpAndSettle();
      final scopedCubit = tester
          .element(find.byType(MedicationListPage))
          .read<MedicationCubit>();
      expect(scopedCubit, isNot(same(globalCubit)));
      expect((scopedCubit.state as MedicationsLoaded).petId, 'other');
      expect(
        (globalCubit.state as MedicationsLoaded).medications,
        hasLength(2),
      );
      expect(find.byType(MedicationDoseListContent), findsOneWidget);
      expect(find.text('Medicine b'), findsOneWidget);
      expect(find.text('Medicine a'), findsNothing);
      expect(find.byType(CarePetIdentity), findsNothing);
      await catalog(tester);
      expect(find.byType(MedicationCatalogContent), findsOneWidget);
      expect(find.text('Medicine b'), findsOneWidget);
      expect(find.text('Medicine a'), findsNothing);
      verify(app.repository.getAllMedications).called(1);
      verify(() => app.repository.getMedications('other')).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (location, label) in [
    (AppRoutes.allVetVisits, 'Unowned visit'),
    (AppRoutes.allVaccinations, 'Unowned vaccine'),
    (AppRoutes.allMedications, 'Medicine missing'),
  ]) {
    testWidgets('missing pet keeps $location record actions disabled', (
      tester,
    ) async {
      visits = [
        VetVisit(
          id: 'missing',
          petId: 'missing',
          visitedOn: app.today,
          reason: 'Unowned visit',
        ),
      ];
      vaccinations = [
        Vaccination(
          id: 'missing',
          petId: 'missing',
          vaccineName: 'Unowned vaccine',
          status: VaccinationStatus.planned,
          date: app.today,
        ),
      ];
      app.medications = [medication('missing', 'missing')];
      final router = await app.pump(tester, location: location);
      if (location == AppRoutes.allMedications) await catalog(tester);
      expect(find.text('Pet unavailable'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, location);
      if (location != AppRoutes.allMedications) {
        await tester.tap(find.byTooltip('Delete $label'));
        await tester.pumpAndSettle();
        expect(find.byType(AppConfirmationDialog), findsNothing);
      }
      verifyNever(() => app.visits.getVetVisitById(any(), any()));
      verifyNever(() => app.pets.getPetById(any()));
      expect(tester.takeException(), isNull);
    });
  }
}
