import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_form_page.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_list_page.dart';

class MockRepository extends Mock implements PetRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

class MockDeletePet extends Mock implements DeletePet {}

PetCubit makeCubit(PetState state) => PetCubit(
  MockRepository(),
  MockCreatePet(),
  MockUpdatePet(),
  MockDeletePet(),
)..emit(state);

const pet = Pet(
  id: 'pet-1',
  name: 'Fluffy with a very long name',
  breed: 'A breed with a very long name',
  species: PetSpecies.cat,
  sex: PetSex.female,
  reproductiveStatus: ReproductiveStatus.sterilized,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const UpdatePetParams(
        name: 'Fluffy',
        species: PetSpecies.cat,
        sex: PetSex.female,
        reproductiveStatus: ReproductiveStatus.sterilized,
      ),
    );
    registerFallbackValue(
      const CreatePetParams(
        name: 'Fluffy',
        species: PetSpecies.cat,
        sex: PetSex.female,
        reproductiveStatus: ReproductiveStatus.sterilized,
      ),
    );
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page,
    PetCubit cubit, {
    double width = 320,
    double scale = 2,
    bool keyboard = false,
    Brightness brightness = Brightness.light,
  }) async {
    final imageStorage = MockImageStorage();
    when(() => imageStorage.resolvePath(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as String,
    );
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard ? 280 : 0),
          ),
          child: child!,
        ),
        home: RepositoryProvider<ImageStorage>.value(
          value: imageStorage,
          child: BlocProvider<PetCubit>.value(value: cubit, child: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final validPhoto in [false, true]) {
    testWidgets(
      'photo ${validPhoto ? 'shows remove when decoded' : 'shows add without remove on error'}',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'pet-photo-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/photo.png');
        if (validPhoto) {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.orange, BlendMode.src);
          final picture = recorder.endRecording();
          final image = (await tester.runAsync(() => picture.toImage(1, 1)))!;
          picture.dispose();
          PaintingBinding.instance.imageCache.putIfAbsent(
            FileImage(file),
            () => OneFrameImageStreamCompleter(
              Future.value(ImageInfo(image: image)),
            ),
          );
          addTearDown(PaintingBinding.instance.imageCache.clear);
        }
        final cubit = makeCubit(const PetInitial());
        addTearDown(cubit.close);
        await pumpPage(
          tester,
          PetFormPage(pet: pet.copyWith(imagePath: file.path)),
          cubit,
          scale: 1,
        );
        if (!validPhoto) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
        }
        await tester.pumpAndSettle();
        expect(
          find.text('Add photo'),
          validPhoto ? findsNothing : findsOneWidget,
        );
        expect(
          find.byTooltip('Remove photo'),
          validPhoto ? findsOneWidget : findsNothing,
        );
        if (validPhoto) {
          final photoBounds = tester.getRect(
            find.byWidgetPredicate(
              (widget) => widget is Material && widget.shape is CircleBorder,
            ),
          );
          final removeBounds = tester.getRect(find.byTooltip('Remove photo'));
          expect(removeBounds.top, greaterThanOrEqualTo(photoBounds.bottom));
          final detailsTop = tester.getTopLeft(find.text('Basic details')).dy;
          await tester.tap(find.byTooltip('Remove photo'));
          await tester.pumpAndSettle();
          expect(find.text('Add photo'), findsOneWidget);
          expect(find.byTooltip('Remove photo'), findsNothing);
          expect(tester.getTopLeft(find.text('Basic details')).dy, detailsTop);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final (width, scale) in [(320.0, 2.0), (800.0, 1.0)]) {
      testWidgets('dropdown menus align with fields at $width in $brightness', (
        tester,
      ) async {
        final cubit = makeCubit(const PetInitial());
        addTearDown(cubit.close);
        await pumpPage(
          tester,
          const PetFormPage(),
          cubit,
          width: width,
          scale: scale,
          brightness: brightness,
        );
        for (final field in [
          find.byType(DropdownButtonFormField<PetSpecies>),
          find.byType(DropdownButtonFormField<PetSex>),
          find.byType(DropdownButtonFormField<ReproductiveStatus>),
        ]) {
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          final fieldBounds = tester.getRect(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          final menu = find.byWidgetPredicate(
            (widget) =>
                widget is ClipRRect &&
                widget.borderRadius == BorderRadius.circular(16),
          );
          expect(menu, findsOneWidget);
          final menuBounds = tester.getRect(menu);
          expect(menuBounds.left, closeTo(fieldBounds.left, 0.1));
          expect(menuBounds.right, closeTo(fieldBounds.right, 0.1));
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
      testWidgets('pet cards fit $width at $scale in $brightness', (
        tester,
      ) async {
        final cubit = makeCubit(const PetsLoaded([pet]));
        addTearDown(cubit.close);
        await pumpPage(
          tester,
          const PetListPage(),
          cubit,
          width: width,
          scale: scale,
          brightness: brightness,
        );
        expect(find.text(pet.name), findsOneWidget);
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
      testWidgets('form fits $width at $scale with keyboard in $brightness', (
        tester,
      ) async {
        final cubit = makeCubit(const PetInitial());
        addTearDown(cubit.close);
        await pumpPage(
          tester,
          const PetFormPage(pet: pet),
          cubit,
          width: width,
          scale: scale,
          brightness: brightness,
          keyboard: true,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(find.text('Save changes').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('save failure keeps input and allows retry', (tester) async {
    final createPet = MockCreatePet();
    final cubit = PetCubit(
      MockRepository(),
      createPet,
      MockUpdatePet(),
      MockDeletePet(),
    );
    addTearDown(cubit.close);
    when(() => createPet(any())).thenAnswer(
      (_) async =>
          const Error(LocalDatabaseFailure('Could not save. Please retry.')),
    );
    await pumpPage(tester, const PetFormPage(), cubit, scale: 1);
    await tester.enterText(find.byType(TextFormField).first, 'Fluffy');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add pet'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Please retry.'), findsOneWidget);
    expect(find.text('Fluffy'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    verify(() => createPet(any())).called(1);
  });

  for (final systemBack in [false, true]) {
    testWidgets(
      'updated pet name appears in list after ${systemBack ? 'system' : 'app bar'} back',
      (tester) async {
        var currentPet = pet;
        final repository = MockRepository();
        final update = MockUpdatePet();
        when(
          () => repository.getPets(),
        ).thenAnswer((_) async => Success([currentPet]));
        when(
          () => repository.getPetById(pet.id),
        ).thenAnswer((_) async => Success(currentPet));
        when(() => update(pet, any())).thenAnswer((invocation) async {
          final params = invocation.positionalArguments[1] as UpdatePetParams;
          currentPet = pet.copyWith(name: params.name);
          return const Success<void>(null);
        });
        getIt.registerFactory<PetCubit>(
          () => PetCubit(repository, MockCreatePet(), update, MockDeletePet()),
        );
        addTearDown(() => getIt.unregister<PetCubit>());
        final router = GoRouter(
          initialLocation: AppRoutes.pets,
          routes: appRouter.configuration.routes,
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(pet.name));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Edit profile'));
        await tester.tap(find.byTooltip('Edit profile'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Updated pet name',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(find.text('Updated pet name'), findsOneWidget);
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        expect(find.byType(PetListPage), findsOneWidget);
        expect(find.text('Updated pet name'), findsOneWidget);
        expect(find.text(pet.name), findsNothing);
        verify(() => repository.getPets()).called(2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('pet card opens the selected profile', (tester) async {
    final cubit = makeCubit(const PetsLoaded([pet]));
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: AppRoutes.pets,
      routes: [
        GoRoute(
          path: AppRoutes.pets,
          builder: (context, state) => BlocProvider<PetCubit>.value(
            value: cubit,
            child: const PetListPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.petDetail(pet.id),
          builder: (context, state) =>
              const Scaffold(body: Text('Selected profile')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(pet.name));
    await tester.pumpAndSettle();
    expect(find.text('Selected profile'), findsOneWidget);
  });
}
