import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/features/all_pets_care/presentation/pages/all_pets_care_page.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_doses.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import '../../../../helpers/pet_care_test_harness.dart';

void main() {
  late PetCareTestHarness app;
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
  late List<Pet> pets;
  late List<VetVisit> visits;
  late List<Vaccination> vaccines;
  Medication medication(String id, String petId, DateTime day) => Medication(
    id: id,
    petId: petId,
    name: 'Medicine $id',
    periods: [
      MedicationPeriod(
        id: 'period-$id',
        medicationId: id,
        startDate: day,
        intervalDays: 1,
        doseTimes: [480],
      ),
    ],
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    final period = MedicationPeriod(
      id: 'fallback',
      medicationId: 'fallback',
      startDate: DateTime(2026),
      intervalDays: 1,
      doseTimes: [480],
    );
    registerFallbackValue(period);
    registerFallbackValue(
      Medication(
        id: 'fallback',
        petId: 'pet',
        name: 'Fallback',
        periods: [period],
      ),
    );
    registerFallbackValue(
      MedicationDoseLog(
        periodId: 'fallback',
        scheduledDate: DateTime(2026),
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      ),
    );
    registerFallbackValue(
      VetVisit(
        id: 'fallback',
        petId: 'pet',
        visitedOn: DateTime(2026),
        reason: 'Fallback',
      ),
    );
  });
  setUp(() {
    app = PetCareTestHarness()..register();
    pets = [simba, buddy];
    visits = [
      VetVisit(
        id: 'visit-a',
        petId: 'pet',
        visitedOn: app.today,
        reason: 'Checkup A',
      ),
      VetVisit(
        id: 'visit-b',
        petId: 'other',
        visitedOn: app.today,
        reason: 'Checkup B',
      ),
    ];
    vaccines = [
      Vaccination(
        id: 'late',
        petId: 'pet',
        vaccineName: 'Overdue vaccine',
        status: VaccinationStatus.planned,
        date: app.today.subtract(const Duration(days: 1)),
      ),
      Vaccination(
        id: 'next',
        petId: 'other',
        vaccineName: 'Upcoming vaccine',
        status: VaccinationStatus.planned,
        date: app.today.add(const Duration(days: 1)),
      ),
    ];
    app.medications = [
      medication('a', 'pet', app.today),
      medication('b', 'other', app.today),
    ];
    when(app.pets.getPets).thenAnswer((_) async => Success(pets));
    when(() => app.pets.getPetById(any())).thenAnswer(
      (call) async => Success(
        pets.firstWhere((pet) => pet.id == call.positionalArguments.first),
      ),
    );
    when(
      app.visits.getAllVetVisits,
    ).thenAnswer((_) async => Success(List.of(visits)));
    when(() => app.visits.getVetVisitById(any(), any())).thenAnswer(
      (call) async => Success(
        visits.firstWhere(
          (v) =>
              v.petId == call.positionalArguments[0] &&
              v.id == call.positionalArguments[1],
        ),
      ),
    );
    when(
      app.vaccinations.getAllVaccinations,
    ).thenAnswer((_) async => Success(vaccines));
    when(() => app.visits.deleteVetVisit(any(), any())).thenAnswer((
      call,
    ) async {
      visits.removeWhere(
        (v) =>
            v.id == call.positionalArguments[1] &&
            v.petId == call.positionalArguments[0],
      );
      return const Success<void>(null);
    });
    when(() => app.visits.createVetVisit(any())).thenAnswer((call) async {
      visits.add(call.positionalArguments[0] as VetVisit);
      return const Success<void>(null);
    });
    getIt.registerFactory<VetVisitFormCubit>(
      () => VetVisitFormCubit(app.visits, app.ids),
    );
  });

  Future<void> destination(WidgetTester tester, String label) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> filter(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'four roots share a persistent page, lazy lists and one pet directory',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.pets);
      final root = tester.state(find.byType(AllPetsCarePage));
      expect(find.text('Simba'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
      verifyNever(app.visits.getAllVetVisits);
      await destination(tester, 'Vet visits');
      expect(router.state.uri.path, AppRoutes.allVetVisits);
      expect(tester.state(find.byType(AllPetsCarePage)), same(root));
      expect(find.text('Checkup A'), findsOneWidget);
      expect(find.text('Checkup B'), findsOneWidget);
      await destination(tester, 'Vaccinations');
      expect(find.text('Overdue'), findsNWidgets(2));
      expect(find.text('Upcoming vaccine'), findsOneWidget);
      await destination(tester, 'Medications');
      expect(find.widgetWithText(FilledButton, 'Given'), findsNWidgets(2));
      await destination(tester, 'Vet visits');
      verify(app.pets.getPets).called(1);
      verify(app.visits.getAllVetVisits).called(1);
      verifyNever(() => app.visits.getVetVisits(any()));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'own successful global mutations do not invalidate the retained source list',
    (tester) async {
      await app.pump(tester, location: AppRoutes.allVetVisits);
      final element = tester.element(find.byType(AllPetsCarePage));
      CareRecordChanges.maybeOf(element)!.changed(
        'pet',
        PetCareTab.vetVisits,
        deletedId: 'visit-a',
        globalListIsCurrent: true,
      );
      await tester.pumpAndSettle();
      verify(app.visits.getAllVetVisits).called(1);
      verify(app.pets.getPets).called(1);
    },
  );

  testWidgets('pet filters survive switching roots without querying again', (
    tester,
  ) async {
    await app.pump(tester, location: AppRoutes.allVetVisits);
    await filter(tester, 'Buddy · Dog');
    expect(find.text('Checkup A'), findsNothing);
    expect(find.text('Checkup B'), findsOneWidget);
    await destination(tester, 'Vaccinations');
    expect(find.text('Overdue vaccine'), findsOneWidget);
    await destination(tester, 'Vet visits');
    expect(find.text('Checkup B'), findsOneWidget);
    expect(find.text('Checkup A'), findsNothing);
    verify(app.visits.getAllVetVisits).called(1);
  });
  testWidgets(
    'global visit detail returns directly to its source with filter intact',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allVetVisits);
      await filter(tester, 'Buddy · Dog');
      await tester.tap(find.text('Checkup B'));
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        AppRoutes.vetVisitDetail('other', 'visit-b'),
      );
      expect(find.byType(NavigationBar), findsNothing);
      verifyNever(() => app.pets.getPetById(any()));
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.allVetVisits);
      expect(find.text('Checkup B'), findsOneWidget);
      expect(find.text('Checkup A'), findsNothing);
      verify(app.visits.getAllVetVisits).called(1);
    },
  );
  testWidgets(
    'creation chooses a pet, while selected filter skips that choice',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allVetVisits);
      await tester.tap(find.byTooltip('Add visit'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a pet'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Buddy'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.addEditVetVisit('other'));
      expect(find.byType(NavigationBar), findsNothing);
      verifyNever(() => app.pets.getPetById(any()));
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.allVetVisits);
      await filter(tester, 'Simba · Cat');
      await tester.tap(find.byTooltip('Add visit'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.addEditVetVisit('pet'));
      expect(find.text('Choose a pet'), findsNothing);
    },
  );
  testWidgets(
    'single-pet creation skips selection and no-pet roots offer Add pet',
    (tester) async {
      pets = [simba];
      final router = await app.pump(tester, location: AppRoutes.allVetVisits);
      await tester.tap(find.byTooltip('Add visit'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.addEditVetVisit('pet'));
      expect(find.text('Choose a pet'), findsNothing);
    },
  );
  testWidgets(
    'confirmed global deletion removes locally; failed retry requires another confirmation',
    (tester) async {
      var fail = true;
      when(() => app.visits.deleteVetVisit('other', 'visit-b')).thenAnswer((
        _,
      ) async {
        if (fail) return const Error(LocalDatabaseFailure('Delete failed'));
        visits.removeWhere((v) => v.id == 'visit-b');
        return const Success<void>(null);
      });
      await app.pump(tester, location: AppRoutes.allVetVisits);
      await tester.tap(find.byTooltip('Delete Checkup B'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete failed'), findsOneWidget);
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verify(() => app.visits.deleteVetVisit('other', 'visit-b')).called(1);
      fail = false;
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Checkup B'), findsNothing);
      expect(find.text('Checkup A'), findsOneWidget);
      verify(app.visits.getAllVetVisits).called(1);
    },
  );
  testWidgets(
    'Given targets the correct pet and shared editor corrects and clears its result',
    (tester) async {
      await app.pump(tester, location: AppRoutes.allMedications);
      final second = find.byType(MedicationDoseTile).last;
      await tester.tap(
        find.descendant(
          of: second,
          matching: find.widgetWithText(FilledButton, 'Given'),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => app.repository.saveDoseLog('other', 'b', any())).called(1);
      expect(app.logs.single.periodId, 'period-b');
      await tester.tap(find.textContaining('Given at').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Buddy'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Skipped').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(app.logs.single.status, MedicationDoseStatus.skipped);
      await tester.tap(find.text('Skipped · Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear record'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear record'));
      await tester.pumpAndSettle();
      expect(app.logs, isEmpty);
      verify(
        () => app.repository.getAllDoseLogs(
          fromDate: app.today,
          toDate: app.today,
        ),
      ).called(1);
    },
  );
  testWidgets('failed outcome read is unavailable, never No record or Given', (
    tester,
  ) async {
    when(
      () => app.repository.getAllDoseLogs(
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer(
      (_) async => const Error(LocalDatabaseFailure('Records failed')),
    );
    await app.pump(tester, location: AppRoutes.allMedications);
    expect(find.text('Dose record unavailable'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Given'), findsNothing);
    expect(find.text('No record'), findsNothing);
    await tester.drag(
      find.byType(CustomScrollView).hitTestable(),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dose record unavailable'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Given'), findsNothing);
  });
  testWidgets('pending dose blocks repeated write, navigation and Back', (
    tester,
  ) async {
    app.pendingDose = Completer<Result<void>>();
    final router = await app.pump(tester, location: AppRoutes.allMedications);
    await tester.tap(find.widgetWithText(FilledButton, 'Given').first);
    await tester.pump();
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Vet visits'),
          )
          .last,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(router.state.uri.path, AppRoutes.allMedications);
    verify(() => app.repository.saveDoseLog(any(), any(), any())).called(1);
    app.pendingDose!.complete(const Success<void>(null));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'external known deletion updates retained root without a source reread',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allVetVisits);
      final context = tester.element(find.byType(AllPetsCarePage));
      CareRecordChanges.maybeOf(
        context,
      )!.changed('other', PetCareTab.vetVisits, deletedId: 'visit-b');
      await tester.pumpAndSettle();
      expect(find.text('Checkup B'), findsNothing);
      expect(router.state.uri.path, AppRoutes.allVetVisits);
      verify(app.visits.getAllVetVisits).called(1);
    },
  );
  testWidgets(
    'no-pet root offers Add pet without a duplicate empty-state action',
    (tester) async {
      pets.clear();
      visits.clear();
      final router = await app.pump(tester, location: AppRoutes.allVetVisits);
      expect(find.text('No pets yet'), findsOneWidget);
      expect(find.byTooltip('Add pet'), findsOneWidget);
      await tester.tap(find.byTooltip('Add pet'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.addEditPet);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );
  testWidgets(
    'successful visit creation refreshes its source and preserves the pet filter',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allVetVisits);
      await filter(tester, 'Buddy · Dog');
      await tester.tap(find.byTooltip('Add visit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason for visit'),
        'Follow-up for Buddy',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add visit'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.allVetVisits);
      expect(find.text('Follow-up for Buddy'), findsOneWidget);
      expect(find.text('Checkup A'), findsNothing);
      verify(app.visits.getAllVetVisits).called(2);
      verify(app.pets.getPets).called(1);
      expect(visits.last.petId, 'other');
    },
  );
  testWidgets(
    'actual detail deletion returns to global list without a source reread',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allVetVisits);
      await tester.tap(find.text('Checkup B'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete visit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.allVetVisits);
      expect(find.text('Checkup B'), findsNothing);
      verify(app.visits.getAllVetVisits).called(1);
    },
  );
  testWidgets('root scroll and medication view survive destination changes', (
    tester,
  ) async {
    visits = [
      for (var i = 0; i < 30; i++)
        VetVisit(
          id: 'visit-$i',
          petId: 'pet',
          visitedOn: app.today,
          reason: 'Checkup $i',
        ),
    ];
    await app.pump(tester, location: AppRoutes.allVetVisits);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = position.pixels;
    expect(offset, greaterThan(0));
    await destination(tester, 'Medications');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Medications'));
    await tester.pumpAndSettle();
    await destination(tester, 'Vet visits');
    expect(position.pixels, offset);
    await destination(tester, 'Medications');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Medications'))
          .selected,
      isTrue,
    );
    verify(app.visits.getAllVetVisits).called(1);
  });
  testWidgets(
    'future dose day is read only and unavailable pet metadata disables writes',
    (tester) async {
      await app.pump(tester, location: AppRoutes.allMedications);
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      expect(find.text('Scheduled'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Given'), findsNothing);
      expect(find.text('Record dose'), findsNothing);
    },
  );
  testWidgets(
    'hidden global medication root does no clock reads and catches up on Back',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allMedications);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Medications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medicine a'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.medicationDetail('pet', 'a'));
      app.clock = DateTime(
        app.today.year,
        app.today.month,
        app.today.day + 1,
        1,
      );
      final next = DateUtils.dateOnly(app.clock);
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
      verifyNever(
        () => app.repository.getAllDoseLogs(fromDate: next, toDate: next),
      );
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.allMedications);
      verify(
        () => app.repository.getAllDoseLogs(fromDate: next, toDate: next),
      ).called(1);
    },
  );
  testWidgets(
    'a known-name detail can change to the same pet profile without losing profile data',
    (tester) async {
      final router = await app.pump(tester, location: AppRoutes.allMedications);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Medications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medicine a'));
      await tester.pumpAndSettle();
      verifyNever(() => app.pets.getPetById(any()));
      router.go(AppRoutes.petDetail('pet'));
      await tester.pumpAndSettle();
      expect(find.text('Profile details'), findsOneWidget);
      expect(find.text('Simba'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      verify(() => app.pets.getPetById('pet')).called(1);
    },
  );
  testWidgets(
    'unavailable pet metadata disables otherwise loaded dose actions',
    (tester) async {
      when(app.pets.getPets).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Pets failed')),
      );
      await app.pump(tester, location: AppRoutes.allMedications);
      expect(find.text('Retry pets'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Given').first,
            )
            .onPressed,
        isNull,
      );
      verifyNever(() => app.repository.saveDoseLog(any(), any(), any()));
    },
  );
  for (final dark in [false, true]) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets('global controls fit $size with large text, dark=$dark', (
        tester,
      ) async {
        await app.pump(
          tester,
          location: AppRoutes.allMedications,
          size: size,
          scale: 2,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        await destination(tester, 'Vaccinations');
        expect(tester.takeException(), isNull);
        await destination(tester, 'Vet visits');
        expect(tester.takeException(), isNull);
        final fab = tester.getRect(find.byType(FloatingActionButton));
        final nav = tester.getRect(find.byType(NavigationBar));
        expect(fab.bottom, lessThan(nav.top));
      });
    }
  }
}
