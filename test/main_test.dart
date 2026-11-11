import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/router/app_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/features/all_pets_care/presentation/pages/all_pets_care_page.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/settings/domain/entities/theme_preference.dart';
import 'package:patilog/features/settings/presentation/pages/settings_page.dart';

import 'helpers/settings_test_harness.dart';

void main() {
  late SettingsTestHarness app;
  setUpAll(SettingsTestHarness.initialize);
  setUp(() {
    app = SettingsTestHarness()..register();
  });

  testWidgets(
    'the first application frame uses the loaded theme and owns the Cubit',
    (tester) async {
      app.stored = ThemePreference.dark;
      await app.pump(tester, settle: false);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(app.cubit.isClosed, isTrue);
    },
  );

  testWidgets(
    'System follows platform changes while explicit Light stays Light',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await app.pump(tester);
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(SettingsPage))).brightness;
      expect(brightness(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
    },
  );

  testWidgets('care filters survive a theme change through My pets', (
    tester,
  ) async {
    const pets = [
      Pet(
        id: 'pet',
        name: 'Simba',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      ),
      Pet(
        id: 'other',
        name: 'Buddy',
        species: PetSpecies.dog,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      ),
    ];
    when(app.care.pets.getPets).thenAnswer((_) async => const Success(pets));
    await app.pump(tester, location: AppRoutes.allVetVisits);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buddy · Dog').last);
    await tester.pumpAndSettle();
    appRouter.go(AppRoutes.pets);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    appRouter.go(AppRoutes.allVetVisits);
    await tester.pumpAndSettle();
    expect(find.text('Buddy · Dog'), findsOneWidget);
    verify(app.care.visits.getAllVetVisits).called(1);
    verify(app.care.pets.getPets).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only My pets has Settings and theme changes retain root state and scroll',
    (tester) async {
      final pets = List.generate(
        15,
        (i) => Pet(
          id: 'pet-$i',
          name: 'Pet $i',
          species: PetSpecies.cat,
          sex: PetSex.male,
          reproductiveStatus: ReproductiveStatus.intact,
        ),
      );
      when(app.care.pets.getPets).thenAnswer((_) async => Success(pets));
      await app.pump(tester, location: AppRoutes.pets);
      final root = tester.state(find.byType(AllPetsCarePage));
      final scroll = find
          .descendant(
            of: find.byType(AllPetsCarePage),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.drag(scroll, const Offset(0, -350));
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(scroll).position.pixels;
      expect(offset, greaterThan(0));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, AppRoutes.settings);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(AllPetsCarePage)), same(root));
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        closeTo(offset, 0.1),
      );
      verify(app.care.pets.getPets).called(1);
      verify(app.repository.getThemePreference).called(1);
      for (final path in [
        AppRoutes.allVetVisits,
        AppRoutes.allVaccinations,
        AppRoutes.allMedications,
      ]) {
        appRouter.go(path);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Settings'), findsNothing);
      }
    },
  );
}
