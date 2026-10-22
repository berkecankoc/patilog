import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:petlytics/features/weight_history/presentation/pages/weight_entry_form_page.dart';
import 'package:petlytics/features/weight_history/presentation/pages/weight_history_page.dart';

class MockWeightRepository extends Mock implements WeightHistoryRepository {}

class MockIdGenerator extends Mock implements IdGenerator {}

class MockPetRepository extends Mock implements PetRepository {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

class MockDeletePet extends Mock implements DeletePet {}

class MockImageStorage extends Mock implements ImageStorage {}

void main() {
  const pet = Pet(
    id: 'pet-1',
    name: 'Fluffy',
    species: PetSpecies.cat,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.sterilized,
  );
  final entry = WeightEntry(
    id: 'entry-1',
    petId: pet.id,
    weight: 4.5,
    measuredAt: DateTime(2025, 1, 12, 10, 30),
  );
  late MockWeightRepository repository;
  late MockPetRepository pets;
  late List<WeightEntry> entries;

  setUpAll(() => registerFallbackValue(entry));

  setUp(() {
    entries = [entry];
    repository = MockWeightRepository();
    when(
      () => repository.getWeightEntries(pet.id),
    ).thenAnswer((_) async => Success(List.of(entries)));
    final ids = MockIdGenerator();
    when(ids.generate).thenReturn('new-entry');
    pets = MockPetRepository();
    when(() => pets.getPets()).thenAnswer((_) async => const Success([pet]));
    when(() => pets.getPetById(pet.id)).thenAnswer(
      (_) async => Success(
        pet.copyWith(weight: entries.isEmpty ? null : entries.first.weight),
      ),
    );
    getIt.registerFactory<PetCubit>(
      () => PetCubit(pets, MockCreatePet(), MockUpdatePet(), MockDeletePet()),
    );
    getIt.registerFactory<WeightHistoryCubit>(
      () => WeightHistoryCubit(repository, ids),
    );
  });

  tearDown(() async {
    await getIt.unregister<PetCubit>();
    await getIt.unregister<WeightHistoryCubit>();
  });

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    String? initialLocation,
    Brightness brightness = Brightness.light,
    double width = 390,
    double height = 720,
    double scale = 1,
    bool keyboard = false,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: initialLocation ?? AppRoutes.weightHistory(pet.id),
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

  Future<void> openAddForm(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add measurement'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('My pets'), findsNothing);
  }

  Future<void> save(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final form = tester.widget<WeightEntryFormPage>(
      find.byType(WeightEntryFormPage),
    );
    final button = find.widgetWithText(
      ElevatedButton,
      form.entry == null ? 'Save' : 'Save changes',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'Edit' : 'Add'} measurement suppresses Android stretch',
      (tester) async {
        await pumpRouter(tester);
        if (editing) {
          await tester.tap(find.text('4.5 kg').last);
          await tester.pumpAndSettle();
        } else {
          await openAddForm(tester);
        }
        expect(
          find.descendant(
            of: find.byType(WeightEntryFormPage),
            matching: find.byType(StretchingOverscrollIndicator),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('profile opens weight history for the selected pet', (
    tester,
  ) async {
    final router = await pumpRouter(
      tester,
      initialLocation: AppRoutes.petDetail(pet.id),
    );
    clearInteractions(pets);
    await tester.ensureVisible(find.text('Weight history'));
    await tester.tap(find.text('Weight history'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.weightHistory(pet.id));
    expect(find.byType(WeightHistoryPage), findsOneWidget);
    verify(() => repository.getWeightEntries(pet.id)).called(1);
    verifyNever(() => pets.getPetById(any()));
  });

  testWidgets('measurement action and both forms keep the pet context', (
    tester,
  ) async {
    await pumpRouter(tester);
    clearInteractions(pets);
    final appBarName = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(pet.name),
    );
    expect(appBarName.hitTestable(), findsOneWidget);
    expect(
      find
          .widgetWithText(FloatingActionButton, 'Add measurement')
          .hitTestable(),
      findsOneWidget,
    );
    await openAddForm(tester);
    expect(appBarName.hitTestable(), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Save').hitTestable(),
      findsOneWidget,
    );
    final date = tester.getRect(find.byType(AppDateField));
    final saveButton = tester.getRect(
      find.widgetWithText(ElevatedButton, 'Save'),
    );
    expect(saveButton.top - date.bottom, lessThanOrEqualTo(32));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
    await tester.pumpAndSettle();
    expect(appBarName.hitTestable(), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Save changes').hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .widget<WeightEntryFormPage>(find.byType(WeightEntryFormPage))
          .entry,
      entry,
    );
    verifyNever(() => pets.getPetById(any()));
  });

  testWidgets('reopening history carries the refreshed profile name', (
    tester,
  ) async {
    var currentPet = pet;
    when(
      () => pets.getPetById(pet.id),
    ).thenAnswer((_) async => Success(currentPet));
    await pumpRouter(tester, initialLocation: AppRoutes.petDetail(pet.id));
    await tester.ensureVisible(find.text('Weight history'));
    await tester.tap(find.text('Weight history'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(pet.name)),
      findsOneWidget,
    );
    currentPet = pet.copyWith(name: 'Luna');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    clearInteractions(pets);
    await tester.ensureVisible(find.text('Weight history'));
    await tester.tap(find.text('Weight history'));
    await tester.pumpAndSettle();
    expect(
      find
          .descendant(of: find.byType(AppBar), matching: find.text('Luna'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.text(pet.name), findsNothing);
    verifyNever(() => pets.getPetById(any()));
  });

  testWidgets(
    'route context for another pet cannot supply the displayed name',
    (tester) async {
      final router = await pumpRouter(tester);
      clearInteractions(pets);
      router.go(
        AppRoutes.weightHistory(pet.id),
        extra: const PetCareRouteExtra(petId: 'pet-2', petName: 'Wrong pet'),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .descendant(of: find.byType(AppBar), matching: find.text(pet.name))
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Wrong pet'), findsNothing);
    },
  );

  testWidgets('weight uses a separate unit when entering a measurement', (
    tester,
  ) async {
    await pumpRouter(
      tester,
      initialLocation: AppRoutes.addEditWeightEntry(pet.id),
    );
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsNothing);
    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();
    expect(find.text('kg').hitTestable(), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '4.8');
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('a late pet name keeps the entered measurement intact', (
    tester,
  ) async {
    final pending = Completer<Result<Pet>>();
    when(() => pets.getPetById(pet.id)).thenAnswer((_) => pending.future);
    await pumpRouter(
      tester,
      initialLocation: AppRoutes.addEditWeightEntry(pet.id),
    );
    await tester.enterText(find.byType(TextFormField).first, '4.8');
    pending.complete(const Success(pet));
    await tester.pumpAndSettle();
    expect(
      find
          .descendant(of: find.byType(AppBar), matching: find.text(pet.name))
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('a pet name lookup failure leaves measurement creation usable', (
    tester,
  ) async {
    when(
      () => repository.createWeightEntry(any()),
    ).thenAnswer((_) async => const Success(null));
    when(() => pets.getPetById(pet.id)).thenAnswer(
      (_) async => const Error(LocalDatabaseFailure('Could not load pet')),
    );
    await pumpRouter(
      tester,
      initialLocation: AppRoutes.addEditWeightEntry(pet.id),
    );
    expect(find.text('Add measurement'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '5.1');
    await save(tester);
    verify(() => repository.createWeightEntry(any())).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a direct history URL and pet change show the matching name and records',
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
      when(
        () => repository.getWeightEntries(other.id),
      ).thenAnswer((_) async => const Success([]));
      final router = await pumpRouter(tester);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(pet.name)),
        findsOneWidget,
      );
      router.go(AppRoutes.weightHistory(other.id));
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
      expect(find.text('No measurements yet'), findsOneWidget);
      expect(find.text('4.5 kg'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text(other.name).hitTestable(), findsOneWidget);
      expect(find.text(pet.name), findsNothing);
    },
  );

  testWidgets('empty history offers a measurement form with today selected', (
    tester,
  ) async {
    entries = [];
    await pumpRouter(tester);
    expect(find.text('No measurements yet'), findsOneWidget);
    expect(find.text('Latest weight'), findsNothing);
    await openAddForm(tester);

    expect(find.byType(WeightEntryFormPage), findsOneWidget);
    final context = tester.element(find.byType(WeightEntryFormPage));
    final today = MaterialLocalizations.of(
      context,
    ).formatShortDate(DateTime.now());
    expect(find.text(today), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'empty history centers and remains usable at $size in $brightness',
        (tester) async {
          entries = [];
          await pumpRouter(
            tester,
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
          );
          final scroll = find.byType(SingleChildScrollView);
          final viewport = find
              .ancestor(of: scroll, matching: find.byType(Expanded))
              .first;
          expect(
            tester.getRect(scroll).center,
            tester.getRect(viewport).center,
          );
          await tester.ensureVisible(find.text('No measurements yet'));
          await tester.pumpAndSettle();
          expect(
            find.text('No measurements yet').hitTestable(),
            findsOneWidget,
          );
          final description = find.text(
            'Add a weight measurement to start the history.',
          );
          await tester.ensureVisible(description);
          await tester.pumpAndSettle();
          expect(description.hitTestable(), findsOneWidget);
          expect(
            tester
                .getRect(description)
                .overlaps(tester.getRect(find.byType(FloatingActionButton))),
            isFalse,
          );
          expect(
            find.byTooltip('Add measurement').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await openAddForm(tester);
          expect(find.byType(WeightEntryFormPage), findsOneWidget);
        },
      );
    }
  }

  for (final input in ['', '0', '-1', 'NaN', 'Infinity', 'abc']) {
    testWidgets('invalid weight "$input" never reaches the repository', (
      tester,
    ) async {
      await pumpRouter(tester);
      await openAddForm(tester);
      await tester.enterText(find.byType(TextFormField).first, input);
      await save(tester);

      expect(
        find.text(
          input.isEmpty
              ? 'Weight is required'
              : 'Enter a weight greater than zero',
        ),
        findsOneWidget,
      );
      verifyNever(() => repository.createWeightEntry(any()));
    });
  }

  for (final editing in [false, true]) {
    for (final input in ['4.125', '4,125', '0.001']) {
      testWidgets('measurement ${editing ? 'edit' : 'add'} accepts "$input"', (
        tester,
      ) async {
        when(
          () => repository.createWeightEntry(any()),
        ).thenAnswer((_) async => const Success(null));
        when(
          () => repository.updateWeightEntry(any()),
        ).thenAnswer((_) async => const Success(null));
        await pumpRouter(tester);
        if (editing) {
          await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
          await tester.pumpAndSettle();
        } else {
          await openAddForm(tester);
        }
        await tester.enterText(find.byType(TextFormField).first, input);
        await save(tester);
        expect(find.byType(WeightHistoryPage), findsOneWidget);
        final saved =
            (editing
                        ? verify(
                            () => repository.updateWeightEntry(captureAny()),
                          )
                        : verify(
                            () => repository.createWeightEntry(captureAny()),
                          ))
                    .captured
                    .single
                as WeightEntry;
        expect(saved.weight, input == '0.001' ? 0.001 : 4.125);
        if (editing) {
          expect(saved.id, entry.id);
          expect(saved.measuredAt, entry.measuredAt);
        }
      });
    }
    testWidgets(
      'measurement ${editing ? 'edit' : 'add'} preserves invalid decimal input',
      (tester) async {
        await pumpRouter(tester, width: 320, scale: 2);
        if (editing) {
          final row = find.widgetWithText(ListTile, '4.5 kg');
          await tester.scrollUntilVisible(row, 200);
          await tester.pumpAndSettle();
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          await tester.tap(row);
          await tester.pumpAndSettle();
        } else {
          await openAddForm(tester);
        }
        final field = find.byType(TextFormField).first;
        for (final input in ['4.1256', '4,1256', '0.0001', '1e-4']) {
          await tester.enterText(field, input);
          await save(tester);
          expect(
            find.text('Use up to 3 decimal places').hitTestable(),
            findsOneWidget,
          );
          expect(
            tester
                .renderObject<RenderParagraph>(
                  find.text('Use up to 3 decimal places'),
                )
                .didExceedMaxLines,
            isFalse,
          );
          expect(tester.widget<TextFormField>(field).controller!.text, input);
          expect(tester.takeException(), isNull);
        }
        verifyNever(() => repository.createWeightEntry(any()));
        verifyNever(() => repository.updateWeightEntry(any()));
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final (weight, text) in [(0.125, '0.125'), (4.0, '4')]) {
      testWidgets('history, form and deletion show $text kg in $brightness', (
        tester,
      ) async {
        entries = [
          WeightEntry(
            id: entry.id,
            petId: pet.id,
            weight: weight,
            measuredAt: entry.measuredAt,
          ),
        ];
        await pumpRouter(tester, brightness: brightness);
        expect(find.text('$text kg'), findsNWidgets(2));
        await tester.tap(
          find.byTooltip('Delete $text kg measurement from Jan 12, 2025'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Remove the $text kg measurement from Jan 12, 2025?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        verifyNever(() => repository.deleteWeightEntry(any()));
        await tester.tap(find.widgetWithText(ListTile, '$text kg'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          text,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Save changes'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsNothing);
        expect(find.byType(WeightHistoryPage), findsOneWidget);
      });
    }
  }

  testWidgets('creation returns to refreshed history', (tester) async {
    when(() => repository.createWeightEntry(any())).thenAnswer((
      invocation,
    ) async {
      entries = [invocation.positionalArguments.first as WeightEntry, entry];
      return const Success(null);
    });
    final router = await pumpRouter(tester);
    await openAddForm(tester);
    expect(router.state.uri.path, AppRoutes.addEditWeightEntry(pet.id));
    await tester.enterText(find.byType(TextFormField).first, '4.8');
    await save(tester);

    expect(find.byType(WeightHistoryPage), findsOneWidget);
    expect(find.text('4.8 kg'), findsNWidgets(2));
    final created =
        verify(() => repository.createWeightEntry(captureAny())).captured.single
            as WeightEntry;
    expect(created.id, 'new-entry');
    expect(created.petId, pet.id);
    expect(created.weight, 4.8);
    expect(DateUtils.isSameDay(created.measuredAt, DateTime.now()), isTrue);
    verify(() => repository.getWeightEntries(pet.id)).called(2);
  });

  testWidgets('save failure preserves weight and selected date for retry', (
    tester,
  ) async {
    var attempts = 0;
    when(() => repository.updateWeightEntry(any())).thenAnswer((
      invocation,
    ) async {
      if (attempts++ == 0) {
        return const Error(
          LocalDatabaseFailure('Could not save. Please retry.'),
        );
      }
      entries = [invocation.positionalArguments.first as WeightEntry];
      return const Success(null);
    });
    await pumpRouter(tester);
    await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '4.7');
    await save(tester);

    expect(find.text('Could not save. Please retry.'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    final formContext = tester.element(find.byType(WeightEntryFormPage));
    expect(
      find.text(
        MaterialLocalizations.of(formContext).formatShortDate(entry.measuredAt),
      ),
      findsOneWidget,
    );
    await save(tester);
    expect(find.byType(WeightHistoryPage), findsOneWidget);
    expect(find.text('4.7 kg'), findsNWidgets(2));
    final updated = verify(
      () => repository.updateWeightEntry(captureAny()),
    ).captured.cast<WeightEntry>();
    expect(updated, hasLength(2));
    expect(updated.last.id, entry.id);
    expect(updated.last.petId, entry.petId);
    expect(updated.last.measuredAt, entry.measuredAt);
    verifyNever(() => repository.createWeightEntry(any()));
  });

  testWidgets('measurement date can be changed before saving', (tester) async {
    when(() => repository.updateWeightEntry(any())).thenAnswer((
      invocation,
    ) async {
      entries = [invocation.positionalArguments.first as WeightEntry];
      return const Success(null);
    });
    await pumpRouter(tester);
    await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose measurement date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('11').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await save(tester);

    final updated =
        verify(() => repository.updateWeightEntry(captureAny())).captured.single
            as WeightEntry;
    expect(updated.measuredAt, DateTime(2025, 1, 11));
  });

  testWidgets('reselecting the measurement day preserves its time', (
    tester,
  ) async {
    when(() => repository.updateWeightEntry(any())).thenAnswer((
      invocation,
    ) async {
      entries = [invocation.positionalArguments.first as WeightEntry];
      return const Success(null);
    });
    await pumpRouter(tester);
    await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose measurement date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '4.7');
    await save(tester);
    final updated =
        verify(() => repository.updateWeightEntry(captureAny())).captured.single
            as WeightEntry;
    expect(updated.measuredAt, entry.measuredAt);
  });

  testWidgets('returning from weight history refreshes the profile weight', (
    tester,
  ) async {
    when(() => repository.updateWeightEntry(any())).thenAnswer((
      invocation,
    ) async {
      entries = [invocation.positionalArguments.first as WeightEntry];
      return const Success(null);
    });
    await pumpRouter(tester, initialLocation: AppRoutes.petDetail(pet.id));
    await tester.ensureVisible(find.text('Weight history'));
    await tester.tap(find.text('Weight history'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '4.9');
    await save(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Profile details'));
    await tester.tap(find.text('Profile details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('4.9 kg'));
    expect(find.text('4.9 kg'), findsOneWidget);
    expect(find.text('4.5 kg'), findsNothing);
  });

  testWidgets('cancelling the form does not reload history', (tester) async {
    await pumpRouter(tester);
    await openAddForm(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(WeightHistoryPage), findsOneWidget);
    verify(() => repository.getWeightEntries(pet.id)).called(1);
    verifyNever(() => repository.createWeightEntry(any()));
  });

  for (final confirm in [false, true]) {
    testWidgets(
      'deletion ${confirm ? 'confirms and updates the list' : 'cancels without deleting'}',
      (tester) async {
        when(() => repository.deleteWeightEntry(entry.id)).thenAnswer((
          _,
        ) async {
          entries = [];
          return const Success(null);
        });
        await pumpRouter(tester);
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        expect(find.text('Delete measurement?'), findsOneWidget);
        await tester.tap(find.text(confirm ? 'Delete' : 'Cancel'));
        await tester.pumpAndSettle();

        if (confirm) {
          expect(find.text('No measurements yet'), findsOneWidget);
          verify(() => repository.deleteWeightEntry(entry.id)).called(1);
          verify(() => repository.getWeightEntries(pet.id)).called(1);
        } else {
          expect(find.text('4.5 kg'), findsNWidgets(2));
          verifyNever(() => repository.deleteWeightEntry(any()));
        }
      },
    );
  }

  testWidgets('load failure offers a working retry', (tester) async {
    final pending = Completer<Result<List<WeightEntry>>>();
    var attempts = 0;
    when(() => repository.getWeightEntries(pet.id)).thenAnswer((_) {
      return attempts++ == 0
          ? Future.value(
              const Error(LocalDatabaseFailure('Could not load measurements')),
            )
          : pending.future;
    });
    await pumpRouter(tester);
    expect(find.text('Could not load measurements'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );
    pending.complete(Success(entries));
    await tester.pumpAndSettle();
    expect(find.text('Latest weight'), findsOneWidget);
    verify(() => repository.getWeightEntries(pet.id)).called(2);
  });

  testWidgets('deleting the latest measurement shows the previous weight', (
    tester,
  ) async {
    final older = WeightEntry(
      id: 'older-entry',
      petId: pet.id,
      weight: 4.2,
      measuredAt: DateTime(2024, 1, 12),
    );
    entries = [entry, older];
    when(() => repository.deleteWeightEntry(entry.id)).thenAnswer((_) async {
      entries = [older];
      return const Success(null);
    });
    await pumpRouter(tester);
    expect(find.text('Jan 12, 2025'), findsNWidgets(2));
    expect(find.text('Jan 12, 2024'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('4.5 kg'), findsNothing);
    expect(find.text('4.2 kg'), findsNWidgets(2));
    expect(find.text('Jan 12, 2024'), findsNWidgets(2));
  });

  testWidgets(
    'delete failure keeps the list and retries only after confirmation',
    (tester) async {
      var attempts = 0;
      when(() => repository.deleteWeightEntry(entry.id)).thenAnswer((_) async {
        if (attempts++ == 0) {
          return const Error(
            LocalDatabaseFailure('Could not delete measurement'),
          );
        }
        entries = [];
        return const Success(null);
      });
      await pumpRouter(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Could not delete measurement'), findsOneWidget);
      expect(find.text('4.5 kg'), findsNWidgets(2));
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('4.5 kg'), findsNWidgets(2));
      verify(() => repository.deleteWeightEntry(entry.id)).called(1);
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No measurements yet'), findsOneWidget);
      verify(() => repository.deleteWeightEntry(entry.id)).called(1);
      verify(() => repository.getWeightEntries(pet.id)).called(1);
    },
  );

  testWidgets('history and form have labeled accessible tap targets', (
    tester,
  ) async {
    await pumpRouter(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await openAddForm(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('duplicate submissions and back during save are safe', (
    tester,
  ) async {
    final pending = Completer<Result<void>>();
    when(
      () => repository.createWeightEntry(any()),
    ).thenAnswer((_) => pending.future);
    await pumpRouter(tester);
    await openAddForm(tester);
    await tester.enterText(find.byType(TextFormField).first, '5');
    final field = tester.widget<TextField>(find.byType(TextField).first);
    field.onSubmitted!('5');
    field.onSubmitted!('5');
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(WeightEntryFormPage), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
    pending.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(find.byType(WeightHistoryPage), findsOneWidget);
    verify(() => repository.createWeightEntry(any())).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second submit after success cannot save or pop twice', (
    tester,
  ) async {
    when(
      () => repository.createWeightEntry(any()),
    ).thenAnswer((_) async => const Success(null));
    await pumpRouter(tester);
    await openAddForm(tester);
    await tester.enterText(find.byType(TextFormField).first, '5.2');
    final submit = tester
        .widget<TextField>(find.byType(TextField).first)
        .onSubmitted!;
    submit('5.2');
    await tester.idle();
    submit('5.2');
    await tester.pumpAndSettle();
    expect(find.byType(WeightHistoryPage), findsOneWidget);
    verify(() => repository.createWeightEntry(any())).called(1);
  });

  for (final editing in [false, true]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'dirty ${editing ? 'edit' : 'add'} form protects input on ${systemBack ? 'system' : 'app bar'} back',
        (tester) async {
          await pumpRouter(tester);
          if (editing) {
            await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
            await tester.pumpAndSettle();
          } else {
            await openAddForm(tester);
          }
          await tester.enterText(find.byType(TextFormField).first, '4.7');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          Future<void> back() async {
            if (systemBack) {
              await tester.binding.handlePopRoute();
            } else {
              await tester.tap(find.byTooltip('Back'));
            }
            await tester.pumpAndSettle();
          }

          await back();
          expect(find.text('Discard changes?'), findsOneWidget);
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(find.text('4.7'), findsOneWidget);
          await back();
          await tester.tap(find.text('Discard changes'));
          await tester.pumpAndSettle();
          expect(find.byType(WeightHistoryPage), findsOneWidget);
          verifyNever(() => repository.createWeightEntry(any()));
          verifyNever(() => repository.updateWeightEntry(any()));
        },
      );
    }
  }

  testWidgets(
    'unchanged edit closes without confirmation and cannot be saved',
    (tester) async {
      await pumpRouter(tester);
      await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Save changes'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(WeightHistoryPage), findsOneWidget);
      verifyNever(() => repository.updateWeightEntry(any()));
    },
  );

  testWidgets('date-only edit is protected before leaving', (tester) async {
    await pumpRouter(tester);
    await tester.tap(find.widgetWithText(ListTile, '4.5 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose measurement date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Jan 11, 2025'), findsOneWidget);
  });

  testWidgets('pending save failure stays on the form with input and retry', (
    tester,
  ) async {
    final pending = Completer<Result<void>>();
    when(
      () => repository.createWeightEntry(any()),
    ).thenAnswer((_) => pending.future);
    await pumpRouter(tester);
    await openAddForm(tester);
    await tester.enterText(find.byType(TextFormField).first, '5.2');
    tester.widget<TextField>(find.byType(TextField).first).onSubmitted!('5.2');
    await tester.pump();
    expect(find.byTooltip('My pets'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(WeightEntryFormPage), findsOneWidget);
    pending.complete(
      const Error(LocalDatabaseFailure('Failed to create measurement')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Failed to create measurement').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('5.2'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'pending deletion blocks exit and profile refreshes after completion',
    (tester) async {
      final older = WeightEntry(
        id: 'older-entry',
        petId: pet.id,
        weight: 4.2,
        measuredAt: DateTime(2024, 1, 12),
      );
      entries = [entry, older];
      final pending = Completer<Result<void>>();
      when(() => repository.deleteWeightEntry(entry.id)).thenAnswer((_) async {
        final result = await pending.future;
        entries = [older];
        return result;
      });
      await pumpRouter(tester, initialLocation: AppRoutes.petDetail(pet.id));
      await tester.ensureVisible(find.text('Weight history'));
      await tester.tap(find.text('Weight history'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(find.text('4.5 kg'), findsNWidgets(2));
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(WeightHistoryPage), findsOneWidget);
      pending.complete(const Success(null));
      await tester.pumpAndSettle();
      expect(find.text('4.5 kg'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Profile details'));
      await tester.tap(find.text('Profile details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('4.2 kg'));
      expect(find.text('4.2 kg'), findsOneWidget);
      expect(find.text('4.5 kg'), findsNothing);
    },
  );

  testWidgets(
    'delete error and confirmed retry preserve a long list scroll position',
    (tester) async {
      entries = List.generate(
        30,
        (i) => WeightEntry(
          id: 'entry-$i',
          petId: pet.id,
          weight: 4.5 + i / 10,
          measuredAt: DateTime(2025, 1, 30 - i),
        ),
      );
      var attempts = 0;
      when(() => repository.deleteWeightEntry(any())).thenAnswer((
        invocation,
      ) async {
        if (attempts++ == 0) {
          return const Error(
            LocalDatabaseFailure('Failed to delete measurement'),
          );
        }
        entries.removeWhere(
          (item) => item.id == invocation.positionalArguments.first,
        );
        return const Success(null);
      });
      await pumpRouter(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = scroll.pixels;
      expect(offset, greaterThan(0));
      await tester.tap(find.byIcon(Icons.delete_outline).hitTestable().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Failed to delete measurement').hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(scroll.pixels, offset);
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      expect(find.text('Delete measurement?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to delete measurement'), findsNothing);
      expect(scroll.pixels, offset);
      verify(() => repository.getWeightEntries(pet.id)).called(1);
    },
  );

  for (final brightness in Brightness.values) {
    for (final (size, scale, keyboard) in [
      (const Size(320, 568), 2.0, true),
      (const Size(640, 320), 2.0, false),
      (const Size(320, 568), 3.0, false),
    ]) {
      testWidgets(
        'long pet name keeps measurement entry usable at $size and $scale in $brightness',
        (tester) async {
          final namedPet = pet.copyWith(
            name: 'Fluffy with a very long family name',
          );
          when(
            () => pets.getPetById(pet.id),
          ).thenAnswer((_) async => Success(namedPet));
          when(
            () => repository.createWeightEntry(any()),
          ).thenAnswer((_) async => const Success(null));
          await pumpRouter(
            tester,
            initialLocation: AppRoutes.addEditWeightEntry(pet.id),
            brightness: brightness,
            width: size.width,
            height: size.height,
            scale: scale,
            keyboard: keyboard,
          );
          expect(
            find
                .descendant(
                  of: find.byType(AppBar),
                  matching: find.text(namedPet.name),
                )
                .hitTestable(),
            findsOneWidget,
          );
          final field = find.byType(TextFormField).first;
          await tester.ensureVisible(field);
          await tester.enterText(field, '5.2');
          await save(tester);
          expect(find.byType(WeightHistoryPage), findsOneWidget);
          verify(() => repository.createWeightEntry(any())).called(1);
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'shared history feedback is aligned and retry reconfirms at $size in $brightness',
        (tester) async {
          when(() => repository.deleteWeightEntry(entry.id)).thenAnswer(
            (_) async => const Error(
              LocalDatabaseFailure('Failed to delete measurement'),
            ),
          );
          await pumpRouter(
            tester,
            width: size.width,
            height: size.height,
            scale: 2,
            brightness: brightness,
          );
          final delete = find.byIcon(Icons.delete_outline);
          await tester.scrollUntilVisible(
            delete,
            150,
            scrollable: find.descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(delete);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
          final message = find.text('Failed to delete measurement');
          final retry = find.text('Retry deletion');
          expect(retry.hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(retry).dx,
            closeTo(tester.getTopLeft(message).dx, 0.1),
          );
          expect(
            tester
                .getRect(retry)
                .overlaps(tester.getRect(find.byType(FloatingActionButton))),
            isFalse,
          );
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(find.text('Delete measurement?'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(WeightHistoryPage), findsOneWidget);
          verify(() => repository.deleteWeightEntry(entry.id)).called(1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final brightness in Brightness.values) {
    for (final (width, height, scale, keyboard) in [
      (320.0, 568.0, 2.0, true),
      (640.0, 320.0, 2.0, false),
    ]) {
      testWidgets(
        'save error and retry stay visible at $width x $height in $brightness',
        (tester) async {
          when(() => repository.createWeightEntry(any())).thenAnswer(
            (_) async => const Error(
              LocalDatabaseFailure('Failed to create measurement'),
            ),
          );
          await pumpRouter(
            tester,
            brightness: brightness,
            width: width,
            height: height,
            scale: scale,
            keyboard: keyboard,
          );
          await openAddForm(tester);
          await tester.enterText(find.byType(TextFormField).first, '5.2');
          tester.widget<TextField>(find.byType(TextField).first).onSubmitted!(
            '5.2',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final error = find.text('Failed to create measurement');
          expect(error.hitTestable(), findsOneWidget);
          final viewport = tester.getRect(find.byType(SingleChildScrollView));
          expect(
            tester.getRect(error).top,
            greaterThanOrEqualTo(viewport.top - 0.1),
          );
          expect(
            tester.getRect(error).bottom,
            lessThanOrEqualTo(viewport.bottom),
          );
          final saveButton = find.widgetWithText(ElevatedButton, 'Save');
          expect(
            tester.getRect(error).bottom,
            lessThanOrEqualTo(tester.getRect(saveButton).top),
          );
          expect(
            find.widgetWithText(ElevatedButton, 'Save').hitTestable(),
            findsOneWidget,
          );
          expect(find.text('5.2'), findsOneWidget);
          when(
            () => repository.createWeightEntry(any()),
          ).thenAnswer((_) async => const Success(null));
          await save(tester);
          expect(find.byType(WeightHistoryPage), findsOneWidget);
          verify(() => repository.createWeightEntry(any())).called(2);
        },
      );
    }
    for (final (width, scale) in [(320.0, 2.0), (800.0, 1.0)]) {
      testWidgets('history and form fit $width at $scale in $brightness', (
        tester,
      ) async {
        await pumpRouter(
          tester,
          brightness: brightness,
          width: width,
          scale: scale,
          keyboard: true,
        );
        expect(tester.takeException(), isNull);
        final addButton = tester.getRect(find.byType(FloatingActionButton));
        expect(addButton.left, greaterThanOrEqualTo(0));
        expect(addButton.right, lessThanOrEqualTo(width));
        await openAddForm(tester);
        await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
        expect(find.text('Save').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
