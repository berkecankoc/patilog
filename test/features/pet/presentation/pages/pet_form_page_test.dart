import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_form_page.dart';

class MockRepository extends Mock implements PetRepository {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

class MockDeletePet extends Mock implements DeletePet {}

void main() {
  const pet = Pet(
    id: 'pet-1',
    name: 'Buddy',
    species: PetSpecies.dog,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
    weight: 12,
  );
  late MockCreatePet create;
  late MockUpdatePet update;
  late PetCubit cubit;
  late Future<bool?> routeResult;

  setUpAll(() {
    registerFallbackValue(
      const CreatePetParams(
        name: 'Buddy',
        species: PetSpecies.dog,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      ),
    );
    registerFallbackValue(
      const UpdatePetParams(
        name: 'Buddy',
        species: PetSpecies.dog,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      ),
    );
  });
  setUp(() {
    create = MockCreatePet();
    update = MockUpdatePet();
    when(() => create(any())).thenAnswer((_) async => const Success(null));
    when(() => update(pet, any())).thenAnswer((_) async => const Success(null));
    cubit = PetCubit(MockRepository(), create, update, MockDeletePet());
  });
  tearDown(() => cubit.close());

  Future<void> pumpForm(
    WidgetTester tester, {
    Pet? existing = pet,
    double width = 390,
    double scale = 1,
    bool keyboard = false,
    Brightness brightness = Brightness.light,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Previous page')),
        ),
        GoRoute(
          path: AppRoutes.addEditPet,
          builder: (_, state) => BlocProvider.value(
            value: cubit,
            child: PetFormPage(pet: state.extra as Pet?),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: (brightness == Brightness.light ? AppTheme.light : AppTheme.dark)
            .copyWith(platform: platform),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard ? 280 : 0),
          ),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    routeResult = router.push<bool>(AppRoutes.addEditPet, extra: existing);
    await tester.pumpAndSettle();
  }

  Future<void> changeName(
    WidgetTester tester, [
    String name = 'Updated Buddy',
  ]) async {
    final field = find.byType(TextFormField).first;
    await tester.ensureVisible(field);
    await tester.enterText(field, name);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  for (final editing in [false, true]) {
    final label = editing ? 'Save changes' : 'Add pet';
    for (final (scenario, input, expected) in [
      ('20 visible characters', '🐈‍⬛' * 20, '🐈‍⬛' * 20),
      ('surrounding whitespace', '  ${'a' * 20}  ', 'a' * 20),
    ]) {
      testWidgets('$label pet name handles $scenario', (tester) async {
        await pumpForm(tester, existing: editing ? pet : null);
        await changeName(tester, input);
        final button = find.widgetWithText(ElevatedButton, label);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(await routeResult, isTrue);
        if (editing) {
          final params =
              verify(() => update(pet, captureAny())).captured.single
                  as UpdatePetParams;
          expect(params.name, expected);
        } else {
          final params =
              verify(() => create(captureAny())).captured.single
                  as CreatePetParams;
          expect(params.name, expected);
        }
      });
    }
    testWidgets(
      '$label rejects a pet name over 20 characters without cutting input',
      (tester) async {
        await pumpForm(tester, existing: editing ? pet : null);
        final tooLong = 'a' * 21;
        await changeName(tester, tooLong);
        final button = find.widgetWithText(ElevatedButton, label);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.text('Keep name within 20 characters').hitTestable(),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          tooLong,
        );
        verifyNever(() => create(any()));
        verifyNever(() => update(pet, any()));
        await changeName(tester, 'a' * 20);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(await routeResult, isTrue);
        if (editing) {
          final params =
              verify(() => update(pet, captureAny())).captured.single
                  as UpdatePetParams;
          expect(params.name, 'a' * 20);
        } else {
          final params =
              verify(() => create(captureAny())).captured.single
                  as CreatePetParams;
          expect(params.name, 'a' * 20);
        }
      },
    );
    testWidgets(
      editing
          ? 'edit saves from basic details with fixed actions'
          : 'add saves only from actions after the form details',
      (tester) async {
        await pumpForm(tester, existing: editing ? pet : null);
        final button = find.widgetWithText(ElevatedButton, label);
        final bounds = tester.getRect(button);
        await changeName(tester);
        if (editing) {
          expect(button.hitTestable(), findsOneWidget);
          expect(find.text('Microchip ID').hitTestable(), findsNothing);
          expect(tester.getRect(button), bounds);
        } else {
          expect(button.hitTestable(), findsNothing);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(button.hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(button).dy,
            greaterThan(tester.getBottomRight(find.text('Microchip ID')).dy),
          );
        }
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Previous page'), findsOneWidget);
        expect(await routeResult, isTrue);
        if (editing) {
          final params =
              verify(() => update(pet, captureAny())).captured.single
                  as UpdatePetParams;
          expect(params.name, 'Updated Buddy');
        } else {
          final params =
              verify(() => create(captureAny())).captured.single
                  as CreatePetParams;
          expect(params.name, 'Updated Buddy');
        }
      },
    );

    for (final systemBack in [false, true]) {
      testWidgets(
        '$label protects unsaved input on ${systemBack ? 'system' : 'app bar'} back',
        (tester) async {
          await pumpForm(tester, existing: editing ? pet : null);
          await changeName(tester);
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Back'));
          }
          await tester.pumpAndSettle();
          expect(find.text('Discard changes?'), findsOneWidget);
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(find.byType(PetFormPage), findsOneWidget);
          expect(find.text('Updated Buddy'), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Discard changes'));
          await tester.pumpAndSettle();
          expect(find.text('Previous page'), findsOneWidget);
          expect(await routeResult, isNull);
          verifyNever(() => create(any()));
          verifyNever(() => update(pet, any()));
        },
      );
    }
  }

  testWidgets('unchanged edit and restored input leave without a prompt', (
    tester,
  ) async {
    await pumpForm(tester);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await changeName(tester);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    await changeName(tester, pet.name);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Previous page'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('empty add form leaves without a prompt', (tester) async {
    await pumpForm(tester, existing: null);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Previous page'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('dropdown-only edits enable saving and protect unsaved changes', (
    tester,
  ) async {
    await pumpForm(tester);
    final field = find.byType(DropdownButtonFormField<PetSpecies>);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bird').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('invalid fields are brought into view without saving', (
    tester,
  ) async {
    await pumpForm(tester);
    final weight = find.byType(TextFormField).at(2);
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '-1');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await changeName(tester);
    expect(find.text('Weight').hitTestable(), findsNothing);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Weight must be greater than 0').hitTestable(),
      findsOneWidget,
    );
    verifyNever(() => update(pet, any()));
  });

  testWidgets('pending save blocks repeat requests and leaving', (
    tester,
  ) async {
    final pending = Completer<Result<void>>();
    when(() => update(pet, any())).thenAnswer((_) => pending.future);
    await pumpForm(tester);
    await changeName(tester);
    await tester.tap(find.text('Save changes'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saving…'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(PetFormPage), findsOneWidget);
    pending.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(find.text('Previous page'), findsOneWidget);
    verify(() => update(pet, any())).called(1);
  });

  testWidgets('save error stays visible with input and retry from the top', (
    tester,
  ) async {
    var attempts = 0;
    when(() => update(pet, any())).thenAnswer(
      (_) async => attempts++ == 0
          ? const Error(LocalDatabaseFailure('Could not save. Please retry.'))
          : const Success(null),
    );
    await pumpForm(tester);
    await changeName(tester);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save. Please retry.').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Updated Buddy'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Previous page'), findsOneWidget);
    verify(() => update(pet, any())).called(2);
  });

  for (final brightness in Brightness.values) {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        'fixed actions and discard fit large text in $brightness on $platform',
        (tester) async {
          await pumpForm(
            tester,
            width: 320,
            scale: 2,
            keyboard: true,
            brightness: brightness,
            platform: platform,
          );
          await changeName(tester);
          expect(find.text('Save changes').hitTestable(), findsOneWidget);
          expect(
            tester.getBottomRight(find.text('Save changes')).dy,
            lessThan(440),
          );
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.text('Keep editing').hitTestable(), findsOneWidget);
          expect(find.text('Discard changes').hitTestable(), findsOneWidget);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
