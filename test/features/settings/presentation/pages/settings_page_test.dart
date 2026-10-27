import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/settings_test_harness.dart';

void main() {
  late SettingsTestHarness app;
  setUpAll(SettingsTestHarness.initialize);
  setUp(() {
    app = SettingsTestHarness()..register();
  });

  testWidgets(
    'direct Settings route reads preferences without loading pet data',
    (tester) async {
      await app.pump(tester);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.byType(RadioListTile<ThemePreference>), findsNWidgets(3));
      expect(find.byType(NavigationBar), findsNothing);
      verify(app.repository.getThemePreference).called(1);
      verifyNever(app.care.pets.getPets);
      verifyNever(app.care.visits.getAllVetVisits);
      verifyNever(app.care.vaccinations.getAllVaccinations);
      verifyNever(app.care.repository.getAllMedications);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, AppRoutes.pets);
    },
  );

  testWidgets('failed initial load uses System and offers a working retry', (
    tester,
  ) async {
    app.failLoad = true;
    await app.pump(tester);
    expect(find.text('Failed to load theme preference'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    app.pendingLoad = Completer<Result<ThemePreference>>();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Failed to load theme preference'), findsNothing);
    for (final tile in tester.widgetList<RadioListTile<ThemePreference>>(
      find.byType(RadioListTile<ThemePreference>),
    )) {
      expect(tile.enabled, isFalse);
    }
    app.pendingLoad!.complete(const Success(ThemePreference.dark));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    verify(app.repository.getThemePreference).called(2);
  });

  testWidgets(
    'failed change keeps the previous theme and retries the same choice',
    (tester) async {
      app.stored = ThemePreference.light;
      app.failSave = true;
      await app.pump(tester);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to save theme preference'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      app.failSave = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(app.stored, ThemePreference.dark);
      expect(find.text('Failed to save theme preference'), findsNothing);
      verify(
        () => app.repository.setThemePreference(ThemePreference.dark),
      ).called(2);
    },
  );

  testWidgets('error feedback leaves all remaining height for the choices', (
    tester,
  ) async {
    app.failLoad = true;
    await app.pump(tester, size: const Size(320, 568), scale: 1.6);
    final list = tester.getRect(find.byType(ListView));
    expect(list.bottom, closeTo(568, 0.1));
    expect(find.text('Retry').hitTestable(), findsOneWidget);
  });

  testWidgets('a failed change retains scroll and keeps Retry visible', (
    tester,
  ) async {
    app.stored = ThemePreference.light;
    app.failSave = true;
    await app.pump(tester, size: const Size(320, 360), scale: 2);
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -600));
    await tester.pumpAndSettle();
    final scroll = find.descendant(of: list, matching: find.byType(Scrollable));
    final offset = tester.state<ScrollableState>(scroll).position.pixels;
    expect(offset, greaterThan(0));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scroll).position.pixels,
      closeTo(offset, 0.1),
    );
    expect(find.text('Retry').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending save blocks immediate Back, system Back and route exit',
    (tester) async {
      await app.pump(tester, location: AppRoutes.pets);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      app.pendingSave = Completer<Result<void>>();
      await tester.tap(find.text('Dark'));
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(appRouter.state.uri.path, AppRoutes.settings);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(appRouter.state.uri.path, AppRoutes.settings);
      appRouter.pop();
      await tester.pump();
      expect(appRouter.state.uri.path, AppRoutes.settings);
      app.pendingSave!.complete(const Success<void>(null));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, AppRoutes.pets);
      verify(
        () => app.repository.setThemePreference(ThemePreference.dark),
      ).called(1);
    },
  );

  for (final preference in [ThemePreference.light, ThemePreference.dark]) {
    testWidgets(
      '${preference.name} narrow large-text errors and choices remain reachable',
      (tester) async {
        app.stored = preference;
        app.failLoad = true;
        tester.platformDispatcher.platformBrightnessTestValue =
            preference == ThemePreference.dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await app.pump(tester, size: const Size(320, 360), scale: 2);
        expect(find.text('Retry').hitTestable(), findsOneWidget);
        final list = find.byType(ListView);
        await tester.drag(list, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(find.text('Dark').hitTestable(), findsOneWidget);
        expect(find.text('Retry').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('appearance controls meet tap target and label guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await app.pump(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
