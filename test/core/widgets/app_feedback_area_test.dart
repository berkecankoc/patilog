import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/core/widgets/app_feedback_area.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<Widget> strips, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              AppFeedbackArea(children: strips),
              const Expanded(child: SizedBox(key: Key('content'))),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double content(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('content'))).height;

  AppErrorFeedback strip(String message) => AppErrorFeedback(
    message: message,
    retryLabel: 'Retry $message',
    onRetry: () {},
  );

  testWidgets('no strips leave the full height to the content', (tester) async {
    await pump(tester, const []);
    expect(content(tester), 844);
  });

  testWidgets('a strip leaves all remaining height to the content', (
    tester,
  ) async {
    await pump(tester, [strip('Failed')]);
    final area = tester.getSize(find.byType(AppFeedbackArea)).height;
    expect(area, greaterThan(0));
    expect(content(tester), 844 - area);
  });

  testWidgets(
    'stacked strips with large text stay within half the screen and scroll to each action',
    (tester) async {
      const size = Size(320, 568);
      var retried = '';
      await pump(
        tester,
        [
          for (final message in ['A long load failure message', 'Second'])
            AppErrorFeedback(
              message: message,
              retryLabel: 'Retry $message',
              onRetry: () => retried = message,
            ),
        ],
        size: size,
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(AppFeedbackArea)).height,
        lessThanOrEqualTo(size.height * AppFeedbackArea.maxHeightFraction),
      );
      expect(content(tester), greaterThanOrEqualTo(size.height / 2));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Retry Second'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry Second'));
      expect(retried, 'Second');
      await tester.ensureVisible(
        find.text('Retry A long load failure message'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry A long load failure message'));
      expect(retried, 'A long load failure message');
    },
  );

  testWidgets(
    'a single long strip keeps its action visible while the message scrolls',
    (tester) async {
      const size = Size(320, 568);
      await pump(
        tester,
        [
          AppErrorFeedback(
            message: List.filled(40, 'Loading failed.').join(' '),
            retryLabel: 'Retry loading',
            onRetry: () {},
          ),
        ],
        size: size,
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(AppFeedbackArea)).height,
        lessThanOrEqualTo(size.height * AppFeedbackArea.maxHeightFraction),
      );
      expect(find.text('Retry loading').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
