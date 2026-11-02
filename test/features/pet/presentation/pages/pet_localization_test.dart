import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';

import '../../../../helpers/pet_care_test_harness.dart' as care;
import '../../../../helpers/settings_test_harness.dart';

void main() {
  const pet = Pet(
    id: 'pet',
    name: 'İnci 🐾',
    species: PetSpecies.bird,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.intact,
    breed: 'Muhabbet kuşu',
  );
  late SettingsTestHarness app;
  late care.MockCreatePet create;
  late care.MockUpdatePet update;
  late care.MockDeletePet delete;

  setUpAll(() async {
    await SettingsTestHarness.initialize();
    registerFallbackValue(pet);
    registerFallbackValue(
      const CreatePetParams(
        name: 'Fallback',
        species: PetSpecies.dog,
        sex: PetSex.unknown,
        reproductiveStatus: ReproductiveStatus.unknown,
      ),
    );
    registerFallbackValue(
      const UpdatePetParams(
        name: 'Fallback',
        species: PetSpecies.dog,
        sex: PetSex.unknown,
        reproductiveStatus: ReproductiveStatus.unknown,
      ),
    );
  });
  setUp(() async {
    app = SettingsTestHarness()..register();
    app.storedLanguage = LanguagePreference.turkish;
    create = care.MockCreatePet();
    update = care.MockUpdatePet();
    delete = care.MockDeletePet();
    when(() => create(any())).thenAnswer((_) async => const Success(null));
    when(
      () => app.care.pets.getPetById(any()),
    ).thenAnswer((_) async => const Success(pet));
    await getIt.unregister<PetCubit>();
    getIt.registerFactory<PetCubit>(
      () => PetCubit(app.care.pets, create, update, delete),
    );
  });

  Future<void> openForm(WidgetTester tester, {Pet? existing}) async {
    unawaited(appRouter.push<bool>(AppRoutes.addEditPet, extra: existing));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'locale changes translate validation and preserve the draft and step',
    (tester) async {
      await app.pump(tester, location: AppRoutes.pets);
      expect(find.text('Dostlarım'), findsWidgets);
      await openForm(tester);
      final form = tester.state(find.byType(AppMultiStepForm));
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Ad girin'), findsOneWidget);
      expect(find.text('Adım 1/2 · Dostunuz'), findsOneWidget);
      await app.cubit.setLanguagePreference(LanguagePreference.english);
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Ad girin'), findsNothing);
      expect(find.text('Step 1 of 2 · Pet'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        pet.name,
      );
      await tester.tap(find.byType(DropdownButtonFormField<PetSpecies>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bird').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await app.cubit.setLanguagePreference(LanguagePreference.turkish);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(AppMultiStepForm)), same(form));
      expect(find.text('Adım 2/2 · Gözden geçir'), findsOneWidget);
      expect(find.text(pet.name), findsOneWidget);
      expect(find.text('Kuş'), findsOneWidget);
      expect(find.text('Name is required'), findsNothing);
      expect(find.text('Geçerli bir kilo girin'), findsNothing);
      verifyNever(() => create(any()));
      expect(tester.takeException(), isNull);
    },
  );

  for (final (failure, message) in <(Failure, String)>[
    (
      const LocalDatabaseFailure('Private database diagnostic'),
      'Dost eklenemedi',
    ),
    (
      const ImageStorageFailure('Private image diagnostic'),
      'Fotoğraf kaydedilemedi',
    ),
  ]) {
    testWidgets(
      '${failure.runtimeType} is localized and retry keeps the same payload',
      (tester) async {
        var attempts = 0;
        when(() => create(any())).thenAnswer(
          (_) async => attempts++ == 0 ? Error(failure) : const Success(null),
        );
        await app.pump(tester, location: AppRoutes.pets);
        await openForm(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Ad'),
          pet.name,
        );
        await tester.tap(find.byType(DropdownButtonFormField<PetSpecies>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kuş').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Devam et'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Dost ekle'));
        await tester.pumpAndSettle();
        expect(find.text(message).hitTestable(), findsOneWidget);
        expect(find.text(failure.message), findsNothing);
        expect(find.text(pet.name), findsOneWidget);
        await app.cubit.setLanguagePreference(LanguagePreference.english);
        await tester.pumpAndSettle();
        expect(find.text(message), findsNothing);
        expect(
          find.text(
            failure is ImageStorageFailure
                ? 'Failed to save new image'
                : 'Failed to create pet',
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add pet'));
        await tester.pumpAndSettle();
        final captured = verify(
          () => create(captureAny()),
        ).captured.cast<CreatePetParams>();
        expect(captured, hasLength(2));
        expect(captured.map((params) => params.name), everyElement(pet.name));
        expect(
          captured.map((params) => params.species),
          everyElement(PetSpecies.bird),
        );
        expect(appRouter.state.uri.path, AppRoutes.pets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an open deletion confirmation changes language without changing the pet',
    (tester) async {
      await app.pump(tester, location: AppRoutes.petDetail(pet.id));
      await tester.tap(find.byTooltip('Profili sil'));
      await tester.pumpAndSettle();
      expect(find.text('Profil silinsin mi?'), findsOneWidget);
      expect(
        find.textContaining('${pet.name} adlı dostunuzun'),
        findsOneWidget,
      );
      expect(find.text('Vazgeç').hitTestable(), findsOneWidget);
      await app.cubit.setLanguagePreference(LanguagePreference.english);
      await tester.pumpAndSettle();
      expect(find.text('Delete pet?'), findsOneWidget);
      expect(find.textContaining('${pet.name}’s profile'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => delete(any()));
      expect(appRouter.state.uri.path, AppRoutes.petDetail(pet.id));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'not-found failures use the localized message rather than diagnostics',
    (tester) async {
      when(() => app.care.pets.getPetById(any())).thenAnswer(
        (_) async =>
            const Error(NotFoundFailure('Internal missing record detail')),
      );
      await app.pump(tester, location: AppRoutes.petDetail(pet.id));
      expect(find.text('Dost bulunamadı'), findsOneWidget);
      expect(find.text('Bir sorun oluştu'), findsOneWidget);
      expect(find.text('Tekrar dene').hitTestable(), findsOneWidget);
      expect(find.text('Internal missing record detail'), findsNothing);
    },
  );

  for (final theme in [ThemePreference.light, ThemePreference.dark]) {
    testWidgets(
      'Turkish profile and edit controls fit at large text in ${theme.name}',
      (tester) async {
        app.stored = theme;
        await app.pump(
          tester,
          location: AppRoutes.pets,
          size: const Size(320, 568),
          scale: 2,
        );
        expect(
          tester
              .widgetList<NavigationDestination>(
                find.byType(NavigationDestination),
              )
              .map((item) => item.label),
          ['Dostlarım', 'Ziyaretler', 'Aşılar', 'İlaçlar', 'Beslenme'],
        );
        final visitCaption = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Ziyaretler'),
        );
        for (final label in [
          'Dostlarım',
          'Ziyaretler',
          'Aşılar',
          'İlaçlar',
          'Beslenme',
        ]) {
          final caption = find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          );
          expect(
            tester.renderObject<RenderParagraph>(caption).didExceedMaxLines,
            isFalse,
            reason: label,
          );
        }
        expect(find.byTooltip('Veteriner ziyaretleri'), findsOneWidget);
        await tester.tap(visitCaption);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Veteriner ziyaretleri'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        unawaited(appRouter.push(AppRoutes.petDetail(pet.id)));
        await tester.pumpAndSettle();
        expect(find.text('Kuş'), findsOneWidget);
        expect(find.text('Profil bilgileri'), findsOneWidget);
        await tester.ensureVisible(find.text('Mikroçip numarası'));
        await tester.pumpAndSettle();
        expect(find.text('Belirtilmedi'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Profili düzenle'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Profili düzenle'));
        await tester.pumpAndSettle();
        expect(
          find.text('Değişiklikleri kaydet').hitTestable(),
          findsOneWidget,
        );
        final status = find.byType(DropdownButtonFormField<ReproductiveStatus>);
        await tester.ensureVisible(status);
        await tester.pumpAndSettle();
        await tester.tap(status);
        await tester.pumpAndSettle();
        expect(find.text('Kısırlaştırılmamış').hitTestable(), findsWidgets);
        expect(tester.takeException(), isNull);
        verifyNever(() => create(any()));
        verifyNever(() => update(any(), any()));
      },
    );
  }
}
