import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/settings/presentation/pages/settings_page.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

import '../../../../helpers/settings_test_harness.dart';

void main() {
  late SettingsTestHarness app;
  setUpAll(SettingsTestHarness.initialize);
  setUp(() {
    app = SettingsTestHarness()..register();
  });

  Future<void> select(WidgetTester tester, LanguagePreference choice) async {
    final tile = find.byWidgetPredicate(
      (widget) =>
          widget is RadioListTile<LanguagePreference> && widget.value == choice,
    );
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'System follows changing device languages while explicit English remains US',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [turkishLocale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await app.pump(tester);
      expect(find.text('Ayarlar'), findsOneWidget);
      await select(tester, LanguagePreference.english);
      expect(find.text('Settings'), findsOneWidget);
      expect(
        Localizations.localeOf(tester.element(find.byType(SettingsPage))),
        englishLocale,
      );
      tester.platformDispatcher.localesTestValue = [
        const Locale('fr', 'FR'),
        turkishLocale,
      ];
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      await select(tester, LanguagePreference.system);
      expect(find.text('Ayarlar'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [const Locale('en', 'GB')];
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(find.byType(SettingsPage))),
        englishLocale,
      );
      verify(app.notifications.repository.initialize).called(1);
      verifyNever(app.notifications.repository.requestNotificationPermission);
      verifyNever(app.notifications.repository.requestExactAlarmPermission);
    },
  );

  testWidgets(
    'a stored Turkish preference is used at startup on an English device',
    (tester) async {
      app.storedLanguage = LanguagePreference.turkish;
      tester.platformDispatcher.localesTestValue = [englishLocale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await app.pump(tester);
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.text('Bildirimler'), findsOneWidget);
      expect(find.text('Görünüm'), findsOneWidget);
      expect(app.cubit.state.languagePreference, LanguagePreference.turkish);
      verify(app.repository.getLanguagePreference).called(1);
    },
  );

  testWidgets(
    'failed language save retains the old locale and retries the same choice',
    (tester) async {
      app.failLanguageSave = true;
      await app.pump(tester);
      final page = tester.element(find.byType(SettingsPage));
      await select(tester, LanguagePreference.turkish);
      expect(find.text('Failed to save language preference'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      app.failLanguageSave = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(tester.element(find.byType(SettingsPage)), same(page));
      expect(app.storedLanguage, LanguagePreference.turkish);
      verify(
        () => app.repository.setLanguagePreference(LanguagePreference.turkish),
      ).called(2);
    },
  );

  testWidgets(
    'a failed read of both preferences is localized and remains recoverable after saving only a theme',
    (tester) async {
      app.failLoad = true;
      app.failLanguageLoad = true;
      tester.platformDispatcher.localesTestValue = [turkishLocale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await app.pump(tester);
      expect(find.text('Ayarlar yüklenemedi'), findsOneWidget);
      await tester.tap(find.text('Koyu'));
      await tester.pumpAndSettle();
      expect(find.text('Dil tercihi yüklenemedi'), findsOneWidget);
      app.failLoad = false;
      app.failLanguageLoad = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(app.cubit.state.hasLoaded, isTrue);
      expect(find.text('Dil tercihi yüklenemedi'), findsNothing);
    },
  );

  testWidgets(
    'pending language writes block both Back paths and other preference writes',
    (tester) async {
      await app.pump(tester, location: AppRoutes.pets);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      app.pendingLanguageSave = Completer<Result<void>>();
      final tile = find.widgetWithText(
        RadioListTile<LanguagePreference>,
        'Türkçe',
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.tap(find.byType(BackButton));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(appRouter.state.uri.path, AppRoutes.settings);
      expect(app.cubit.state.languagePreference, LanguagePreference.system);
      await app.cubit.setThemePreference(ThemePreference.dark);
      app.pendingLanguageSave!.complete(const Success<void>(null));
      await tester.pumpAndSettle();
      expect(find.text('Ayarlar'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, AppRoutes.pets);
      verifyNever(() => app.repository.setThemePreference(any()));
    },
  );

  testWidgets(
    'a locale change preserves an open form draft and its Cubit identity',
    (tester) async {
      await app.pump(tester, location: AppRoutes.addEditPet);
      final name = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(name, 'İnci');
      final cubit = tester.element(name).read<PetCubit>();
      await app.cubit.setLanguagePreference(LanguagePreference.turkish);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(name).controller!.text, 'İnci');
      expect(tester.element(name).read<PetCubit>(), same(cubit));
      expect(Localizations.localeOf(tester.element(name)), turkishLocale);
      expect(appRouter.state.uri.path, AppRoutes.addEditPet);
    },
  );

  testWidgets('an open dialog updates language without losing its input', (
    tester,
  ) async {
    await app.pump(tester);
    final controller = TextEditingController(text: 'Taslak');
    addTearDown(controller.dispose);
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(SettingsPage)),
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).languageTitle),
          content: TextField(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await app.cubit.setLanguagePreference(LanguagePreference.turkish);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Dil'), findsOneWidget);
    expect(controller.text, 'Taslak');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  for (final theme in [ThemePreference.light, ThemePreference.dark]) {
    testWidgets(
      'Turkish ${theme.name} choices and retry remain reachable on a short screen with large text',
      (tester) async {
        app.stored = theme;
        app.storedLanguage = LanguagePreference.turkish;
        app.failLanguageSave = true;
        await app.pump(tester, size: const Size(320, 360), scale: 2);
        await select(tester, LanguagePreference.english);
        expect(find.text('Dil tercihi kaydedilemedi'), findsOneWidget);
        expect(find.text('Tekrar dene').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('English'));
        await tester.pumpAndSettle();
        expect(find.text('English').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
