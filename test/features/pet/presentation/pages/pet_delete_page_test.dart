import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_detail_page.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_list_page.dart';

class MockRepository extends Mock implements PetRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

void main() {
  const pet = Pet(
    id: 'pet-1',
    name: 'Fluffy with a very long name',
    species: PetSpecies.cat,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  const other = Pet(
    id: 'pet-2',
    name: 'Buddy',
    species: PetSpecies.dog,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  late MockRepository repository;
  late MockImageStorage images;
  late bool deleted;
  setUp(() {
    deleted = false;
    repository = MockRepository();
    images = MockImageStorage();
    when(
      () => repository.getPets(),
    ).thenAnswer((_) async => Success([if (!deleted) pet, other]));
    when(
      () => repository.getPetById(pet.id),
    ).thenAnswer((_) async => const Success(pet));
    when(() => repository.deletePet(pet.id)).thenAnswer((_) async {
      deleted = true;
      return const Success(null);
    });
    getIt.registerFactory<PetCubit>(
      () => PetCubit(
        repository,
        MockCreatePet(),
        MockUpdatePet(),
        DeletePet(repository, images),
      ),
    );
  });
  tearDown(() => getIt.unregister<PetCubit>());

  Future<void> pumpProfile(
    WidgetTester tester, {
    double width = 390,
    double height = 720,
    double scale = 1,
    Brightness brightness = Brightness.light,
    TargetPlatform platform = TargetPlatform.android,
    String? initialLocation,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: initialLocation ?? AppRoutes.pets,
      routes: appRouter.configuration.routes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<ImageStorage>.value(
        value: images,
        child: MaterialApp.router(
          theme:
              (brightness == Brightness.light ? AppTheme.light : AppTheme.dark)
                  .copyWith(platform: platform),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (initialLocation == null) {
      await tester.tap(find.text(pet.name));
      await tester.pumpAndSettle();
    }
  }

  Future<void> confirmDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Delete pet'));
    await tester.pumpAndSettle();
    expect(find.text('Delete pet?'), findsOneWidget);
  }

  testWidgets('cancellation keeps the profile and does not delete', (
    tester,
  ) async {
    await pumpProfile(tester);
    await confirmDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(PetDetailPage), findsOneWidget);
    expect(find.text(pet.name), findsOneWidget);
    verifyNever(() => repository.deletePet(any()));
    verifyZeroInteractions(images);
  });

  testWidgets(
    'confirmation returns to a refreshed list without the deleted pet',
    (tester) async {
      await pumpProfile(tester);
      await confirmDialog(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(PetListPage), findsOneWidget);
      expect(find.byType(PetDetailPage), findsNothing);
      expect(find.text(pet.name), findsNothing);
      expect(find.text(other.name), findsOneWidget);
      verify(() => repository.deletePet(pet.id)).called(1);
      verify(() => repository.getPets()).called(2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting the last pet returns to the empty list', (
    tester,
  ) async {
    when(
      () => repository.getPets(),
    ).thenAnswer((_) async => Success([if (!deleted) pet]));
    await pumpProfile(tester);
    await confirmDialog(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(PetListPage), findsOneWidget);
    expect(find.text('No pets yet'), findsOneWidget);
    expect(find.text(pet.name), findsNothing);
    verify(() => repository.deletePet(pet.id)).called(1);
  });

  testWidgets('failure keeps the profile and allows a confirmed retry', (
    tester,
  ) async {
    var attempts = 0;
    when(() => repository.deletePet(pet.id)).thenAnswer((_) async {
      if (attempts++ == 0) {
        return const Error(
          LocalDatabaseFailure('Could not delete pet. Please retry.'),
        );
      }
      deleted = true;
      return const Success(null);
    });
    await pumpProfile(tester);
    await tester.ensureVisible(find.text('Profile details'));
    await tester.tap(find.text('Profile details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Microchip ID'));
    await confirmDialog(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(PetDetailPage), findsOneWidget);
    expect(find.text(pet.name), findsOneWidget);
    expect(
      find.text('Could not delete pet. Please retry.').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Retry deletion').hitTestable(), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Edit profile',
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Retry deletion'));
    await tester.pumpAndSettle();
    expect(find.text('Delete pet?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(PetListPage), findsOneWidget);
    verify(() => repository.deletePet(pet.id)).called(2);
    verify(() => repository.getPets()).called(2);
  });

  testWidgets(
    'pending deletion disables actions, prevents duplicate requests and waits before leaving',
    (tester) async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.deletePet(pet.id),
      ).thenAnswer((_) => pending.future);
      await pumpProfile(tester);
      await confirmDialog(tester);
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Deleting pet…'), findsOneWidget);
      expect(find.text(pet.name), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Delete pet',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Edit profile',
              ),
            )
            .onPressed,
        isNull,
      );
      final cubit = tester.element(find.byType(PetDetailPage)).read<PetCubit>();
      await cubit.deletePet(pet);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PetDetailPage), findsOneWidget);
      deleted = true;
      pending.complete(const Success(null));
      await tester.pumpAndSettle();
      expect(find.byType(PetListPage), findsOneWidget);
      expect(find.text(pet.name), findsNothing);
      verify(() => repository.deletePet(pet.id)).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'shared profile feedback is aligned and retry reconfirms at $size in $brightness',
        (tester) async {
          when(() => repository.deletePet(pet.id)).thenAnswer(
            (_) async => const Error(
              LocalDatabaseFailure('Could not delete pet. Please retry.'),
            ),
          );
          await pumpProfile(
            tester,
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
            initialLocation: AppRoutes.petDetail(pet.id),
          );
          await confirmDialog(tester);
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
          final message = find.text('Could not delete pet. Please retry.');
          final retry = find.text('Retry deletion');
          expect(retry.hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(retry).dx,
            closeTo(tester.getTopLeft(message).dx, 0.1),
          );
          expect(tester.getRect(retry).bottom, lessThanOrEqualTo(size.height));
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(find.text('Delete pet?'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(PetDetailPage), findsOneWidget);
          verify(() => repository.deletePet(pet.id)).called(1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final brightness in Brightness.values) {
    for (final (width, scale) in [(320.0, 2.0), (800.0, 1.0)]) {
      testWidgets('confirmation fits $width at $scale in $brightness', (
        tester,
      ) async {
        await pumpProfile(
          tester,
          width: width,
          scale: scale,
          brightness: brightness,
        );
        await confirmDialog(tester);
        final colors = Theme.of(
          tester.element(find.text('Cancel')),
        ).colorScheme;
        final cancel = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Cancel'),
        );
        expect(cancel.style!.foregroundColor!.resolve({}), colors.onSurface);
        expect(find.widgetWithText(ElevatedButton, 'Delete'), findsOneWidget);
        expect(
          ElevatedButtonTheme.of(
            tester.element(find.text('Delete')),
          ).style!.backgroundColor!.resolve({}),
          colors.primary,
        );
        expect(find.text('Delete').hitTestable(), findsOneWidget);
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        when(() => repository.deletePet(pet.id)).thenAnswer(
          (_) async => const Error(
            LocalDatabaseFailure('Could not delete pet. Please retry.'),
          ),
        );
        await confirmDialog(tester);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(
          find.text('Could not delete pet. Please retry.').hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Retry deletion').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('iOS confirmation supports large text in $brightness', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        platform: TargetPlatform.iOS,
        brightness: brightness,
        width: 320,
        scale: 2,
      );
      await confirmDialog(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Delete'), findsOneWidget);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(find.text('Delete').hitTestable(), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(PetDetailPage), findsOneWidget);
      verifyNever(() => repository.deletePet(any()));
      expect(tester.takeException(), isNull);
    });
  }
}
