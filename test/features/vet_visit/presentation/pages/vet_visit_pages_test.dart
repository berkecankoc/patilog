import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'dart:async';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';

import 'package:flutter/material.dart';
import '../../../../helpers/all_pets_care_dependencies.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
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
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/vet_visit/data/models/vet_visit_model.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_list_page.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_detail_page.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_form_page.dart';
import 'package:petlytics/core/widgets/app_suggestion_field.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';

class MockVetRepository extends Mock implements VetVisitRepository {}

class MockMedications extends Mock implements MedicationRepository {}

class MockVaccinations extends Mock implements VaccinationRepository {}

class MockPetRepository extends Mock implements PetRepository {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

class MockDeletePet extends Mock implements DeletePet {}

class MockImageStorage extends Mock implements ImageStorage {}

class MockIds extends Mock implements IdGenerator {}

void main() {
  const pet = Pet(
    id: 'pet-1',
    name: 'Milo',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  final visit = VetVisit(
    id: 'visit-1',
    petId: pet.id,
    visitedOn: DateTime(2025, 1, 12),
    reason: 'Annual checkup',
    clinicName: 'Clinic A',
    veterinarianName: 'Dr. Smith',
    diagnosis: 'Healthy',
    notes: 'Routine follow-up',
    costMinorUnits: 125050,
    currency: VetVisitCurrency.turkishLira,
  );
  late MockVetRepository repository;
  late MockPetRepository pets;
  late List<VetVisit> visits;

  VetVisit stored(VetVisit value) => VetVisitModel.fromJson(
    VetVisitModel.fromEntity(value).toJson(),
  ).toEntity();

  setUpAll(() => registerFallbackValue(visit));
  setUp(() {
    visits = [visit];
    repository = MockVetRepository();
    when(() => repository.getVetVisits(any())).thenAnswer(
      (invocation) async => Success(
        visits
            .where((v) => v.petId == invocation.positionalArguments.first)
            .toList(),
      ),
    );
    when(() => repository.getVetVisitById(any(), any())).thenAnswer((
      invocation,
    ) async {
      final found = visits.where(
        (v) =>
            v.petId == invocation.positionalArguments[0] &&
            v.id == invocation.positionalArguments[1],
      );
      return found.isEmpty
          ? const Error(NotFoundFailure('Vet visit not found'))
          : Success(found.single);
    });
    when(
      () => repository.getSuggestions(clinicName: any(named: 'clinicName')),
    ).thenAnswer((invocation) async {
      final clinic = (invocation.namedArguments[#clinicName] as String?)
          ?.trim()
          .toLowerCase();
      return Success(
        VetVisitSuggestions(
          clinicNames: const ['Clinic A', 'Clinic B'],
          veterinarianNames: clinic == 'clinic b'
              ? ['Dr. Jones']
              : ['Dr. Smith'],
        ),
      );
    });
    when(() => repository.createVetVisit(any())).thenAnswer((invocation) async {
      visits = [
        stored(invocation.positionalArguments.first as VetVisit),
        ...visits,
      ];
      return const Success(null);
    });
    when(() => repository.updateVetVisit(any())).thenAnswer((invocation) async {
      final changed = stored(invocation.positionalArguments.first as VetVisit);
      visits = [
        for (final v in visits)
          if (v.id == changed.id) changed else v,
      ];
      return const Success(null);
    });
    when(() => repository.deleteVetVisit(any(), any())).thenAnswer((
      invocation,
    ) async {
      visits = visits
          .where((v) => v.id != invocation.positionalArguments[1])
          .toList();
      return const Success(null);
    });
    final ids = MockIds();
    when(ids.generate).thenReturn('new-visit');
    pets = MockPetRepository();
    when(pets.getPets).thenAnswer((_) async => const Success([pet]));
    when(
      () => pets.getPetById(any()),
    ).thenAnswer((_) async => const Success(pet));
    registerAllPetsCare(pets);
    getIt.registerFactory<PetCubit>(
      () => PetCubit(pets, MockCreatePet(), MockUpdatePet(), MockDeletePet()),
    );
    getIt.registerFactory<VetVisitCubit>(() => VetVisitCubit(repository));
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
    getIt.registerFactory<VaccinationCubit>(
      () => VaccinationCubit(MockVaccinations()),
    );
    getIt.registerFactory<VetVisitFormCubit>(
      () => VetVisitFormCubit(repository, ids),
    );
  });
  tearDown(() async => getIt.reset());

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    String? location,
    double width = 390,
    double height = 760,
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool keyboard = false,
    EdgeInsets safePadding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: location ?? AppRoutes.vetVisits(pet.id),
      routes: appRouter.configuration.routes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard ? 280 : 0),
            viewPadding: safePadding,
            padding: safePadding.copyWith(
              bottom: keyboard ? 0 : safePadding.bottom,
            ),
          ),
          child: RepositoryProvider<ImageStorage>.value(
            value: MockImageStorage(),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openAdd(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add visit'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('My pets'), findsNothing);
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.tap(find.text(visit.reason));
    await tester.pumpAndSettle();
  }

  for (final editing in [false, true]) {
    testWidgets(
      'multi-step visit ${editing ? 'edit' : 'add'} reviews before saving',
      (tester) async {
        await pumpRouter(tester);
        if (editing) {
          await openDetail(tester);
          await tester.tap(find.byTooltip('Edit visit'));
          await tester.pumpAndSettle();
        } else {
          await openAdd(tester);
        }
        expect(
          find.text(editing ? 'Step 2 of 2 · Review' : 'Step 1 of 2 · Visit'),
          findsOneWidget,
        );
        final reason = find.byKey(
          const Key('visit-reason'),
          skipOffstage: false,
        );
        await enterFormText(tester, reason, 'Checkup');
        await reviewForm(tester);
        expect(find.text('Review visit'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Edit'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextButton, 'Back'), findsNothing);
        expect(
          tester.widget<TextFormField>(reason).controller!.text,
          'Checkup',
        );
        await reviewForm(tester);
        verifyNever(() => repository.createVetVisit(any()));
        verifyNever(() => repository.updateVetVisit(any()));
      },
    );
    testWidgets(
      '${editing ? 'Edit' : 'Add'} visit suppresses Android stretch',
      (tester) async {
        await pumpRouter(tester);
        if (editing) {
          await openDetail(tester);
          await tester.tap(find.byTooltip('Edit visit'));
          await tester.pumpAndSettle();
        } else {
          await openAdd(tester);
        }
        final form = find.byType(VetVisitFormPage);
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

  Future<void> fill(WidgetTester tester, Finder field, String value) async {
    await revealFormField(tester, field);
    await enterFormText(tester, field, value);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) => submitForm(tester);

  final reasonField = find.byKey(
    const Key('visit-reason'),
    skipOffstage: false,
  );

  final amountField = find.byKey(const Key('visit-cost'), skipOffstage: false);
  final clinicField = find.widgetWithText(
    TextFormField,
    'Clinic (optional)',
    skipOffstage: false,
  );
  final veterinarianField = find.widgetWithText(
    TextFormField,
    'Veterinarian (optional)',
    skipOffstage: false,
  );

  testWidgets(
    'visit list, detail and both forms keep the pet name in the app bar',
    (tester) async {
      await pumpRouter(tester);
      clearInteractions(pets);
      final name = find.descendant(
        of: find.byType(AppBar),
        matching: find.text(pet.name),
      );
      expect(name.hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Add visit'));
      await tester.pumpAndSettle();
      expect(name.hitTestable(), findsOneWidget);
      expect(
        tester.widget<VetVisitFormPage>(find.byType(VetVisitFormPage)).visit,
        isNull,
      );
      verifyNever(() => pets.getPetById(any()));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await openDetail(tester);
      expect(name.hitTestable(), findsOneWidget);
      final date = MaterialLocalizations.of(
        tester.element(find.byType(VetVisitDetailPage)),
      ).formatShortDate(visit.visitedOn);
      final icon = tester.getRect(find.byIcon(Icons.event_note_outlined));
      expect(
        tester.getRect(find.text(date)).center.dy,
        closeTo(icon.center.dy, 1),
      );
      expect(find.text('Visit date'), findsNothing);
      await tester.tap(find.byTooltip('Edit visit'));
      await tester.pumpAndSettle();
      expect(name.hitTestable(), findsOneWidget);
      expect(
        tester.widget<VetVisitFormPage>(find.byType(VetVisitFormPage)).visit,
        visit,
      );
      verifyNever(() => pets.getPetById(any()));
    },
  );

  testWidgets(
    'direct visit URLs show the selected pet after changing pet IDs',
    (tester) async {
      const other = Pet(
        id: 'pet-2',
        name: 'Luna',
        species: PetSpecies.bird,
        sex: PetSex.unknown,
        reproductiveStatus: ReproductiveStatus.unknown,
      );
      when(
        () => pets.getPetById(other.id),
      ).thenAnswer((_) async => Success(other));
      final router = await pumpRouter(
        tester,
        location: AppRoutes.vetVisitDetail(pet.id, visit.id),
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(pet.name)),
        findsOneWidget,
      );
      final secondVisit = VetVisit(
        id: 'visit-2',
        petId: pet.id,
        visitedOn: DateTime(2026, 10, 15),
        reason: 'Dental checkup',
      );
      visits.add(secondVisit);
      router.go(AppRoutes.vetVisitDetail(pet.id, secondVisit.id));
      await tester.pumpAndSettle();
      expect(find.text(secondVisit.reason), findsOneWidget);
      expect(find.text(visit.reason), findsNothing);
      router.go(AppRoutes.vetVisits(other.id));
      await tester.pumpAndSettle();
      expect(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.text(other.name),
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text(pet.name), findsNothing);
      expect(find.text(visit.reason), findsNothing);
      router.go(AppRoutes.vetVisits(pet.id));
      await tester.pumpAndSettle();
      expect(
        find
            .descendant(of: find.byType(AppBar), matching: find.text(pet.name))
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text(visit.reason), findsOneWidget);
    },
  );

  testWidgets('profile opens visits and a detail URL loads without extra', (
    tester,
  ) async {
    final router = await pumpRouter(
      tester,
      location: AppRoutes.petDetail(pet.id),
    );
    clearInteractions(pets);
    await revealFormField(tester, find.text('Vet visits'));
    await tester.tap(find.text('Vet visits'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.vetVisits(pet.id));
    await openDetail(tester);
    expect(router.state.uri.path, AppRoutes.vetVisitDetail(pet.id, visit.id));
    expect(find.text('Annual checkup'), findsOneWidget);
    await revealFormField(tester, find.text('1250.50 TRY'));
    expect(find.text('1250.50 TRY'), findsOneWidget);
    verify(() => repository.getVetVisitById(pet.id, visit.id)).called(1);
    verifyNever(() => pets.getPetById(any()));
  });

  testWidgets('empty list opens a form with today and optional fields', (
    tester,
  ) async {
    visits = [];
    await pumpRouter(tester);
    expect(find.text('No visits yet'), findsOneWidget);
    await openAdd(tester);
    final date = MaterialLocalizations.of(
      tester.element(find.byType(VetVisitFormPage)),
    ).formatShortDate(DateTime.now());
    expect(find.text(date), findsOneWidget);
    await fill(tester, reasonField, 'Checkup');
    await save(tester);
    expect(find.byType(VetVisitListPage), findsOneWidget);
    expect(find.text('Checkup'), findsOneWidget);
    final created =
        verify(() => repository.createVetVisit(captureAny())).captured.single
            as VetVisit;
    expect(created.id, 'new-visit');
    expect(created.costMinorUnits, isNull);
    expect(created.currency, isNull);
  });

  testWidgets('reason is required and invalid money cannot be saved', (
    tester,
  ) async {
    await pumpRouter(tester);
    await openAdd(tester);
    await save(tester);
    expect(
      find.text('Enter a reason for the visit').hitTestable(),
      findsOneWidget,
    );
    await fill(tester, reasonField, 'Checkup');
    for (final input in ['-1', '1.234', 'Infinity', '92233720368547758.08']) {
      await fill(tester, amountField, input);
      await save(tester);
      expect(
        find
            .text('Enter a valid amount with up to 2 decimal places')
            .hitTestable(),
        findsOneWidget,
      );
    }
    verifyNever(() => repository.createVetVisit(any()));
  });

  for (final editing in [false, true]) {
    testWidgets(
      'visit reason precedes the date and validates 100 visible characters in ${editing ? 'edit' : 'add'}',
      (tester) async {
        await pumpRouter(tester);
        if (editing) {
          await openDetail(tester);
          await tester.tap(find.byTooltip('Edit visit'));
          await tester.pumpAndSettle();
        } else {
          await openAdd(tester);
        }
        await revealFormField(tester, reasonField);
        expect(
          tester.getTopLeft(reasonField).dy,
          lessThan(tester.getTopLeft(find.byType(AppDateField)).dy),
        );
        final tooLong = '🐈‍⬛' * 101;
        await fill(tester, reasonField, tooLong);
        await save(tester);
        expect(
          find.text('Keep reason within 100 characters').hitTestable(),
          findsOneWidget,
        );
        expect(
          tester.widget<TextFormField>(reasonField).controller!.text,
          tooLong,
        );
        verifyNever(() => repository.createVetVisit(any()));
        verifyNever(() => repository.updateVetVisit(any()));
        final valid = '🐈‍⬛' * 100;
        await fill(tester, reasonField, valid);
        await save(tester);
        final saved =
            verify(
                  () => editing
                      ? repository.updateVetVisit(captureAny())
                      : repository.createVetVisit(captureAny()),
                ).captured.single
                as VetVisit;
        expect(saved.reason, valid);
      },
    );
  }

  for (final editing in [false, true]) {
    testWidgets(
      editing
          ? 'edit visit saves from the first fields with fixed actions'
          : 'add visit saves only from Review with fixed actions',
      (tester) async {
        await pumpRouter(tester);
        if (editing) {
          await openDetail(tester);
          await tester.tap(find.byTooltip('Edit visit'));
          await tester.pumpAndSettle();
        } else {
          await openAdd(tester);
        }
        final button = find.widgetWithText(
          ElevatedButton,
          editing ? 'Save changes' : 'Add visit',
        );
        if (!editing) expect(button, findsNothing);
        await fill(tester, reasonField, 'Follow-up');
        await reviewForm(tester);
        expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
        expect(button.hitTestable(), findsOneWidget);
        verifyNever(() => repository.createVetVisit(any()));
        verifyNever(() => repository.updateVetVisit(any()));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(VetVisitFormPage), findsNothing);
        if (editing) {
          verify(() => repository.updateVetVisit(any())).called(1);
        } else {
          verify(() => repository.createVetVisit(any())).called(1);
        }
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final (size, scale, keyboard) in [
      (const Size(390, 844), 1.0, false),
      (const Size(320, 568), 2.0, true),
      (const Size(640, 320), 2.0, false),
    ]) {
      testWidgets(
        'pet and visit edit footers match with safe areas at $size in $brightness',
        (tester) async {
          final router = await pumpRouter(
            tester,
            width: size.width,
            height: size.height,
            scale: scale,
            brightness: brightness,
            keyboard: keyboard,
            safePadding: const EdgeInsets.only(bottom: 34),
          );
          router.push<bool>(AppRoutes.addEditPet, extra: pet);
          await tester.pumpAndSettle();
          final petButton = tester.getRect(
            find.widgetWithText(ElevatedButton, 'Save changes'),
          );
          final petActions = tester.getRect(
            find.byKey(const ValueKey('multi-step-form-actions')),
          );
          final petSurface = tester
              .widget<Material>(
                find.byKey(const ValueKey('multi-step-form-actions')),
              )
              .color;
          expect(petActions.bottom, size.height - (keyboard ? 280 : 0));
          router.pop();
          await tester.pumpAndSettle();
          router.push<bool>(AppRoutes.addEditVetVisit(pet.id), extra: visit);
          await tester.pumpAndSettle();
          final visitButton = find.widgetWithText(
            ElevatedButton,
            'Save changes',
          );
          expect(tester.getRect(visitButton), petButton);
          expect(
            tester.getRect(
              find.byKey(const ValueKey('multi-step-form-actions')),
            ),
            petActions,
          );
          expect(
            tester
                .widget<Material>(
                  find.byKey(const ValueKey('multi-step-form-actions')),
                )
                .color,
            petSurface,
          );
          expect(visitButton.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'comma money, currency and medical details reach the saved record',
    (tester) async {
      await pumpRouter(tester);
      await openAdd(tester);
      await fill(tester, reasonField, 'Checkup');
      await fill(
        tester,
        find.byKey(const Key('visit-diagnosis'), skipOffstage: false),
        'Healthy',
      );
      await fill(
        tester,
        find.byKey(const Key('visit-notes'), skipOffstage: false),
        'Review next year',
      );
      await fill(tester, amountField, '25,99');
      await revealFormField(
        tester,
        find.byType(DropdownButtonFormField<VetVisitCurrency>),
      );
      await tester.tap(find.byType(DropdownButtonFormField<VetVisitCurrency>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EUR').last);
      await tester.pumpAndSettle();
      await save(tester);
      final created =
          verify(() => repository.createVetVisit(captureAny())).captured.single
              as VetVisit;
      expect(created.costMinorUnits, 2599);
      expect(created.currency, VetVisitCurrency.euro);
      expect(created.diagnosis, 'Healthy');
      expect(created.notes, 'Review next year');
    },
  );

  testWidgets(
    'clinic suggestions filter veterinarians without erasing typed input',
    (tester) async {
      await pumpRouter(tester);
      await openAdd(tester);
      await fill(tester, reasonField, 'Follow-up');
      await fill(tester, veterinarianField, 'My veterinarian');
      await fill(tester, clinicField, 'Clinic');
      await tester.tap(find.widgetWithText(MenuItemButton, 'Clinic B'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(veterinarianField).controller!.text,
        'My veterinarian',
      );
      await fill(tester, veterinarianField, 'Dr.');
      expect(find.widgetWithText(MenuItemButton, 'Dr. Jones'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, 'Dr. Smith'), findsNothing);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Dr. Jones'));
      await tester.pumpAndSettle();
      await fill(tester, reasonField, 'Follow-up');
      await save(tester);
      final created =
          verify(() => repository.createVetVisit(captureAny())).captured.single
              as VetVisit;
      expect(created.clinicName, 'Clinic B');
      expect(created.veterinarianName, 'Dr. Jones');
    },
  );

  testWidgets(
    'suggestion errors retry independently and do not block manual entry',
    (tester) async {
      var failed = true;
      when(
        () => repository.getSuggestions(clinicName: any(named: 'clinicName')),
      ).thenAnswer(
        (_) async => failed
            ? const Error(LocalDatabaseFailure('Could not load suggestions'))
            : const Success(
                VetVisitSuggestions(clinicNames: [], veterinarianNames: []),
              ),
      );
      await pumpRouter(tester);
      await openAdd(tester);
      await fill(tester, reasonField, 'Checkup');
      await fill(tester, clinicField, 'New clinic');
      await revealFormField(tester, find.text('Retry suggestions'));
      expect(
        tester.getTopLeft(find.text('Retry suggestions')).dx,
        tester.getTopLeft(find.text('Failed to load suggestions')).dx,
      );
      failed = false;
      await tester.tap(find.text('Retry suggestions'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to load suggestions'), findsNothing);
      expect(
        tester.widget<TextFormField>(clinicField).controller!.text,
        'New clinic',
      );
      await save(tester);
      expect(find.byType(VetVisitListPage), findsOneWidget);
    },
  );

  testWidgets(
    'editing refreshes detail and list, and optional fields can be removed',
    (tester) async {
      await pumpRouter(tester);
      await openDetail(tester);
      await tester.tap(find.byTooltip('Edit visit'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Save changes'),
            )
            .onPressed,
        isNull,
      );
      await fill(tester, reasonField, 'Updated checkup');
      await fill(tester, clinicField, '');
      await fill(tester, amountField, '');
      await save(tester);
      expect(find.byType(VetVisitDetailPage), findsOneWidget);
      expect(find.text('Updated checkup'), findsOneWidget);
      expect(find.text('Clinic'), findsOneWidget);
      expect(find.text('Cost'), findsOneWidget);
      expect(find.text('Not provided'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(VetVisitListPage), findsOneWidget);
      expect(find.text('Updated checkup'), findsOneWidget);
      expect(find.text('Annual checkup'), findsNothing);
    },
  );

  for (final editing in [false, true]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'dirty $editing form protects ${systemBack ? 'system' : 'app bar'} back',
        (tester) async {
          await pumpRouter(tester);
          if (editing) {
            await openDetail(tester);
            await tester.tap(find.byTooltip('Edit visit'));
            await tester.pumpAndSettle();
          } else {
            await openAdd(tester);
          }
          await fill(tester, reasonField, 'Changed reason');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          Future<void> back() async {
            await leaveForm(tester, systemBack: systemBack);
          }

          await back();
          expect(find.text('Discard changes?'), findsOneWidget);
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextFormField>(reasonField).controller!.text,
            'Changed reason',
          );
          await back();
          await tester.tap(find.text('Discard changes'));
          await tester.pumpAndSettle();
          expect(find.byType(VetVisitFormPage), findsNothing);
          verifyNever(() => repository.createVetVisit(any()));
          verifyNever(() => repository.updateVetVisit(any()));
        },
      );
    }
  }

  testWidgets(
    'unchanged edit leaves without warning and date-only edits are protected',
    (tester) async {
      await pumpRouter(tester);
      await openDetail(tester);
      await tester.tap(find.byTooltip('Edit visit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      await tester.tap(find.byTooltip('Edit visit'));
      await tester.pumpAndSettle();
      await tapFormControl(
        tester,
        find.byTooltip('Visit date: choose date', skipOffstage: false),
      );
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(
        DateUtils.dateOnly(picker.lastDate),
        DateUtils.dateOnly(DateTime.now()),
      );
      await tester.tap(find.text('11').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await leaveForm(tester, systemBack: true);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Jan 11, 2025'), findsOneWidget);
    },
  );

  testWidgets(
    'pending save blocks back and duplicates, failure retains all input and allows retry',
    (tester) async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.createVetVisit(any()),
      ).thenAnswer((_) => pending.future);
      await pumpRouter(tester);
      await openAdd(tester);
      await fill(tester, reasonField, 'Checkup');
      await fill(
        tester,
        find.byKey(const Key('visit-notes'), skipOffstage: false),
        'Keep this note',
      );
      await fill(tester, amountField, '0');
      await reviewForm(tester);
      final submit = tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(find.byTooltip('My pets'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.byType(VetVisitFormPage), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      pending.complete(
        const Error(LocalDatabaseFailure('Failed to create vet visit')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Failed to create vet visit').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(reasonField).controller!.text,
        'Checkup',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('visit-notes'), skipOffstage: false),
            )
            .controller!
            .text,
        'Keep this note',
      );
      expect(tester.widget<TextFormField>(amountField).controller!.text, '0');
      verify(() => repository.createVetVisit(any())).called(1);
      when(
        () => repository.createVetVisit(any()),
      ).thenAnswer((_) async => const Success(null));
      await save(tester);
      expect(find.byType(VetVisitListPage), findsOneWidget);
      verify(() => repository.createVetVisit(any())).called(1);
    },
  );

  for (final confirm in [false, true]) {
    testWidgets('deletion confirm=$confirm updates only after confirmation', (
      tester,
    ) async {
      await pumpRouter(tester);
      await openDetail(tester);
      await tester.tap(find.byTooltip('Delete visit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(confirm ? 'Delete' : 'Cancel'));
      await tester.pumpAndSettle();
      if (confirm) {
        expect(find.text('No visits yet'), findsOneWidget);
        verify(() => repository.deleteVetVisit(pet.id, visit.id)).called(1);
        verify(() => repository.getVetVisits(pet.id)).called(1);
      } else {
        expect(find.byType(VetVisitDetailPage), findsOneWidget);
        verifyNever(() => repository.deleteVetVisit(any(), any()));
      }
    });
  }

  testWidgets(
    'pending deletion blocks exit and failure retry requires fresh confirmation',
    (tester) async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.deleteVetVisit(pet.id, visit.id),
      ).thenAnswer((_) => pending.future);
      await pumpRouter(tester);
      await openDetail(tester);
      await revealFormField(tester, find.text('1250.50 TRY'));
      await tester.tap(find.byTooltip('Delete visit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(VetVisitDetailPage), findsOneWidget);
      pending.complete(
        const Error(LocalDatabaseFailure('Failed to delete vet visit')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Failed to delete vet visit').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verify(() => repository.deleteVetVisit(pet.id, visit.id)).called(1);
      when(
        () => repository.deleteVetVisit(pet.id, visit.id),
      ).thenAnswer((_) async => const Success(null));
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No visits yet'), findsOneWidget);
      verify(() => repository.getVetVisits(pet.id)).called(1);
    },
  );

  testWidgets('deleting from a long list preserves scroll without rereading', (
    tester,
  ) async {
    visits = List.generate(
      30,
      (index) => VetVisit(
        id: 'visit-$index',
        petId: pet.id,
        visitedOn: DateTime(2025, 1, 30 - index),
        reason: 'Visit $index',
      ),
    );
    await pumpRouter(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = position.pixels;
    expect(offset, greaterThan(0));
    await tester.tap(find.byIcon(Icons.delete_outline).hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(VetVisitListPage), findsOneWidget);
    expect(position.pixels, offset);
    verify(() => repository.getVetVisits(pet.id)).called(1);
  });

  testWidgets(
    'date heads the card while reason and clinic use the full card width',
    (tester) async {
      await pumpRouter(tester);
      final date = MaterialLocalizations.of(
        tester.element(find.byType(VetVisitListPage)),
      ).formatShortDate(visit.visitedOn);
      final dateText = tester.widget<Text>(find.text(date));
      final reasonText = tester.widget<Text>(find.text(visit.reason));
      expect(dateText.style!.fontSize, lessThanOrEqualTo(18));
      expect(
        dateText.style!.fontWeight!.value,
        greaterThan(reasonText.style!.fontWeight!.value),
      );
      expect(find.byIcon(Icons.event_note_outlined), findsOneWidget);
      expect(find.byIcon(Icons.local_hospital_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(
        tester.getRect(find.text(visit.reason)).top,
        greaterThan(tester.getRect(find.text(date)).bottom),
      );
      expect(
        tester.getRect(find.text(visit.reason)).left,
        lessThan(tester.getRect(find.text(date)).left),
      );
      expect(find.text(visit.reason), findsOneWidget);
    },
  );

  for (final brightness in Brightness.values) {
    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(640, 320), 2.0),
    ]) {
      testWidgets(
        'FAB overlays the full list and the final delete can scroll clear at $size in $brightness',
        (tester) async {
          visits = List.generate(
            20,
            (index) => VetVisit(
              id: 'visit-$index',
              petId: pet.id,
              visitedOn: DateTime(2025, 1, 30 - index),
              reason: 'Checkup $index',
              clinicName: 'Clinic A',
            ),
          );
          await pumpRouter(
            tester,
            width: size.width,
            height: size.height,
            scale: scale,
            brightness: brightness,
            safePadding: const EdgeInsets.only(bottom: 34),
          );
          final list = find.byType(ListView);
          final fab = find.byType(FloatingActionButton);
          expect(tester.getRect(list).bottom, size.height - 34);
          expect(tester.getRect(list).overlaps(tester.getRect(fab)), isTrue);
          final last = find.byKey(const ValueKey('visit-19'));
          await tester.scrollUntilVisible(
            last,
            250,
            scrollable: find.descendant(
              of: list,
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await revealFormField(tester, last);
          await tester.pumpAndSettle();
          final delete = find.descendant(
            of: last,
            matching: find.byType(IconButton),
          );
          expect(delete.hitTestable(), findsOneWidget);
          expect(tester.getRect(delete).overlaps(tester.getRect(fab)), isFalse);
          await tester.tap(delete);
          await tester.pumpAndSettle();
          expect(find.text('Delete visit?'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          verifyNever(() => repository.deleteVetVisit(any(), any()));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'details stay in a static card with editing in the section heading',
    (tester) async {
      visits = [
        VetVisit(
          id: visit.id,
          petId: pet.id,
          visitedOn: visit.visitedOn,
          reason: visit.reason,
        ),
      ];
      await pumpRouter(tester);
      await openDetail(tester);
      expect(find.byType(Card), findsNWidgets(3));
      expect(
        find.widgetWithText(ExpansionTile, 'Linked medications'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ExpansionTile, 'Linked vaccinations'),
        findsOneWidget,
      );
      expect(find.text('Visit details'), findsNothing);
      expect(find.text('Visit date'), findsNothing);
      final date = MaterialLocalizations.of(
        tester.element(find.byType(VetVisitDetailPage)),
      ).formatShortDate(visit.visitedOn);
      expect(
        tester.widget<Text>(find.text(date)).style!.fontSize,
        lessThanOrEqualTo(18),
      );
      expect(find.text('Not provided'), findsNWidgets(5));
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.byTooltip('Edit visit'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Edit visit'));
      await tester.pumpAndSettle();
      expect(find.byType(VetVisitFormPage), findsOneWidget);
    },
  );

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'suggestion loading preserves form positions and input at $size in $brightness',
        (tester) async {
          await tester.runAsync(loadFormTestFont);
          await pumpRouter(
            tester,
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
            keyboard: size.width == 320,
          );
          await openAdd(tester);
          await fill(tester, reasonField, 'Checkup');
          await fill(tester, veterinarianField, 'My veterinarian');
          await fill(tester, clinicField, 'C');
          final neighbor = tester.getRect(veterinarianField);
          final height = tester.getSize(clinicField).height;
          final pending = Completer<Result<VetVisitSuggestions>>();
          when(
            () => repository.getSuggestions(clinicName: 'Cli'),
          ).thenAnswer((_) => pending.future);
          await enterFormText(tester, clinicField, 'Cli');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.getRect(veterinarianField), neighbor);
          expect(tester.getSize(clinicField).height, height);
          pending.complete(
            const Success(
              VetVisitSuggestions(
                clinicNames: ['Clinic A', 'Clinic B'],
                veterinarianNames: [],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(veterinarianField), neighbor);
          final clinic = find.widgetWithText(MenuItemButton, 'Clinic B');
          await revealFormField(tester, clinic);
          await tester.pumpAndSettle();
          await tester.tap(clinic);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextFormField>(veterinarianField).controller!.text,
            'My veterinarian',
          );
          await save(tester);
          final saved =
              verify(
                    () => repository.createVetVisit(captureAny()),
                  ).captured.single
                  as VetVisit;
          expect(saved.clinicName, 'Clinic B');
          expect(saved.veterinarianName, 'My veterinarian');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'long visit cards remain readable and open detail at $size in $brightness',
        (tester) async {
          const reason =
              'Follow-up after the annual examination and a discussion about ongoing care.';
          const clinic =
              'Park Veterinary Hospital and specialist centre for companion animals';
          visits = [
            VetVisit(
              id: visit.id,
              petId: pet.id,
              visitedOn: visit.visitedOn,
              reason: reason,
              clinicName: clinic,
            ),
          ];
          await pumpRouter(
            tester,
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
          );
          final delete = find.widgetWithIcon(IconButton, Icons.delete_outline);
          await revealFormField(tester, delete);
          await tester.pumpAndSettle();
          expect(delete.hitTestable(), findsOneWidget);
          expect(
            tester
                .getRect(delete)
                .overlaps(tester.getRect(find.byType(FloatingActionButton))),
            isFalse,
          );
          await revealFormField(tester, find.text(reason));
          await tester.pumpAndSettle();
          expect(find.text(reason).hitTestable(), findsOneWidget);
          await tester.tap(find.text(reason));
          await tester.pumpAndSettle();
          expect(find.byType(VetVisitDetailPage), findsOneWidget);
          expect(find.text(reason), findsOneWidget);
          expect(find.text(clinic), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('medical fields grow to their line limit and then scroll', (
    tester,
  ) async {
    await pumpRouter(tester);
    await openAdd(tester);
    await fill(tester, reasonField, 'Checkup');
    for (final (key, lines) in [('visit-diagnosis', 4), ('visit-notes', 6)]) {
      final field = find.byKey(Key(key), skipOffstage: false);
      await revealFormField(tester, field);
      final initialHeight = tester.getSize(field).height;
      await fill(tester, field, List.filled(lines, 'A line').join('\n'));
      final cappedHeight = tester.getSize(field).height;
      expect(cappedHeight, greaterThan(initialHeight));
      await fill(tester, field, List.filled(20, 'A line').join('\n'));
      expect(tester.getSize(field).height, cappedHeight);
      final textScroll = tester
          .state<ScrollableState>(
            find.descendant(of: field, matching: find.byType(Scrollable)),
          )
          .position;
      expect(textScroll.maxScrollExtent, greaterThan(0));
      textScroll.jumpTo(textScroll.maxScrollExtent);
      await tester.pump();
      await tester.drag(
        find.descendant(of: field, matching: find.byType(EditableText)),
        const Offset(0, 48),
      );
      await tester.pumpAndSettle();
      expect(textScroll.pixels, lessThan(textScroll.maxScrollExtent));
      await fill(tester, field, '');
      expect(tester.getSize(field).height, initialHeight);
    }
  });

  testWidgets(
    'medical text limits count visible characters and cap pasted input',
    (tester) async {
      await pumpRouter(tester);
      await openAdd(tester);
      await fill(tester, reasonField, 'Checkup');
      final diagnosis = List.filled(200, '🐈‍⬛').join();
      final notes = List.filled(200, 'e\u0301').join();
      for (final (key, text) in [
        ('visit-diagnosis', diagnosis),
        ('visit-notes', notes),
      ]) {
        final field = find.byKey(Key(key), skipOffstage: false);
        await fill(tester, field, '${text}extra');
        expect(tester.widget<TextFormField>(field).controller!.text, text);
      }
      await save(tester);
      final created =
          verify(() => repository.createVetVisit(captureAny())).captured.single
              as VetVisit;
      expect(created.diagnosis, diagnosis);
      expect(created.notes, notes);
    },
  );

  testWidgets(
    'existing long medical text is preserved and must be shortened explicitly',
    (tester) async {
      final diagnosis = List.filled(201, 'd').join();
      final notes = List.filled(201, 'n').join();
      visits = [
        VetVisit(
          id: visit.id,
          petId: pet.id,
          visitedOn: visit.visitedOn,
          reason: visit.reason,
          diagnosis: diagnosis,
          notes: notes,
        ),
      ];
      await pumpRouter(tester);
      await openDetail(tester);
      await tester.tap(find.byTooltip('Edit visit'));
      await tester.pumpAndSettle();
      final diagnosisField = find.byKey(
        const Key('visit-diagnosis'),
        skipOffstage: false,
      );
      final notesField = find.byKey(
        const Key('visit-notes'),
        skipOffstage: false,
      );
      expect(
        tester.widget<TextFormField>(diagnosisField).controller!.text,
        diagnosis,
      );
      expect(tester.widget<TextFormField>(notesField).controller!.text, notes);
      await fill(tester, reasonField, 'Follow-up');
      await save(tester);
      expect(
        find.text('Keep diagnosis within 200 characters').hitTestable(),
        findsOneWidget,
      );
      verifyNever(() => repository.updateVetVisit(any()));
      await fill(tester, diagnosisField, diagnosis.substring(0, 200));
      await save(tester);
      expect(
        find.text('Keep notes within 200 characters').hitTestable(),
        findsOneWidget,
      );
      verifyNever(() => repository.updateVetVisit(any()));
      await fill(tester, notesField, notes.substring(0, 200));
      await save(tester);
      expect(find.byType(VetVisitDetailPage), findsOneWidget);
      final updated =
          verify(() => repository.updateVetVisit(captureAny())).captured.single
              as VetVisit;
      expect(updated.diagnosis, diagnosis.substring(0, 200));
      expect(updated.notes, notes.substring(0, 200));
    },
  );

  testWidgets(
    'detail and form share section order and edit retains the visit context',
    (tester) async {
      List<String> headings() => tester
          .widgetList<AppSectionHeading>(find.byType(AppSectionHeading))
          .map((heading) => heading.title)
          .toList();
      await pumpRouter(tester);
      await openDetail(tester);
      final detailSections = headings();
      expect(detailSections, [
        'Clinic & veterinarian',
        'Medical notes',
        'Cost',
      ]);
      await tester.tap(find.byTooltip('Edit visit'));
      await tester.pumpAndSettle();
      expect(headings(), ['Visit details']);
      for (final title in detailSections) {
        expect(find.text('$title (optional)'), findsOneWidget);
      }
      expect(
        find.widgetWithText(ElevatedButton, 'Save changes').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(reasonField).controller!.text,
        visit.reason,
      );
    },
  );

  testWidgets(
    'list deletion blocks exit, preserves rows on failure and confirms retries',
    (tester) async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.deleteVetVisit(pet.id, visit.id),
      ).thenAnswer((_) => pending.future);
      await pumpRouter(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.deleteVetVisit(any(), any()));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(find.text(visit.reason), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.byType(VetVisitListPage), findsOneWidget);
      pending.complete(
        const Error(LocalDatabaseFailure('Failed to delete vet visit')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Failed to delete vet visit').hitTestable(),
        findsOneWidget,
      );
      expect(find.text(visit.reason), findsOneWidget);
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verify(() => repository.deleteVetVisit(pet.id, visit.id)).called(1);
      when(
        () => repository.deleteVetVisit(pet.id, visit.id),
      ).thenAnswer((_) async => const Success(null));
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No visits yet'), findsOneWidget);
      verifyNever(() => repository.getVetVisitById(any(), any()));
      verify(() => repository.getVetVisits(pet.id)).called(1);
    },
  );

  for (final size in [const Size(320, 568), const Size(640, 320)]) {
    testWidgets(
      'list Delete and Retry stay outside Add at $size with large text',
      (tester) async {
        when(() => repository.deleteVetVisit(pet.id, visit.id)).thenAnswer(
          (_) async =>
              const Error(LocalDatabaseFailure('Failed to delete vet visit')),
        );
        await pumpRouter(
          tester,
          width: size.width,
          height: size.height,
          scale: 2,
        );
        final delete = find.widgetWithIcon(IconButton, Icons.delete_outline);
        await revealFormField(tester, delete);
        await tester.pumpAndSettle();
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await revealFormField(tester, delete);
        await tester.pumpAndSettle();
        final addRect = tester.getRect(find.byType(FloatingActionButton));
        if (tester.getRect(delete).bottom > addRect.top) {
          final list = find
              .ancestor(of: delete, matching: find.byType(Scrollable))
              .first;
          await tester.drag(
            list,
            Offset(0, -(tester.getRect(delete).bottom - addRect.top + 24)),
          );
          await tester.pumpAndSettle();
        }
        expect(
          tester.getRect(delete).bottom,
          lessThanOrEqualTo(addRect.top + 1),
        );
        expect(delete.hitTestable(), findsOneWidget);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(find.text('Delete visit?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        final message = find.text('Failed to delete vet visit');
        final textViewport = find.ancestor(
          of: message,
          matching: find.byType(SingleChildScrollView),
        );
        final typography = Theme.of(
          tester.element(message),
        ).textTheme.bodyMedium!;
        final lineHeight = typography.fontSize! * typography.height! * 2;
        expect(
          tester.getSize(textViewport).height,
          greaterThanOrEqualTo(lineHeight - 0.1),
        );
        expect(find.text('Retry deletion').hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Retry deletion')).dx,
          closeTo(tester.getTopLeft(message).dx, 0.1),
        );
        await tester.tap(find.text('Retry deletion'));
        await tester.pumpAndSettle();
        expect(find.text('Delete visit?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('missing detail URL and list failure provide working retries', (
    tester,
  ) async {
    when(() => repository.getVetVisits(pet.id)).thenAnswer(
      (_) async => const Error(LocalDatabaseFailure('Could not load visits')),
    );
    await pumpRouter(tester);
    when(
      () => repository.getVetVisits(pet.id),
    ).thenAnswer((_) async => Success(visits));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(visit.reason), findsOneWidget);
    await pumpRouter(
      tester,
      location: AppRoutes.vetVisitDetail(pet.id, 'missing'),
    );
    expect(find.text('Vet visit not found'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    verify(() => repository.getVetVisitById(pet.id, 'missing')).called(2);
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'save and delete errors remain reachable at $size in $brightness with large text',
        (tester) async {
          when(() => repository.createVetVisit(any())).thenAnswer(
            (_) async =>
                const Error(LocalDatabaseFailure('Failed to create vet visit')),
          );
          await pumpRouter(
            tester,
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
            keyboard: size.width == 320,
          );
          await openAdd(tester);
          await fill(tester, reasonField, 'Checkup');
          await save(tester);
          await checkFormError(tester, 'Failed to create vet visit');
          final retry = find.widgetWithText(ElevatedButton, 'Add visit');
          await revealFormField(tester, retry);
          await tester.pumpAndSettle();
          expect(retry.hitTestable(), findsOneWidget);
          expect(
            tester.widget<TextFormField>(reasonField).controller!.text,
            'Checkup',
          );
          expect(tester.takeException(), isNull);
          final editRouter = await pumpRouter(
            tester,
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
            keyboard: size.width == 320,
          );
          editRouter.push<bool>(
            AppRoutes.addEditVetVisit(pet.id),
            extra: visit,
          );
          await tester.pumpAndSettle();
          when(() => repository.updateVetVisit(any())).thenAnswer(
            (_) async =>
                const Error(LocalDatabaseFailure('Failed to update vet visit')),
          );
          await fill(tester, reasonField, 'Follow-up');
          await save(tester);
          await checkFormError(tester, 'Failed to update vet visit');
          expect(
            find.widgetWithText(ElevatedButton, 'Save changes').hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.widget<TextFormField>(reasonField).controller!.text,
            'Follow-up',
          );
          expect(tester.takeException(), isNull);
          // Replace the route to inspect deletion feedback without keyboard insets.
          await pumpRouter(
            tester,
            location: AppRoutes.vetVisitDetail(pet.id, visit.id),
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
          );
          when(() => repository.deleteVetVisit(pet.id, visit.id)).thenAnswer(
            (_) async =>
                const Error(LocalDatabaseFailure('Failed to delete vet visit')),
          );
          await tester.tap(find.byTooltip('Delete visit'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
          expect(
            find.text('Failed to delete vet visit').hitTestable(),
            findsOneWidget,
          );
          expect(find.text('Retry deletion').hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('Retry deletion')).dx,
            closeTo(
              tester.getTopLeft(find.text('Failed to delete vet visit')).dx,
              0.1,
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('list, detail, form and suggestions have labeled tap targets', (
    tester,
  ) async {
    await pumpRouter(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await openDetail(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byTooltip('Edit visit'));
    await tester.pumpAndSettle();
    await fill(tester, clinicField, 'Clinic');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(find.byType(AppSuggestionField), findsNWidgets(2));
  });
}
