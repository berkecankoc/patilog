import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/error_view.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [const Size(640, 320), const Size(320, 568)]) {
      testWidgets(
        'error and retry are reachable at $size with large text in $brightness',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var attempts = 0;
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: brightness == Brightness.light
                  ? AppTheme.light
                  : AppTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('Weight history')),
                body: ErrorView(
                  message: 'Failed to load weight history',
                  onRetry: () => attempts++,
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Failed to load weight history'), findsOneWidget);
          final retry = find.widgetWithText(ElevatedButton, 'Retry');
          await tester.ensureVisible(retry);
          expect(retry.hitTestable(), findsOneWidget);
          expect(tester.getRect(retry).bottom, lessThanOrEqualTo(size.height));
          await tester.tap(retry);
          expect(attempts, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
