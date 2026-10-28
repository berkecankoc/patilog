import 'dart:async';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';

import 'package:flutter/material.dart';
import '../../../../helpers/all_pets_care_dependencies.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../helpers/multi_step_form_helpers.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/vaccination/data/models/vaccination_model.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_detail_page.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_form_page.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_list_page.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_detail_page.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:petlytics/core/widgets/app_related_records_section.dart';
import 'package:petlytics/core/widgets/app_related_clinical_details.dart';

class MockVaccinations extends Mock implements VaccinationRepository {}

class MockPets extends Mock implements PetRepository {}

class MockVisits extends Mock implements VetVisitRepository {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

class MockDeletePet extends Mock implements DeletePet {}

class MockImages extends Mock implements ImageStorage {}

class MockIds extends Mock implements IdGenerator {}

class MockMedications extends Mock implements MedicationRepository {}

void main() {
  const pet = Pet(
    id: 'pet-1',
    name: 'Milo',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  const otherPet = Pet(
    id: 'pet-2',
    name: 'Luna',
    species: PetSpecies.dog,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.sterilized,
  );
  final administered = Vaccination(
    id: 'administered',
    petId: pet.id,
    vaccineName: 'Rabies',
    status: VaccinationStatus.administered,
    date: DateTime(2020, 1, 2),
    clinicName: 'Clinic A',
    veterinarianName: 'Dr. Smith',
    notes: 'No reaction',
  );
  final planned = Vaccination(
    id: 'planned',
    petId: pet.id,
    vaccineName: 'Booster',
    status: VaccinationStatus.planned,
    date: DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 5)),
  );
  final visit = VetVisit(
    id: 'visit-1',
    petId: pet.id,
    visitedOn: DateTime(2020, 1, 2),
    reason: 'Checkup',
    clinicName: 'Clinic A',
    veterinarianName: 'Dr. Smith',
  );
  late MockVaccinations repository;
  late MockPets pets;
  late MockVisits visitRepository;
  late List<Vaccination> records;

  Vaccination stored(Vaccination v) => VaccinationModel.fromJson(
    VaccinationModel.fromEntity(v).toJson(),
  ).toEntity();

  Vaccination linkedRecord({String id = 'linked', String vaccine = 'Rabies'}) =>
      Vaccination(
        id: id,
        petId: pet.id,
        vaccineName: vaccine,
        status: VaccinationStatus.administered,
        date: visit.visitedOn,
        vetVisitId: visit.id,
      );

