import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_form_page.dart';

import '../../../../helpers/multi_step_form_helpers.dart';
import '../../../../helpers/feeding_test_harness.dart';
import '../../../../helpers/pet_care_test_harness.dart';

const _title = 'Your pets’ care in one place';
const _privacy = 'No account needed. Records are stored on this device.';
const _action = 'Add your first pet';

void main() {
  late PetCareTestHarness app;
  late List<Pet> pets;

  setUpAll(() async {
    await loadFormTestFont();
    final harness = PetCareTestHarness();
    final sample = harness.sample();
    registerFallbackValue(sample);
    registerFallbackValue(sample.periods.single);
    registerFallbackValue(
      MedicationDoseLog(
        periodId: sample.periods.single.id,
        scheduledDate: harness.today,
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      ),
    );
    registerFallbackValue(
      const CreatePetParams(
        name: 'Milo',
        species: PetSpecies.dog,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      ),
    );
  });

  setUp(() {
    app = FeedingTestHarness()..register();
    pets = [];
    when(app.pets.getPets).thenAnswer((_) async => Success(List.of(pets)));
  });

  testWidgets('empty directory starts onboarding through the existing form', (
    tester,
  ) async {
    final router = await app.pump(tester, location: AppRoutes.pets);
    expect(find.text(_title), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    verify(app.pets.getPets).called(1);
    verifyNever(app.visits.getAllVetVisits);
    verifyNever(app.vaccinations.getAllVaccinations);
    verifyNever(app.repository.getAllMedications);

    await tester.tap(find.byTooltip(_action));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.addEditPet);
    expect(find.byType(PetFormPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.pets);
    expect(find.text(_title), findsOneWidget);
    expect(pets, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saving the first profile replaces onboarding with the pet list',
    (tester) async {
      final create = MockCreatePet();
      when(() => create(any())).thenAnswer((call) async {
        final params = call.positionalArguments.single as CreatePetParams;
        pets.add(
          Pet(
            id: 'new-pet',
            name: params.name,
            species: params.species,
            sex: params.sex,
            reproductiveStatus: params.reproductiveStatus,
          ),
        );
        return const Success(null);
      });
      await getIt.unregister<PetCubit>();
      getIt.registerFactory<PetCubit>(
        () => PetCubit(app.pets, create, MockUpdatePet(), MockDeletePet()),
      );

      final router = await app.pump(tester, location: AppRoutes.pets);
      await tester.tap(find.byTooltip(_action));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Milo',
      );
      await reviewForm(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add pet'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.pets);
      expect(find.text(_title), findsNothing);
      expect(find.text(_privacy), findsNothing);
      expect(find.text('Milo'), findsOneWidget);
      expect(find.byTooltip('Add pet'), findsOneWidget);
      verify(() => create(any())).called(1);
      verify(app.pets.getPets).called(2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('load errors offer recovery before showing onboarding', (
    tester,
  ) async {
    var fail = true;
    when(app.pets.getPets).thenAnswer(
      (_) async => fail
          ? const Error(LocalDatabaseFailure('Test failure'))
          : const Success([]),
    );
    await app.pump(tester, location: AppRoutes.pets);
    expect(find.text('Failed to get pets'), findsOneWidget);
    expect(find.text(_title), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);
    expect(find.byTooltip(_action), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (locale, action, genericAction) in [
    (englishLocale, _action, 'Add pet'),
    (turkishLocale, 'İlk dostunu ekle', 'Dost ekle'),
  ]) {
    for (final location in [
      AppRoutes.pets,
      AppRoutes.allVetVisits,
      AppRoutes.allVaccinations,
      AppRoutes.allMedications,
      AppRoutes.allFeeding,
    ]) {
      testWidgets('first-pet action is consistent at $location in $locale', (
        tester,
      ) async {
        final router = await app.pump(
          tester,
          location: location,
          locale: locale,
        );
        expect(find.byTooltip(action), findsOneWidget);
        expect(find.byTooltip(genericAction), findsNothing);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byType(ElevatedButton), findsNothing);

        await tester.tap(find.byTooltip(action));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.addEditPet);
        expect(find.byType(PetFormPage), findsOneWidget);

        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, location);
        expect(find.byTooltip(action), findsOneWidget);
        expect(pets, isEmpty);
        verify(app.pets.getPets).called(1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (locale, title, privacy, action) in [
    (englishLocale, _title, _privacy, _action),
    (
      turkishLocale,
      'Dostlarınızın bakımı bir arada',
      'Hesap oluşturmanız gerekmez. Kayıtlarınız bu cihazda saklanır.',
      'İlk dostunu ekle',
    ),
  ]) {
    for (final dark in [false, true]) {
      for (final (size, scale) in [
        (const Size(320, 568), 1.0),
        (const Size(320, 568), 2.0),
        (const Size(640, 320), 2.0),
      ]) {
        testWidgets('onboarding fits $locale $size scale=$scale dark=$dark', (
          tester,
        ) async {
          await app.pump(
            tester,
            location: AppRoutes.pets,
            locale: locale,
            size: size,
            scale: scale,
            dark: dark,
            bottomInset: 24,
          );
          expect(find.text(title), findsOneWidget);
          expect(find.byTooltip(action).hitTestable(), findsOneWidget);
          expect(find.byType(FloatingActionButton), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -1200),
          );
          await tester.pumpAndSettle();
          final info = find.text(privacy);
          expect(info.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(info).top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(SingleChildScrollView).first).top,
            ),
          );
          expect(
            tester.getRect(info).bottom,
            lessThan(tester.getRect(find.byType(FloatingActionButton)).top),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
