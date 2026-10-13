import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_detail_page.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

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
          final cubit = PetCubit(repository, MockCreatePet(), MockUpdatePet());
          await cubit.getPetById(pet.id);
          addTearDown(cubit.close);

          await tester.pumpWidget(
            MaterialApp(
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
          expect(find.text('Coming soon'), findsNWidgets(3));
          expect(
            find.byWidgetPredicate(
              (widget) => widget is ListTile && !widget.enabled,
            ),
            findsNWidgets(3),
          );
          expect(find.byTooltip('Edit profile'), findsOneWidget);
          for (final title in [
            'Vet visits',
            'Vaccines',
            'Medicine',
            'Weight history',
          ]) {
            expect(find.text(title), findsOneWidget);
          }
          expect(find.text('Not provided'), findsNothing);
          await tester.ensureVisible(find.text('Profile details'));
          await tester.tap(find.text('Profile details'));
          await tester.pumpAndSettle();
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
                  of: find.byType(ExpansionTile),
                  matching: find.byType(Text),
                ),
              )
              .map((text) => text.data)
              .where(fieldOrder.contains)
              .toList();
          expect(displayedFields, fieldOrder);
          expect(find.text('Not provided'), findsNWidgets(3));
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