  setUpAll(() {
    registerFallbackValue(administered);
    registerFallbackValue(visit);
  });
  setUp(() {
    records = [planned, administered];
    repository = MockVaccinations();
    pets = MockPets();
    visitRepository = MockVisits();
    when(pets.getPets).thenAnswer((_) async => const Success([pet, otherPet]));
    when(() => pets.getPetById(any())).thenAnswer(
      (i) async =>
          Success(i.positionalArguments.first == otherPet.id ? otherPet : pet),
    );
    when(
      () => repository.getVaccinations(
        any(),
        vetVisitId: any(named: 'vetVisitId'),
      ),
    ).thenAnswer(
      (i) async => Success(
        records
            .where(
              (v) =>
                  v.petId == i.positionalArguments.first &&
                  (i.namedArguments[#vetVisitId] == null ||
                      v.vetVisitId == i.namedArguments[#vetVisitId]),
            )
            .toList(),
      ),
    );
    when(() => repository.getVaccinationById(any(), any())).thenAnswer((
      i,
    ) async {
      final found = records.where(
        (v) =>
            v.petId == i.positionalArguments[0] &&
            v.id == i.positionalArguments[1],
      );
      return found.isEmpty
          ? const Error(NotFoundFailure('Vaccination not found'))
          : Success(found.single);
    });
    when(
      () => repository.getSuggestions(clinicName: any(named: 'clinicName')),
    ).thenAnswer(
      (i) async => Success(
        VaccinationSuggestions(
          vaccineNames: const ['Rabies', 'Booster'],
          clinicNames: const ['Clinic A', 'Clinic B'],
          veterinarianNames: i.namedArguments[#clinicName] == 'Clinic B'
              ? ['Dr. Jones']
              : ['Dr. Smith'],
        ),
      ),
    );
    when(
      () =>
          repository.createVaccination(any(), nextDose: any(named: 'nextDose')),
    ).thenAnswer((i) async {
      final next = i.namedArguments[#nextDose] as Vaccination?;
      records = [
        if (next != null) stored(next),
        stored(i.positionalArguments.first as Vaccination),
        ...records,
      ];
      return const Success(null);
    });
    when(
      () =>
          repository.updateVaccination(any(), nextDose: any(named: 'nextDose')),
    ).thenAnswer((i) async {
      final changed = stored(i.positionalArguments.first as Vaccination);
      final next = i.namedArguments[#nextDose] as Vaccination?;
      records = [
        if (next != null) stored(next),
        for (final v in records)
          if (v.id == changed.id && v.petId == changed.petId) changed else v,
      ];
      return const Success(null);
    });
    when(() => repository.deleteVaccination(any(), any())).thenAnswer((
      i,
    ) async {
      records.removeWhere(
        (v) =>
            v.petId == i.positionalArguments[0] &&
            v.id == i.positionalArguments[1],
      );
      return const Success(null);
    });
    when(() => visitRepository.getVetVisits(any())).thenAnswer(
      (i) async => Success(
        i.positionalArguments.first == pet.id ? [visit] : <VetVisit>[],
      ),
    );
    when(
      () => visitRepository.getVetVisitById(pet.id, visit.id),
    ).thenAnswer((_) async => Success(visit));
    final ids = MockIds();
    var id = 0;
    when(ids.generate).thenAnswer((_) => 'created-${++id}');
    registerAllPetsCare(pets);
    getIt.registerFactory<PetCubit>(
      () => PetCubit(pets, MockCreatePet(), MockUpdatePet(), MockDeletePet()),
    );
    getIt.registerFactory<VaccinationCubit>(() => VaccinationCubit(repository));
    getIt.registerFactory<VaccinationFormCubit>(
      () => VaccinationFormCubit(
        repository,
        visitRepository,
        SaveVaccination(repository, ids),
      ),
    );
    getIt.registerFactory<VetVisitCubit>(() => VetVisitCubit(visitRepository));
    final medications = MockMedications();
    when(
      () => medications.getMedications(
        any(),
        vetVisitId: any(named: 'vetVisitId'),
      ),
    ).thenAnswer((_) async => const Success([]));
    getIt.registerFactory<MedicationCubit>(
      () => MedicationCubit(medications, const CalculateMedicationDoses()),
    );
    getIt.registerFactory<VetVisitFormCubit>(
      () => VetVisitFormCubit(visitRepository, ids),
    );
    when(
      () =>
          visitRepository.getSuggestions(clinicName: any(named: 'clinicName')),
    ).thenAnswer(
      (_) async => const Success(
        VetVisitSuggestions(
          clinicNames: ['Clinic A'],
          veterinarianNames: ['Dr. Smith'],
        ),
      ),
    );
  });
  tearDown(() async => getIt.reset());

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    String? location,
    Size size = const Size(390, 844),
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool keyboard = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: location ?? AppRoutes.vaccinations(pet.id),
      routes: appRouter.configuration.routes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard ? 280 : 0),
            viewPadding: const EdgeInsets.only(bottom: 34),
            padding: EdgeInsets.only(bottom: keyboard ? 0 : 34),
          ),
          child: RepositoryProvider<ImageStorage>.value(
            value: MockImages(),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  final name = find.widgetWithText(
    TextFormField,
    'Vaccine name',
    skipOffstage: false,
  );
  final notes = find.byKey(const Key('vaccination-notes'), skipOffstage: false);
  final clinic = find.widgetWithText(
    TextFormField,
    'Clinic (optional)',
    skipOffstage: false,
  );
  final vet = find.widgetWithText(
    TextFormField,
    'Veterinarian (optional)',
    skipOffstage: false,
  );

  Future<void> expandRelated(WidgetTester tester, String title) async {
    final row = find.widgetWithText(ListTile, title);
    await revealFormField(tester, row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, Finder field, String value) async {
    await revealFormField(tester, field);
    await enterFormText(tester, field, value);
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add vaccination'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('My pets'), findsNothing);
  }

  Future<void> open(WidgetTester tester, Vaccination record) async {
    if (find.text(record.vaccineName).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(record.vaccineName),
        150,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await revealFormField(tester, find.text(record.vaccineName));
    await tester.pumpAndSettle();
    await tester.tap(find.text(record.vaccineName));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, {bool settle = true}) =>
      submitForm(tester, settle: settle);

  testWidgets(
    'linked visit loads on expansion, retries locally and stays cached on reopen',
    (tester) async {
      records = [linkedRecord()];
      await pumpRouter(
        tester,
        location: AppRoutes.vaccinationDetail(pet.id, records.single.id),
      );
      verifyNever(() => visitRepository.getVetVisitById(any(), any()));
      when(() => visitRepository.getVetVisitById(pet.id, visit.id)).thenAnswer(
        (_) async =>
            const Error(LocalDatabaseFailure('Could not load linked visit')),
      );
      await expandRelated(tester, 'Linked vet visit');
      expect(find.text('Could not load linked visit'), findsOneWidget);
      expect(find.text('Rabies'), findsOneWidget);
      when(
        () => visitRepository.getVetVisitById(pet.id, visit.id),
      ).thenAnswer((_) async => Success(visit));
      await revealFormField(tester, find.text('Retry visit'));
      await tester.tap(find.text('Retry visit'));
      await tester.pumpAndSettle();
      expect(find.text('Checkup'), findsOneWidget);
      await expandRelated(tester, 'Linked vet visit');
      await expandRelated(tester, 'Linked vet visit');
      verify(() => visitRepository.getVetVisitById(pet.id, visit.id)).called(2);
    },
  );

  testWidgets(
    'linked vaccination edit, unlink and deletion refresh the expanded visit section',
    (tester) async {
      records = [linkedRecord()];
      await pumpRouter(
        tester,
        location: AppRoutes.vetVisitDetail(pet.id, visit.id),
      );
      verifyNever(
        () => repository.getVaccinations(pet.id, vetVisitId: visit.id),
      );
      await expandRelated(tester, 'Linked vaccinations');
      final arrow = find.byTooltip('Open vaccination: Rabies');
      await revealFormField(tester, arrow);
      await tester.tap(arrow);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit vaccination'));
      await tester.pumpAndSettle();
      await fill(tester, name, 'Updated vaccine');
      await submit(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Updated vaccine'), findsOneWidget);
      final updatedArrow = find.byTooltip('Open vaccination: Updated vaccine');
      await revealFormField(tester, updatedArrow);
      await tester.tap(updatedArrow);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit vaccination'));
      await tester.pumpAndSettle();
      final visitField = find.byType(
        DropdownButtonFormField<String>,
        skipOffstage: false,
      );
      await revealFormField(tester, visitField);
      await tester.tap(visitField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('No linked visit').last);
      await tester.pumpAndSettle();
      await submit(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        find.text('No vaccinations linked to this visit.'),
        findsOneWidget,
      );
      records = [linkedRecord()];
      // Re-enter the visit with a newly linked record, then delete from its detail.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checkup'));
      await tester.pumpAndSettle();
      await expandRelated(tester, 'Linked vaccinations');
      await revealFormField(tester, arrow);
      await tester.tap(arrow);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete vaccination'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(
        find.text('No vaccinations linked to this visit.'),
        findsOneWidget,
      );
      verify(() => repository.deleteVaccination(pet.id, 'linked')).called(1);
    },
  );

  testWidgets(
    'visit linked errors retry without replacing details and many records scroll',
    (tester) async {
      records = List.generate(
        40,
        (i) => linkedRecord(id: 'linked-$i', vaccine: 'Vaccine $i'),
      );
      when(
        () => repository.getVaccinations(pet.id, vetVisitId: visit.id),
      ).thenAnswer(
        (_) async =>
            const Error(LocalDatabaseFailure('Linked vaccines failed')),
      );
      await pumpRouter(
        tester,
        location: AppRoutes.vetVisitDetail(pet.id, visit.id),
      );
      await expandRelated(tester, 'Linked vaccinations');
      expect(find.text('Linked vaccines failed'), findsOneWidget);
      expect(find.text('Checkup'), findsOneWidget);
      when(
        () => repository.getVaccinations(pet.id, vetVisitId: visit.id),
      ).thenAnswer((_) async => Success(records));
      await revealFormField(tester, find.text('Retry vaccinations'));
      await tester.tap(find.text('Retry vaccinations'));
      await tester.pumpAndSettle();
      final section = find.widgetWithText(
        AppRelatedRecordsSection,
        'Linked vaccinations',
      );
      final scrollable = find
          .descendant(of: section, matching: find.byType(Scrollable))
          .last;
      final last = find.byTooltip('Open vaccination: Vaccine 39');
      await revealFormField(tester, scrollable);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(last, 200, scrollable: scrollable);
      await tester.pumpAndSettle();
      await revealFormField(tester, last);
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      expect(find.text('Vaccine 39'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('editing a linked visit refreshes its open preview', (
    tester,
  ) async {
    records = [linkedRecord()];
    when(() => visitRepository.updateVetVisit(any())).thenAnswer((
      invocation,
    ) async {
      final updated = invocation.positionalArguments.single as VetVisit;
      records = [
        for (final record in records)
          if (record.vetVisitId == updated.id)
            VaccinationModel.fromJson({
              ...VaccinationModel.fromEntity(record).toJson(),
              'date': updated.visitedOn.toIso8601String(),
            }).toEntity()
          else
            record,
      ];
      when(
        () => visitRepository.getVetVisitById(pet.id, visit.id),
      ).thenAnswer((_) async => Success(updated));
      return const Success(null);
    });
    await pumpRouter(
      tester,
      location: AppRoutes.vaccinationDetail(pet.id, records.single.id),
    );
    await expandRelated(tester, 'Linked vet visit');
    await revealFormField(tester, find.byTooltip('Open vet visit'));
    await tester.tap(find.byTooltip('Open vet visit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit visit'));
    await tester.pumpAndSettle();
    await fill(
      tester,
      find.byKey(const Key('visit-reason'), skipOffstage: false),
      'Updated visit reason',
    );
    expect(find.byTooltip('My pets'), findsNothing);
    await revealFormField(
      tester,
      find.byTooltip('Choose visit date', skipOffstage: false),
    );
    await tester.tap(find.byTooltip('Choose visit date', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text('Dates of any linked vaccinations will also change.'),
      findsOneWidget,
    );
    await submit(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(VaccinationDetailPage), findsOneWidget);
    expect(find.text('Updated visit reason'), findsOneWidget);
    expect(find.text('Jan 3, 2020'), findsOneWidget);
    await revealFormField(tester, find.text('Updated visit reason'));
    await tester.pumpAndSettle();
    expect(find.text('Updated visit reason').hitTestable(), findsOneWidget);
    verify(() => visitRepository.updateVetVisit(any())).called(1);
  });

  for (final linkedVisit in [false, true]) {
    testWidgets(
      'My pets safely leaves a pending linked ${linkedVisit ? 'visit' : 'vaccination'} read',
      (tester) async {
        final visitRead = Completer<Result<VetVisit>>();
        final vaccinesRead = Completer<Result<List<Vaccination>>>();
        records = [linkedRecord()];
        if (linkedVisit) {
          when(
            () => visitRepository.getVetVisitById(pet.id, visit.id),
          ).thenAnswer((_) => visitRead.future);
        } else {
          when(
            () => repository.getVaccinations(pet.id, vetVisitId: visit.id),
          ).thenAnswer((_) => vaccinesRead.future);
        }
        final router = await pumpRouter(
          tester,
          location: linkedVisit
              ? AppRoutes.vaccinationDetail(pet.id, records.single.id)
              : AppRoutes.vetVisitDetail(pet.id, visit.id),
        );
        final header = find.widgetWithText(
          ListTile,
          linkedVisit ? 'Linked vet visit' : 'Linked vaccinations',
        );
        await revealFormField(tester, header);
        await tester.tap(header);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byTooltip('My pets'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.pets);
        expect(router.canPop(), isFalse);
        if (linkedVisit) {
          visitRead.complete(Success(visit));
        } else {
          vaccinesRead.complete(Success(records));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'short landscape linked retry and record action work in $brightness',
      (tester) async {
        records = [linkedRecord()];
        when(
          () => repository.getVaccinations(pet.id, vetVisitId: visit.id),
        ).thenAnswer(
          (_) async => const Error(
            LocalDatabaseFailure('Could not load linked vaccinations'),
          ),
        );
        await pumpRouter(
          tester,
          location: AppRoutes.vetVisitDetail(pet.id, visit.id),
          size: const Size(640, 320),
          scale: 2,
          brightness: brightness,
        );
        await expandRelated(tester, 'Linked vaccinations');
        final retry = find.text('Retry vaccinations');
        await revealFormField(tester, retry);
        await tester.pumpAndSettle();
        expect(retry.hitTestable(), findsOneWidget);
        when(
          () => repository.getVaccinations(pet.id, vetVisitId: visit.id),
        ).thenAnswer((_) async => Success(records));
        await tester.tap(retry);
        await tester.pumpAndSettle();
        final arrow = find.byTooltip('Open vaccination: Rabies');
        await revealFormField(tester, arrow);
        await tester.pumpAndSettle();
        expect(arrow.hitTestable(), findsOneWidget);
        await tester.tap(arrow);
        await tester.pumpAndSettle();
        expect(find.byType(VaccinationDetailPage), findsOneWidget);
        expect(find.text('Rabies'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<void> pickDate(
    WidgetTester tester,
    String label,
    DateTime date,
  ) async {
    final choose = find.byTooltip(
      'Choose ${label.toLowerCase()}',
      skipOffstage: false,
    );
    await revealFormField(tester, choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    final dialog = find.byType(DatePickerDialog);
    final l10n = MaterialLocalizations.of(tester.element(dialog));
    await tester.tap(find.byTooltip(l10n.inputDateModeButtonLabel));
    await tester.pumpAndSettle();
    await enterFormText(
      tester,
      find.descendant(of: dialog, matching: find.byType(TextField)).first,
      '${date.month}/${date.day}/${date.year}',
    );
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
  }

  Future<void> chooseStatus(WidgetTester tester, String label) async {
    final field = find.byType(
      DropdownButtonFormField<VaccinationStatus>,
      skipOffstage: false,
    );
    await revealFormField(tester, field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  for (final editing in [false, true]) {
    testWidgets(
      'multi-step vaccination ${editing ? 'edit' : 'add'} reviews before saving',
      (tester) async {
        await pumpRouter(tester);
        if (editing) {
          await open(tester, administered);
          await tester.tap(find.byTooltip('Edit vaccination'));
          await tester.pumpAndSettle();
        } else {
          await add(tester);
        }
        expect(
          find.text(
            editing ? 'Step 2 of 2 · Review' : 'Step 1 of 2 · Vaccination',
          ),
          findsOneWidget,
        );
        await fill(tester, name, 'Rabies');
        await reviewForm(tester);
        expect(find.text('Review vaccination'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Edit'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextButton, 'Back'), findsNothing);
        expect(tester.widget<TextFormField>(name).controller!.text, 'Rabies');
        await reviewForm(tester);
        verifyNever(
          () => repository.createVaccination(
            any(),
            nextDose: any(named: 'nextDose'),
          ),
        );
        verifyNever(
          () => repository.updateVaccination(
            any(),
            nextDose: any(named: 'nextDose'),
          ),
        );
      },
    );
    testWidgets(
      'linked ${editing ? 'edit' : 'add'} inherits visit date and unlocks on unlink',
      (tester) async {
        final second = VetVisit(
          id: 'visit-2',
          petId: pet.id,
          visitedOn: DateTime(2020, 2, 3),
          reason: 'Follow-up visit',
        );
        when(
          () => visitRepository.getVetVisits(pet.id),
        ).thenAnswer((_) async => Success([visit, second]));
        records = [linkedRecord()];
        await pumpRouter(tester);
        if (editing) {
          await open(tester, records.single);
          await tester.tap(find.byTooltip('Edit vaccination'));
          await tester.pumpAndSettle();
        } else {
          await add(tester);
        }
        expect(find.byTooltip('My pets'), findsNothing);
        await fill(tester, name, 'Linked vaccine');
        final dateFinder = find.byKey(
          const Key('vaccination-date'),
          skipOffstage: false,
        );
        AppDateField date() => tester.widget<AppDateField>(dateFinder);
        Future<void> select(String reason) async {
          final field = find.byType(
            DropdownButtonFormField<String>,
            skipOffstage: false,
          );
          await revealFormField(tester, field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining(reason).last);
          await tester.pumpAndSettle();
        }

        await select('Checkup');
        expect(date().value, visit.visitedOn);
        expect(date().readOnly, isTrue);
        expect(find.text('Date from linked vet visit'), findsOneWidget);
        await revealFormField(tester, dateFinder);
        await tester.tap(
          find.descendant(of: dateFinder, matching: find.byType(TextField)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(
          find.byTooltip('Choose administration date', skipOffstage: false),
          findsNothing,
        );
        await select('Follow-up visit');
        expect(date().value, second.visitedOn);
        await select('No linked visit');
        expect(date().value, second.visitedOn);
        expect(date().readOnly, isFalse);
        expect(find.text('Date from linked vet visit'), findsNothing);
        await revealFormField(
          tester,
          find.byTooltip('Choose administration date', skipOffstage: false),
        );
        await tester.tap(
          find.byTooltip('Choose administration date', skipOffstage: false),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .initialDate,
          second.visitedOn,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await select('Follow-up visit');
        await submit(tester);
        final saved = records.singleWhere(
          (record) => record.vaccineName == 'Linked vaccine',
        );
        expect(saved.date, second.visitedOn);
        expect(saved.vetVisitId, second.id);
      },
    );
  }

  for (final visitDetail in [false, true]) {
    testWidgets(
      '${visitDetail ? 'visit' : 'vaccination'} preview hides shared dates and names but shows clinical differences',
      (tester) async {
        final linked = Vaccination(
          id: 'linked',
          petId: pet.id,
          vaccineName: 'Rabies',
          status: VaccinationStatus.administered,
          date: visit.visitedOn,
          vetVisitId: visit.id,
          clinicName: ' clinic   a ',
          veterinarianName: 'Dr. Jones',
        );
        records = [linked];
        await pumpRouter(
          tester,
          location: visitDetail
              ? AppRoutes.vetVisitDetail(pet.id, visit.id)
              : AppRoutes.vaccinationDetail(pet.id, linked.id),
        );
        final home = find.byTooltip('My pets');
        final delete = find.byTooltip(
          visitDetail ? 'Delete visit' : 'Delete vaccination',
        );
        expect(
          find.widgetWithIcon(IconButton, Icons.home_outlined),
          findsOneWidget,
        );
        expect(
          tester.getCenter(home).dx,
          lessThan(tester.getCenter(delete).dx),
        );
        await expandRelated(
          tester,
          visitDetail ? 'Linked vaccinations' : 'Linked vet visit',
        );
        final section = find.byType(AppRelatedRecordsSection);
        final details = find.descendant(
          of: section,
          matching: find.byType(AppRelatedClinicalDetails),
        );
        expect(
          find.descendant(of: details, matching: find.text('Clinic')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: details,
            matching: find.text(visitDetail ? 'Dr. Jones' : 'Dr. Smith'),
          ),
          findsOneWidget,
        );
        expect(find.text('Jan 2, 2020'), findsOneWidget);
        expect(
          find.descendant(
            of: section,
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: section,
            matching: find.byIcon(Icons.open_in_new_outlined),
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'profile navigation forwards the pet name to list detail and form without extra reads',
    (tester) async {
      await pumpRouter(tester, location: AppRoutes.petDetail(pet.id));
      clearInteractions(pets);
      await revealFormField(tester, find.text('Vaccinations'));
      await tester.tap(find.text('Vaccinations'));
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationListPage), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Administered'), findsOneWidget);
      await open(tester, administered);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(pet.name)),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Edit vaccination'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(pet.name)),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.text('Next dose'), findsNothing);
      verifyNever(() => pets.getPetById(any()));
    },
  );

  testWidgets(
    'empty state opens creation with today and a submit action at the end',
    (tester) async {
      records = [];
      await pumpRouter(tester);
      expect(find.text('No vaccinations yet'), findsOneWidget);
      await add(tester);
      expect(
        find.text(
          MaterialLocalizations.of(
            tester.element(name),
          ).formatShortDate(DateTime.now()),
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Continue').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.widget<AppFormActions>(find.byType(AppFormActions)).fixed,
        isFalse,
      );
      await fill(tester, name, 'New vaccine');
      await submit(tester);
      expect(find.byType(VaccinationListPage), findsOneWidget);
      expect(records.single.vaccineName, 'New vaccine');
      expect(records.single.status, VaccinationStatus.administered);
    },
  );

  testWidgets(
    'name and note validation preserves overlong input without counters',
    (tester) async {
      await pumpRouter(tester);
      await add(tester);
      await submit(tester);
      expect(find.text('Enter a vaccine name').hitTestable(), findsOneWidget);
      final longName = '🐈' * 51;
      await fill(tester, name, longName);
      await submit(tester);
      expect(
        find.text('Keep vaccine name within 50 characters'),
        findsOneWidget,
      );
      expect(tester.widget<TextFormField>(name).controller!.text, longName);
      await fill(tester, name, '🐈' * 50);
      await fill(tester, notes, 'x' * 201);
      await submit(tester);
      expect(
        find.text('Keep notes within 200 characters').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('50/50'), findsNothing);
      verifyNever(
        () => repository.createVaccination(
          any(),
          nextDose: any(named: 'nextDose'),
        ),
      );
    },
  );

  testWidgets(
    'planned records show settings guidance without per-record controls',
    (tester) async {
      records = [planned];
      await pumpRouter(tester);
      await open(tester, planned);
      await tester.ensureVisible(
        find.text('Reminders are managed in Settings → Notifications.'),
      );
      expect(
        find.text('Reminders are managed in Settings → Notifications.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Edit vaccination'));
      await tester.pumpAndSettle();
      await fill(tester, notes, 'Care notes');
      await tester.ensureVisible(
        find.byKey(const Key('vaccination-reminder-guidance')),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('vaccination-reminder-guidance')))
            .dy,
        greaterThan(tester.getBottomLeft(notes).dy),
      );
      expect(find.text('Custom'), findsNothing);
      expect(find.text('Reminder preference'), findsNothing);
      expect(find.byKey(const Key('reminder-time')), findsNothing);
      await fill(tester, name, 'Corrected vaccine');
      await submit(tester);
      expect(records.single.vaccineName, 'Corrected vaccine');
    },
  );

  testWidgets('administration and independent next plan are created together', (
    tester,
  ) async {
    await pumpRouter(tester);
    await add(tester);
    await fill(tester, name, 'New vaccine');
    await fill(tester, clinic, 'Clinic A');
    await fill(tester, notes, 'Keep on the administration only');
    final nextDate = DateTime(DateTime.now().year + 1, 1, 2);
    await pickDate(tester, 'Next dose date (optional)', nextDate);
    final guidance = find.byKey(const Key('vaccination-reminder-guidance'));
    await tester.ensureVisible(guidance);
    expect(
      find.text('Reminders are managed in Settings → Notifications.'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(guidance).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('vaccination-next-date'))).dy,
      ),
    );
    await submit(tester);
    final created = records
        .where((v) => v.vaccineName == 'New vaccine')
        .toList();
    expect(created, hasLength(2));
    final next = created.singleWhere(
      (v) => v.status == VaccinationStatus.planned,
    );
    final given = created.singleWhere(
      (v) => v.status == VaccinationStatus.administered,
    );
    expect(next.date, nextDate);
    expect(next.id, isNot(given.id));
    expect(next.clinicName, isNull);
    expect(next.notes, isNull);
    expect(next.vetVisitId, isNull);
    expect(given.notes, 'Keep on the administration only');
  });

  testWidgets(
    'next-dose picker excludes administration day and changing administration revalidates the plan',
    (tester) async {
      await pumpRouter(tester);
      await add(tester);
      await fill(tester, name, 'New vaccine');
      final today = DateUtils.dateOnly(DateTime.now());
      await pickDate(
        tester,
        'Administration date',
        DateTime(today.year, today.month, today.day - 1),
      );
      await pickDate(tester, 'Next dose date (optional)', today);
      await pickDate(tester, 'Administration date', today);
      final next = tester.widget<AppDateField>(
        find.byKey(const Key('vaccination-next-date'), skipOffstage: false),
      );
      expect(next.firstDate, DateTime(today.year, today.month, today.day + 1));
      await submit(tester);
      expect(
        find.text('Choose a date after the administration date').hitTestable(),
        findsOneWidget,
      );
      verifyNever(
        () => repository.createVaccination(
          any(),
          nextDose: any(named: 'nextDose'),
        ),
      );
      await tester.tap(find.byTooltip('Clear next dose date (optional)'));
      await tester.pumpAndSettle();
      await submit(tester);
      expect(
        records.where((v) => v.vaccineName == 'New vaccine'),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'editing an overdue plan requires today or a future date without changing input on open',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final overdue = Vaccination(
        id: 'overdue',
        petId: pet.id,
        vaccineName: 'Overdue vaccine',
        status: VaccinationStatus.planned,
        date: DateTime(today.year, today.month, today.day - 1),
      );
      records = [overdue];
      await pumpRouter(tester);
      await open(tester, overdue);
      await tester.tap(find.byTooltip('Edit vaccination'));
      await tester.pumpAndSettle();
      final field = tester.widget<AppDateField>(
        find.byKey(const Key('vaccination-date'), skipOffstage: false),
      );
      expect(field.value, overdue.date);
      expect(field.firstDate, today);
      await fill(tester, name, 'Updated name');
      await submit(tester);
      expect(
        find.text('Choose today or a future date').hitTestable(),
        findsOneWidget,
      );
      verifyNever(
        () => repository.updateVaccination(
          any(),
          nextDose: any(named: 'nextDose'),
        ),
      );
      await tester.tap(
        find.byTooltip('Choose planned date', skipOffstage: false),
      );
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, today);
      expect(picker.initialDate, today);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppDateField>(
              find.byKey(const Key('vaccination-date'), skipOffstage: false),
            )
            .value,
        overdue.date,
      );
      await pickDate(tester, 'Planned date', today);
      await submit(tester);
      expect(records.single.date, today);
      expect(records.single.vaccineName, 'Updated name');
    },
  );

  testWidgets(
    'date bounds follow status and next-dose plans cannot be in the past',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      await pumpRouter(tester);
      await add(tester);
      expect(
        DateUtils.dateOnly(
          tester
              .widget<AppDateField>(
                find.byKey(const Key('vaccination-date'), skipOffstage: false),
              )
              .lastDate,
        ),
        today,
      );
      await pickDate(tester, 'Administration date', DateTime(2020));
      expect(
        tester
            .widget<AppDateField>(
              find.byKey(
                const Key('vaccination-next-date'),
                skipOffstage: false,
              ),
            )
            .firstDate,
        today,
      );
      await chooseStatus(tester, 'Planned');
      final plannedDate = tester.widget<AppDateField>(
        find.byKey(const Key('vaccination-date'), skipOffstage: false),
      );
      expect(plannedDate.firstDate, today);
      expect(plannedDate.value, today);
    },
  );

  testWidgets(
    'planned dates allow the future and hide administration-only fields',
    (tester) async {
      await pumpRouter(tester);
      await add(tester);
      await fill(tester, name, 'Future vaccine');
      await chooseStatus(tester, 'Planned');
      expect(
        find.byType(DropdownButtonFormField<String>, skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Next dose'), findsNothing);
      final future = DateTime(DateTime.now().year + 1, 2, 3);
      await pickDate(tester, 'Planned date', future);
      await submit(tester);
      final saved = records.singleWhere(
        (v) => v.vaccineName == 'Future vaccine',
      );
      expect(saved.status, VaccinationStatus.planned);
      expect(saved.date, future);
    },
  );

  testWidgets(
    'recording administration proposes today and keeps the existing ID',
    (tester) async {
      await pumpRouter(tester);
      await open(tester, planned);
      await tester.tap(find.text('Record administration'));
      await tester.pumpAndSettle();
      expect(
        records.singleWhere((v) => v.id == planned.id).status,
        VaccinationStatus.planned,
      );
      expect(find.text('Next dose (optional)'), findsOneWidget);
      await submit(tester);
      final saved = records.singleWhere((v) => v.id == planned.id);
      expect(saved.status, VaccinationStatus.administered);
      expect(saved.date, DateUtils.dateOnly(DateTime.now()));
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Record administration'), findsNothing);
      expect(find.text('History'), findsOneWidget);
    },
  );

  for (final size in [const Size(320, 568), const Size(640, 320)]) {
    testWidgets(
      'long linked visit stays compact and 150 visits remain selectable at $size',
      (tester) async {
        final visits = List.generate(
          150,
          (i) => VetVisit(
            id: 'visit-$i',
            petId: pet.id,
            visitedOn: DateTime(2020, 1, 2),
            reason: 'Visit $i — ${'Long visit reason ' * 9}',
            clinicName: 'Clinic $i',
            veterinarianName: 'Dr. $i',
          ),
        );
        when(
          () => visitRepository.getVetVisits(pet.id),
        ).thenAnswer((_) async => Success(visits));
        await pumpRouter(
          tester,
          size: size,
          scale: 2,
          brightness: Brightness.dark,
        );
        await add(tester);
        await fill(tester, name, 'Linked vaccine');
        final field = find.byType(
          DropdownButtonFormField<String>,
          skipOffstage: false,
        );
        await revealFormField(tester, field);
        await tester.pumpAndSettle();
        final initialHeight = tester.getSize(field).height;
        await tester.tap(field);
        await tester.pumpAndSettle();
        final last = find.descendant(
          of: find.byType(ListView),
          matching: find.textContaining('Visit 149 —'),
        );
        final menuScroll = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .last;
        await tester.scrollUntilVisible(
          last,
          400,
          scrollable: menuScroll,
          maxScrolls: 200,
        );
        await revealFormField(tester, last);
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(
          tester.getSize(field).height,
          lessThanOrEqualTo(initialHeight + 8),
        );
        final selected = find.descendant(
          of: field,
          matching: find.textContaining('Visit 149 —'),
        );
        expect(tester.widget<Text>(selected).maxLines, 1);
        expect(tester.widget<Text>(selected).overflow, TextOverflow.ellipsis);
        expect(
          tester.widget<TextFormField>(clinic).controller!.text,
          'Clinic 149',
        );
        expect(tester.widget<TextFormField>(vet).controller!.text, 'Dr. 149');
        await revealFormField(tester, field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        final first = find.descendant(
          of: find.byType(ListView),
          matching: find.textContaining('Visit 0 —'),
        );
        await tester.scrollUntilVisible(
          first,
          -400,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .last,
          maxScrolls: 200,
        );
        await revealFormField(tester, first);
        await tester.pumpAndSettle();
        await tester.tap(first);
        await tester.pumpAndSettle();
        await fill(tester, name, 'Linked vaccine');
        await submit(tester);
        expect(
          records
              .singleWhere((v) => v.vaccineName == 'Linked vaccine')
              .vetVisitId,
          'visit-0',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'visit selection fills only blank clinical fields and changing clinic keeps the vet',
    (tester) async {
      await pumpRouter(tester);
      await add(tester);
      await fill(tester, name, 'Linked vaccine');
      await fill(tester, clinic, 'Custom clinic');
      final field = find.byType(
        DropdownButtonFormField<String>,
        skipOffstage: false,
      );
      await revealFormField(tester, field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Checkup').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(clinic).controller!.text,
        'Custom clinic',
      );
      expect(tester.widget<TextFormField>(vet).controller!.text, 'Dr. Smith');
      await fill(tester, clinic, 'Clinic B');
      expect(tester.widget<TextFormField>(vet).controller!.text, 'Dr. Smith');
      await fill(tester, name, 'Linked vaccine');
      await submit(tester);
      expect(
        records
            .singleWhere((v) => v.vaccineName == 'Linked vaccine')
            .vetVisitId,
        visit.id,
      );
    },
  );

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'Edit' : 'Add'} vaccination suppresses Android stretch',
      (tester) async {
        final router = await pumpRouter(tester);
        if (editing) {
          router.push(
            AppRoutes.addEditVaccination(pet.id),
            extra: VaccinationFormExtra(
              petId: pet.id,
              petName: pet.name,
              vaccination: administered,
            ),
          );
          await tester.pumpAndSettle();
        } else {
          await add(tester);
        }
        final form = find.byType(VaccinationFormPage);
        expect(
          find.descendant(
            of: form,
            matching: find.byType(StretchingOverscrollIndicator),
          ),
          findsNothing,
        );
        await tester.drag(
          find.descendant(of: form, matching: find.byType(Scrollable)).first,
          const Offset(0, 400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'option failures can retry independently while entered text remains',
    (tester) async {
      when(
        () => repository.getSuggestions(clinicName: any(named: 'clinicName')),
      ).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Suggestions failed')),
      );
      when(() => visitRepository.getVetVisits(any())).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Visits failed')),
      );
      await pumpRouter(tester);
      await add(tester);
      await fill(tester, name, 'Manual vaccine');
      await revealFormField(tester, clinic);
      await revealFormField(tester, find.text('Retry visits'));
      expect(
        tester.getTopLeft(find.text('Retry visits')).dx,
        tester.getTopLeft(find.text('Visits failed')).dx,
      );
      await tester.tap(find.text('Retry visits'));
      await tester.pumpAndSettle();
      verify(() => visitRepository.getVetVisits(pet.id)).called(2);
      await revealFormField(tester, find.text('Retry suggestions'));
      expect(
        tester.getTopLeft(find.text('Retry suggestions')).dx,
        tester.getTopLeft(find.text('Suggestions failed')).dx,
      );
      await tester.tap(find.text('Retry suggestions'));
      await tester.pumpAndSettle();
      await submit(tester);
      expect(
        records
            .singleWhere((v) => v.vaccineName == 'Manual vaccine')
            .vaccineName,
        'Manual vaccine',
      );
    },
  );

  for (final editing in [false, true]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'dirty ${editing ? 'edit' : 'add'} protects ${systemBack ? 'system' : 'app bar'} back',
        (tester) async {
          await pumpRouter(tester);
          if (editing) {
            await open(tester, administered);
            await tester.tap(find.byTooltip('Edit vaccination'));
            await tester.pumpAndSettle();
          } else {
            await add(tester);
          }
          await fill(tester, name, 'Changed');
          await leaveForm(tester, systemBack: systemBack);
          expect(find.text('Discard changes?'), findsOneWidget);
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextFormField>(name).controller!.text,
            'Changed',
          );
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Discard changes'));
          await tester.pumpAndSettle();
          expect(find.byType(VaccinationFormPage), findsNothing);
        },
      );
    }
  }

  testWidgets('date-only edits are dirty and unchanged edits leave normally', (
    tester,
  ) async {
    await pumpRouter(tester);
    await open(tester, administered);
    await tester.tap(find.byTooltip('Edit vaccination'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    await tester.tap(find.byTooltip('Edit vaccination'));
    await tester.pumpAndSettle();
    await pickDate(tester, 'Administration date', DateTime(2020, 1, 3));
    await leaveForm(tester, systemBack: true);
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets(
    'pending save blocks exit and duplicates; failed save preserves input and retries',
    (tester) async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.createVaccination(
          any(),
          nextDose: any(named: 'nextDose'),
        ),
      ).thenAnswer((_) => pending.future);
      await pumpRouter(tester);
      await add(tester);
      await fill(tester, name, 'Keep this name');
      await fill(tester, notes, 'Keep this note');
      final action = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      await submit(tester, settle: false);
      action.onPressed!();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byTooltip('My pets'), findsNothing);
      expect(find.byType(VaccinationFormPage), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      pending.complete(const Error(LocalDatabaseFailure('Save failed')));
      await tester.pumpAndSettle();
      expect(find.text('Save failed').hitTestable(), findsOneWidget);
      expect(find.text('Retry save'), findsNothing);
      expect(
        find.widgetWithText(ElevatedButton, 'Add vaccination').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Keep this name',
      );
      expect(
        tester.widget<TextFormField>(notes).controller!.text,
        'Keep this note',
      );
      verify(
        () => repository.createVaccination(
          any(),
          nextDose: any(named: 'nextDose'),
        ),
      ).called(1);
      when(
        () => repository.createVaccination(
          any(),
          nextDose: any(named: 'nextDose'),
        ),
      ).thenAnswer((_) async => const Success(null));
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationListPage), findsOneWidget);
    },
  );

  testWidgets(
    'detail deletion returns a known ID and updates the list without another read',
    (tester) async {
      await pumpRouter(tester);
      await open(tester, administered);
      clearInteractions(repository);
      await tester.tap(find.byTooltip('Delete vaccination'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationListPage), findsOneWidget);
      expect(find.text(administered.vaccineName), findsNothing);
      verifyNever(() => repository.getVaccinations(any()));
    },
  );

  for (final brightness in Brightness.values) {
    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 2.0),
    ]) {
      testWidgets(
        'linked visit icons center on the title at $size in $brightness',
        (tester) async {
          final linked = Vaccination(
            id: administered.id,
            petId: pet.id,
            vaccineName: administered.vaccineName,
            status: administered.status,
            date: administered.date,
            vetVisitId: visit.id,
          );
          records = [linked];
          await pumpRouter(
            tester,
            size: size,
            scale: scale,
            brightness: brightness,
          );
          await open(tester, linked);
          final sectionStyle = tester
              .widget<Text>(find.text('Clinic & veterinarian'))
              .style!;
          final linkedVisitStyle = tester
              .widget<Text>(find.text('Linked vet visit'))
              .style!;
          expect(linkedVisitStyle.fontSize, sectionStyle.fontSize);
          expect(linkedVisitStyle.fontWeight, sectionStyle.fontWeight);
          final row = find.widgetWithText(ListTile, 'Linked vet visit');
          await revealFormField(tester, row);
          await tester.pumpAndSettle();
          final titleCenter = tester
              .getCenter(find.text('Linked vet visit'))
              .dy;
          for (final icon in [Icons.link_outlined]) {
            expect(
              tester.getSize(
                find.descendant(of: row, matching: find.byIcon(icon)),
              ),
              const Size(20, 20),
            );
            expect(
              tester
                  .getCenter(
                    find.descendant(of: row, matching: find.byIcon(icon)),
                  )
                  .dy,
              closeTo(titleCenter, 0.1),
            );
          }
          expect(row.hitTestable(), findsOneWidget);
          clearInteractions(visitRepository);
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.text('Checkup'), findsOneWidget);
          expect(find.byType(VaccinationDetailPage), findsOneWidget);
          verify(
            () => visitRepository.getVetVisitById(pet.id, visit.id),
          ).called(1);
          final arrow = find.byTooltip('Open vet visit');
          await revealFormField(tester, arrow);
          await tester.pumpAndSettle();
          expect(arrow.hitTestable(), findsOneWidget);
          await tester.tap(arrow);
          await tester.pumpAndSettle();
          expect(find.byType(VetVisitDetailPage), findsOneWidget);
          final visitSectionStyle = tester
              .widget<Text>(find.text('Clinic & veterinarian'))
              .style!;
          final vaccinationsStyle = tester
              .widget<Text>(find.text('Linked vaccinations'))
              .style!;
          expect(vaccinationsStyle.fontSize, visitSectionStyle.fontSize);
          expect(vaccinationsStyle.fontWeight, visitSectionStyle.fontWeight);
          await expandRelated(tester, 'Linked vaccinations');
          final vaccineArrow = find.byTooltip('Open vaccination: Rabies');
          await revealFormField(tester, vaccineArrow);
          await tester.pumpAndSettle();
          expect(vaccineArrow.hitTestable(), findsOneWidget);
          await tester.tap(vaccineArrow);
          await tester.pumpAndSettle();
          expect(find.byType(VaccinationDetailPage), findsOneWidget);
          await tester.tap(find.byTooltip('My pets'));
          await tester.pumpAndSettle();
          expect(
            find.text('Choose a pet to view its profile and care overview.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'a linked visit opens with context and its deletion refreshes only the link',
    (tester) async {
      final linked = Vaccination(
        id: administered.id,
        petId: pet.id,
        vaccineName: administered.vaccineName,
        status: administered.status,
        date: administered.date,
        clinicName: 'Clinic A',
        vetVisitId: visit.id,
      );
      records = [linked];
      when(() => visitRepository.deleteVetVisit(pet.id, visit.id)).thenAnswer((
        _,
      ) async {
        records = [administered];
        return const Success(null);
      });
      await pumpRouter(tester);
      await open(tester, linked);
      final link = find.widgetWithText(ListTile, 'Linked vet visit');
      await revealFormField(tester, link);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(link).dy,
        greaterThan(tester.getTopLeft(find.text('Veterinarian')).dy),
      );
      clearInteractions(pets);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('Checkup'), findsOneWidget);
      await revealFormField(tester, find.byTooltip('Open vet visit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open vet visit'));
      await tester.pumpAndSettle();
      verifyNever(() => pets.getPetById(any()));
      await tester.tap(find.byTooltip('Delete visit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.byType(VaccinationDetailPage), findsOneWidget);
      expect(find.text('Linked vet visit'), findsNothing);
      expect(find.text('Clinic A'), findsOneWidget);
    },
  );

  testWidgets('mismatched form extras never edit another pet record', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    router.push(
      AppRoutes.addEditVaccination(otherPet.id),
      extra: VaccinationFormExtra(
        petId: otherPet.id,
        petName: otherPet.name,
        vaccination: administered,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(name).controller!.text, isEmpty);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(otherPet.name),
      ),
      findsOneWidget,
    );
    await fill(tester, name, 'Other pet vaccine');
    await submit(tester);
    verifyNever(
      () =>
          repository.updateVaccination(any(), nextDose: any(named: 'nextDose')),
    );
    expect(
      records.singleWhere((v) => v.vaccineName == 'Other pet vaccine').petId,
      otherPet.id,
    );
  });

  testWidgets('missing detail URL and list failures have working retries', (
    tester,
  ) async {
    final router = await pumpRouter(
      tester,
      location: AppRoutes.vaccinationDetail(pet.id, 'missing'),
    );
    expect(find.text('Vaccination not found'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    verify(() => repository.getVaccinationById(pet.id, 'missing')).called(2);
    when(
      () => repository.getVaccinations(pet.id),
    ).thenAnswer((_) async => const Error(LocalDatabaseFailure('List failed')));
    router.go(AppRoutes.petDetail(pet.id));
    await tester.pumpAndSettle();
    router.go(AppRoutes.vaccinations(pet.id));
    await tester.pumpAndSettle();
    expect(find.text('List failed'), findsOneWidget);
    when(
      () => repository.getVaccinations(pet.id),
    ).thenAnswer((_) async => Success(records));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('delayed missing name lookup cannot reset form input', (
    tester,
  ) async {
    final pending = Completer<Result<Pet>>();
    when(() => pets.getPetById(any())).thenAnswer((_) => pending.future);
    await pumpRouter(tester, location: AppRoutes.addEditVaccination(pet.id));
    await fill(tester, name, 'Keep during lookup');
    pending.complete(const Success(pet));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(name).controller!.text,
      'Keep during lookup',
    );
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(pet.name)),
      findsOneWidget,
    );
  });

  testWidgets(
    'a failed name lookup leaves the form usable without inventing context',
    (tester) async {
      when(
        () => pets.getPetById(any()),
      ).thenAnswer((_) async => const Error(NotFoundFailure('Pet not found')));
      await pumpRouter(tester, location: AppRoutes.addEditVaccination(pet.id));
      await fill(tester, name, 'Still editable');
      expect(find.byType(VaccinationFormPage), findsOneWidget);
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Still editable',
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(pet.name)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'route identity changes refresh the visible and underlying pet context',
    (tester) async {
      final second = Vaccination(
        id: 'other-record',
        petId: otherPet.id,
        vaccineName: 'Other vaccine',
        status: VaccinationStatus.administered,
        date: administered.date,
      );
      records.add(second);
      final router = await pumpRouter(
        tester,
        location: AppRoutes.vaccinationDetail(pet.id, administered.id),
      );
      router.go(AppRoutes.vaccinationDetail(otherPet.id, second.id));
      await tester.pumpAndSettle();
      expect(find.text('Other vaccine'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(otherPet.name),
        ),
        findsOneWidget,
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.vaccinations(otherPet.id));
      expect(find.text(otherPet.name), findsOneWidget);
      expect(find.text(pet.name), findsNothing);
      verify(
        () => repository.getVaccinationById(otherPet.id, second.id),
      ).called(1);
    },
  );

  testWidgets('planned labels distinguish overdue today and upcoming records', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    records = [
      for (final day in [-1, 0, 1])
        Vaccination(
          id: 'plan-$day',
          petId: pet.id,
          vaccineName: 'Plan $day',
          status: VaccinationStatus.planned,
          date: DateTime(today.year, today.month, today.day + day),
        ),
    ];
    await pumpRouter(tester);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
  });

  testWidgets(
    'list deletion blocks exit, keeps scroll on failure and reconfirms retry',
    (tester) async {
      records = List.generate(
        12,
        (i) => Vaccination(
          id: 'row-$i',
          petId: pet.id,
          vaccineName: 'Vaccine $i',
          status: VaccinationStatus.administered,
          date: administered.date,
        ),
      );
      final pending = Completer<Result<void>>();
      when(
        () => repository.deleteVaccination(pet.id, 'row-8'),
      ).thenAnswer((_) => pending.future);
      await pumpRouter(tester);
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final remove = find.byTooltip('Delete Vaccine 8 from Jan 2, 2020');
      await tester.scrollUntilVisible(remove, 200, scrollable: scrollable);
      await revealFormField(tester, find.byKey(const ValueKey('row-8')));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scrollable).position;
      final originalOffset = position.pixels;
      clearInteractions(repository);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(VaccinationListPage), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      pending.complete(const Error(LocalDatabaseFailure('Delete failed')));
      await tester.pumpAndSettle();
      expect(position.pixels, originalOffset);
      expect(records, hasLength(12));
      expect(find.text('Retry deletion').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verify(() => repository.deleteVaccination(pet.id, 'row-8')).called(1);
      verifyNever(() => repository.getVaccinations(any()));
    },
  );

  testWidgets(
    'a stale linked visit can be cleared without discarding the form',
    (tester) async {
      records = [
        Vaccination(
          id: administered.id,
          petId: pet.id,
          vaccineName: administered.vaccineName,
          status: administered.status,
          date: administered.date,
          vetVisitId: 'deleted-visit',
        ),
      ];
      final router = await pumpRouter(tester);
      router.push(
        AppRoutes.addEditVaccination(pet.id),
        extra: VaccinationFormExtra(
          petId: pet.id,
          petName: pet.name,
          vaccination: records.single,
        ),
      );
      await tester.pumpAndSettle();
      final picker = find.byType(
        DropdownButtonFormField<String>,
        skipOffstage: false,
      );
      await revealFormField(tester, picker);
      await tester.pumpAndSettle();
      expect(find.text('Linked visit unavailable'), findsOneWidget);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('No linked visit').last);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(records.single.vetVisitId, isNull);
      expect(records.single.vaccineName, administered.vaccineName);
    },
  );

  testWidgets('list detail and form expose labeled tap targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpRouter(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await open(tester, administered);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.byTooltip('Edit vaccination'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'clinical suggestions stay stable through pending loads at $size in $brightness',
        (tester) async {
          await tester.runAsync(loadFormTestFont);
          await pumpRouter(
            tester,
            size: size,
            scale: 2,
            brightness: brightness,
            keyboard: size.width == 320,
          );
          await add(tester);
          await fill(tester, name, 'Care vaccine');
          await fill(tester, clinic, 'C');
          final neighbor = tester.getRect(vet);
          final height = tester.getSize(clinic).height;
          final pending = Completer<Result<VaccinationSuggestions>>();
          when(
            () => repository.getSuggestions(clinicName: 'Cli'),
          ).thenAnswer((_) => pending.future);
          await enterFormText(tester, clinic, 'Cli');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.getRect(vet), neighbor);
          expect(tester.getSize(clinic).height, height);
          pending.complete(
            const Success(
              VaccinationSuggestions(
                vaccineNames: ['Rabies'],
                clinicNames: ['Clinic A', 'Clinic B'],
                veterinarianNames: [],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(vet), neighbor);
          final option = find.widgetWithText(MenuItemButton, 'Clinic B');
          await revealFormField(tester, option);
          await tester.pumpAndSettle();
          expect(option.hitTestable(), findsOneWidget);
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextFormField>(clinic).controller!.text,
            'Clinic B',
          );
          expect(
            tester
                .element(find.byType(VaccinationFormPage))
                .read<VaccinationFormCubit>()
                .state
                .suggestions
                .veterinarianNames,
            ['Dr. Jones'],
          );
          await fill(tester, vet, 'Dr.');
          final veterinarian = find.widgetWithText(MenuItemButton, 'Dr. Jones');
          expect(veterinarian, findsOneWidget);
          expect(veterinarian.hitTestable(), findsOneWidget);
          await tester.tap(veterinarian);
          await tester.pumpAndSettle();
          await submit(tester);
          final saved = records.singleWhere(
            (v) => v.vaccineName == 'Care vaccine',
          );
          expect(saved.clinicName, 'Clinic B');
          expect(saved.veterinarianName, 'Dr. Jones');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'planned detail action stays outside the card and recovery remains reachable at $size in $brightness',
        (tester) async {
          final record = Vaccination(
            id: planned.id,
            petId: planned.petId,
            vaccineName: planned.vaccineName,
            status: planned.status,
            date: planned.date,
            notes: 'Note ' * 40,
          );
          records = [record];
          await pumpRouter(
            tester,
            size: size,
            scale: 2,
            brightness: brightness,
          );
          await open(tester, record);
          final action = find.widgetWithText(
            ElevatedButton,
            'Record administration',
          );
          expect(
            find.ancestor(of: action, matching: find.byType(Card)),
            findsNothing,
          );
          if (size.width < size.height) {
            expect(action.hitTestable(), findsOneWidget);
            expect(
              tester.widget<AppFormActions>(find.byType(AppFormActions)).fixed,
              isTrue,
            );
            expect(
              tester.getRect(find.byType(AppFormActions)).bottom,
              size.height,
            );
            expect(
              tester.getRect(find.byType(SingleChildScrollView)).bottom,
              lessThanOrEqualTo(tester.getRect(action).top),
            );
            await tester.drag(
              find.byType(SingleChildScrollView),
              const Offset(0, -500),
            );
          } else {
            expect(
              tester.widget<AppFormActions>(find.byType(AppFormActions)).fixed,
              isFalse,
            );
            await revealFormField(tester, action);
          }
          await tester.pumpAndSettle();
          expect(action.hitTestable(), findsOneWidget);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(find.byType(VaccinationFormPage), findsOneWidget);
          expect(
            tester
                .widget<DropdownButtonFormField<VaccinationStatus>>(
                  find.byType(
                    DropdownButtonFormField<VaccinationStatus>,
                    skipOffstage: false,
                  ),
                )
                .initialValue,
            VaccinationStatus.administered,
          );
          verifyNever(
            () => repository.updateVaccination(
              any(),
              nextDose: any(named: 'nextDose'),
            ),
          );
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          await revealFormField(tester, find.text('Discard changes').last);
          await tester.tap(find.text('Discard changes').last);
          await tester.pumpAndSettle();
          final deletion = Completer<Result<void>>();
          when(
            () => repository.deleteVaccination(any(), any()),
          ).thenAnswer((_) => deletion.future);
          await tester.tap(find.byTooltip('Delete vaccination'));
          await tester.pumpAndSettle();
          await revealFormField(tester, find.text('Delete').last);
          await tester.tap(find.text('Delete').last);
          await tester.pump();
          expect(tester.widget<ElevatedButton>(action).onPressed, isNull);
          deletion.complete(const Error(LocalDatabaseFailure('Delete failed')));
          await tester.pumpAndSettle();
          expect(find.text('Delete failed').hitTestable(), findsOneWidget);
          expect(find.text('Retry deletion').hitTestable(), findsOneWidget);
          if (size.width < size.height) {
            expect(action.hitTestable(), findsOneWidget);
          }
          await tester.tap(find.text('Retry deletion'));
          await tester.pumpAndSettle();
          await revealFormField(tester, find.text('Cancel'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'save and destructive retry remain usable at $size in $brightness with large text',
        (tester) async {
          await pumpRouter(
            tester,
            size: size,
            scale: 2,
            brightness: brightness,
            keyboard: size.width == 320,
          );
          await open(tester, administered);
          await tester.tap(find.byTooltip('Edit vaccination'));
          await tester.pumpAndSettle();
          await fill(tester, name, 'Changed vaccine');
          when(
            () => repository.updateVaccination(
              any(),
              nextDose: any(named: 'nextDose'),
            ),
          ).thenAnswer(
            (_) async => const Error(
              LocalDatabaseFailure('Failed to update vaccination'),
            ),
          );
          await submit(tester);
          await checkFormError(tester, 'Failed to update vaccination');
          expect(find.byType(ElevatedButton).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(find.text('Retry save'), findsNothing);
          when(
            () => repository.updateVaccination(
              any(),
              nextDose: any(named: 'nextDose'),
            ),
          ).thenAnswer((_) async => const Success(null));
          await tester.tap(find.byType(ElevatedButton));
          await tester.pumpAndSettle();
          expect(find.byType(VaccinationDetailPage), findsOneWidget);
          when(() => repository.deleteVaccination(any(), any())).thenAnswer(
            (_) async => const Error(LocalDatabaseFailure('Delete failed')),
          );
          await tester.tap(find.byTooltip('Delete vaccination'));
          await tester.pumpAndSettle();
          await revealFormField(tester, find.text('Delete').last);
          await tester.tap(find.text('Delete').last);
          await tester.pumpAndSettle();
          expect(find.text('Delete failed').hitTestable(), findsOneWidget);
          expect(find.text('Retry deletion').hitTestable(), findsOneWidget);
          clearInteractions(repository);
          await tester.tap(find.text('Retry deletion'));
          await tester.pumpAndSettle();
          await revealFormField(tester, find.text('Cancel'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          verifyNever(() => repository.deleteVaccination(any(), any()));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'floating FAB and final list control stay usable at $size in $brightness',
        (tester) async {
          records = List.generate(
            16,
            (i) => Vaccination(
              id: 'row-$i',
              petId: pet.id,
              vaccineName: 'Vaccine $i',
              status: VaccinationStatus.administered,
              date: administered.date,
            ),
          );
          await pumpRouter(
            tester,
            size: size,
            scale: 2,
            brightness: brightness,
          );
          final scroll = find.byType(CustomScrollView);
          final lastDelete = find.byTooltip(
            'Delete Vaccine 15 from Jan 2, 2020',
          );
          await tester.scrollUntilVisible(
            lastDelete,
            300,
            scrollable: find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first,
          );
          await revealFormField(tester, find.byKey(const ValueKey('row-15')));
          await tester.pumpAndSettle();
          final button = tester.getRect(find.byType(FloatingActionButton));
          expect(tester.getRect(scroll).bottom, size.height - 34);
          expect(tester.getRect(scroll).overlaps(button), isTrue);
          final control = tester.getRect(lastDelete);
          expect(control.overlaps(button), isFalse);
          expect(lastDelete.hitTestable(), findsOneWidget);
          await tester.tap(lastDelete);
          await tester.pumpAndSettle();
          await revealFormField(tester, find.text('Delete').last);
          await tester.tap(find.text('Delete').last);
          await tester.pumpAndSettle();
          expect(records.any((v) => v.id == 'row-15'), isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
