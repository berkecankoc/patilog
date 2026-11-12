import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/di/injection.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/router/app_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/services/external_link_launcher.dart';
import 'package:patilog/features/settings/domain/entities/language_preference.dart';
import 'package:patilog/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/settings_test_harness.dart';

class FakeLinkLauncher implements ExternalLinkLauncher {
  final opened = <Uri>[];
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

void main() {
  late SettingsTestHarness app;
  late FakeLinkLauncher links;
  setUpAll(SettingsTestHarness.initialize);
  setUp(() {
    app = SettingsTestHarness()..register();
    links = FakeLinkLauncher();
    getIt.registerSingleton<ExternalLinkLauncher>(links);
  });

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    // scrollUntilVisible stops once the item is built, which may still be
    // below the viewport edge.
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  testWidgets('privacy policy and source code open in the browser', (
    tester,
  ) async {
    await app.pump(tester);
    await scrollTo(tester, find.text('Open-source licenses'));
    expect(find.text('About'), findsOneWidget);
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source code'));
    await tester.pumpAndSettle();
    expect(links.opened, [
      Uri.parse('https://berkecankoc.github.io/patilog-site/privacy/'),
      Uri.parse('https://github.com/berkecankoc/patilog'),
    ]);
    expect(find.byType(SnackBar), findsNothing);
    expect(appRouter.state.uri.path, AppRoutes.settings);
  });

  testWidgets('Turkish opens the Turkish privacy policy', (tester) async {
    app.storedLanguage = LanguagePreference.turkish;
    await app.pump(tester);
    await scrollTo(tester, find.text('Gizlilik politikası'));
    expect(find.text('Hakkında'), findsOneWidget);
    await tester.tap(find.text('Gizlilik politikası'));
    await tester.pumpAndSettle();
    expect(links.opened, [
      Uri.parse('https://berkecankoc.github.io/patilog-site/tr/privacy/'),
    ]);
  });

  testWidgets(
    'a link that cannot open offers a reachable Copy link on large text',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      links.result = false;
      await app.pump(tester, size: const Size(320, 568), scale: 2);
      await scrollTo(tester, find.text('Source code'));
      await tester.tap(find.text('Source code'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't open the link."), findsOneWidget);
      expect(find.text('Copy link').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(copied, 'https://github.com/berkecankoc/patilog');
      expect(find.text('Link copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('links stay disabled while a preference is saving', (
    tester,
  ) async {
    await app.pump(tester);
    app.pendingSave = Completer<Result<void>>();
    await tester.tap(find.text('Dark'));
    await tester.pump();
    await scrollTo(tester, find.text('Open-source licenses'));
    await tester.tap(find.text('Privacy policy'));
    await tester.tap(find.text('Open-source licenses'));
    await tester.pump();
    expect(links.opened, isEmpty);
    expect(appRouter.state.uri.path, AppRoutes.settings);
    app.pendingSave!.complete(const Success<void>(null));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'licenses open as a Settings route and both Back paths return to Settings',
    (tester) async {
      await app.pump(tester);
      for (final systemBack in [false, true]) {
        await scrollTo(tester, find.text('Open-source licenses'));
        await tester.tap(find.text('Open-source licenses'));
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, AppRoutes.openSourceLicenses);
        expect(find.byType(LicensePage), findsOneWidget);
        expect(
          find.textContaining('Licensed under the GNU GPL v3 or later.'),
          findsOneWidget,
        );
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, AppRoutes.settings);
        expect(find.byType(SettingsPage), findsOneWidget);
      }
      expect(links.opened, isEmpty);
    },
  );
}
