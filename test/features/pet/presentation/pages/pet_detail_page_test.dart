import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/theme/app_theme.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/storage/image_storage.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';
import 'package:patilog/features/pet/domain/use_cases/create_pet.dart';
import 'package:patilog/features/pet/domain/use_cases/delete_pet.dart';
import 'package:patilog/features/pet/domain/use_cases/update_pet.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:patilog/features/pet/presentation/pages/pet_detail_page.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

class MockDeletePet extends Mock implements DeletePet {}

void main() {
  for (final brightness in Brightness.values) {
    for (final (width, textScale) in [(320.0, 2.0), (800.0, 1.0)]) {
      testWidgets(
        'profile fits width $width and text scale $textScale in $brightness mode',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const pet = Pet(
            id: 'pet-1',
            name: 'Fluffy with a very long name',
            species: PetSpecies.cat,
            sex: PetSex.female,
            reproductiveStatus: ReproductiveStatus.sterilized,
            weight: 0.125,
            microchipId: '123456789012345',
            imagePath: '/missing-pet-photo.jpg',
          );
          final repository = MockPetRepository();
          final imageStorage = MockImageStorage();
          when(() => imageStorage.resolvePath(any())).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments.first as String,
          );
          when(
            () => repository.getPetById(pet.id),
          ).thenAnswer((_) async => const Success(pet));
          final cubit = PetCubit(
            repository,
            MockCreatePet(),
            MockUpdatePet(),
            MockDeletePet(),
          );
          await cubit.getPetById(pet.id);
          addTearDown(cubit.close);

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: brightness == Brightness.light
                  ? AppTheme.light
                  : AppTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: RepositoryProvider<ImageStorage>.value(
                value: imageStorage,
                child: BlocProvider<PetCubit>.value(
                  value: cubit,
                  child: const PetDetailPage(petId: 'pet-1'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(pet.name), findsOneWidget);
          expect(find.text('Coming soon'), findsNothing);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is ListTile && !widget.enabled,
            ),
            findsNothing,
          );
          expect(find.byTooltip('Edit profile'), findsOneWidget);
          expect(find.byTooltip('My pets'), findsNothing);
          expect(find.text('Care records'), findsNothing);
          expect(find.byType(ExpansionTile), findsNothing);
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byTooltip('Edit profile'),
            ),
            findsNothing,
          );
          expect(
            find.descendant(
              of: find.byType(Card),
              matching: find.byTooltip('Edit profile'),
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Profile details'));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          const fieldOrder = [
            'Sex',
            'Breed',
            'Reproductive status',
            'Birth date',
            'Current weight',
            'Microchip ID',
          ];
          final displayedFields = tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byType(Card),
                  matching: find.byType(Text),
                ),
              )
              .map((text) => text.data)
              .where(fieldOrder.contains)
              .toList();
          expect(displayedFields, fieldOrder);
          for (final icon in [
            Icons.wc_outlined,
            Icons.category_outlined,
            Icons.health_and_safety_outlined,
            Icons.cake_outlined,
            Icons.monitor_weight_outlined,
            Icons.memory_outlined,
          ]) {
            expect(
              find.descendant(
                of: find.byType(Card),
                matching: find.byIcon(icon),
              ),
              findsOneWidget,
            );
          }
          expect(find.text('0.125 kg'), findsOneWidget);
          expect(find.text('Not provided'), findsNWidgets(2));
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.text(pet.microchipId!));
          await tester.pumpAndSettle();
          expect(find.text(pet.microchipId!).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
