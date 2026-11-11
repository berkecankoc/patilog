import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/theme/app_theme.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/presentation/utils/weight_chart_data.dart';
import 'package:patilog/features/weight_history/presentation/widgets/weight_history_chart.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

import '../../../../helpers/multi_step_form_helpers.dart';

WeightEntry measurement(String id, DateTime day, double weight) =>
    WeightEntry(id: id, petId: 'pet', weight: weight, measuredAt: day);

void main() {
  setUpAll(loadFormTestFont);
  Future<void> pumpChart(
    WidgetTester tester,
    List<WeightEntry> entries, {
    Locale locale = const Locale('en', 'US'),
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 720),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: WeightHistoryChart(
                key: const ValueKey('pet'),
                entries: entries,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'starts with three months; all-history recovers an empty period',
    (tester) async {
      await pumpChart(tester, [measurement('old', DateTime(2020), 4.5)]);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey(WeightChartRange.threeMonths)),
            )
            .selected,
        isTrue,
      );
      expect(find.text('No measurements in this period.'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      await tester.tap(find.text('Show all history'));
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsOneWidget);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineBarsData.single.spots.single.y, 4.5);
      expect(data.minX, lessThan(data.maxX));
      expect(find.textContaining('One day recorded.'), findsOneWidget);
    },
  );

  testWidgets(
    'filter survives data and language changes; tooltips use exact local values',
    (tester) async {
      final entries = [
        measurement('new', DateTime(2020, 1, 12), 4.525),
        measurement('old', DateTime(2020, 1, 2), 4.1),
      ];
      await pumpChart(tester, entries);
      await tester.tap(find.byKey(const ValueKey(WeightChartRange.all)));
      await tester.pumpAndSettle();
      await pumpChart(tester, entries, locale: const Locale('tr', 'TR'));
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey(WeightChartRange.all)),
            )
            .selected,
        isTrue,
      );
      final bar = chart.data.lineBarsData.single;
      expect(bar.spots.map((spot) => spot.x), [0, 10]);
      final tooltip = chart.data.lineTouchData.touchTooltipData.getTooltipItems(
        [LineBarSpot(bar, 0, bar.spots.last)],
      ).single!;
      expect(tooltip.text, '4,525 kg\n12 Oca 2020');
      expect(find.text('Bu dönemdeki değişim: +0,425 kg'), findsOneWidget);
      await pumpChart(tester, [
        entries.first,
      ], locale: const Locale('tr', 'TR'));
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots,
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vertical drags on the plot still scroll the measurement page', (
    tester,
  ) async {
    final today = DateTime.now();
    await pumpChart(
      tester,
      [
        measurement('new', today, 4.5),
        measurement(
          'old',
          DateTime(today.year, today.month, today.day - 10),
          4.1,
        ),
      ],
      size: const Size(320, 568),
      scale: 2,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byType(LineChart)),
      alignment: 0.3,
    );
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final before = scroll.pixels;
    final plot = tester.getRect(find.byType(LineChart));
    await tester.dragFrom(
      Offset(plot.right - 40, plot.center.dy),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(scroll.pixels, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en', 'US'), const Locale('tr', 'TR')]) {
    testWidgets('range controls keep one stable row in $locale', (
      tester,
    ) async {
      await pumpChart(
        tester,
        [measurement('today', DateTime.now(), 3)],
        locale: locale,
        size: const Size(320, 568),
      );
      Finder chip(WeightChartRange range) => find.byKey(ValueKey(range));
      final widths = {
        for (final range in WeightChartRange.values)
          range: tester.getSize(chip(range)).width,
      };
      for (final selected in WeightChartRange.values) {
        await tester.tap(chip(selected));
        await tester.pumpAndSettle();
        final top = tester.getTopLeft(chip(WeightChartRange.month)).dy;
        for (final range in WeightChartRange.values) {
          expect(tester.getTopLeft(chip(range)).dy, closeTo(top, 0.1));
          expect(tester.getSize(chip(range)).width, widths[range]);
          expect(chip(range).hitTestable(), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('decimal axis labels stay on one line in $locale at $scale', (
        tester,
      ) async {
        final today = DateTime.now();
        await pumpChart(
          tester,
          [
            measurement('new', today, 2.9),
            measurement(
              'old',
              DateTime(today.year, today.month, today.day - 1),
              2.8,
            ),
          ],
          locale: locale,
          size: const Size(320, 568),
          scale: scale,
        );
        final labels = find.descendant(
          of: find.byType(SideTitleWidget),
          matching: find.byType(Text),
        );
        expect(labels, findsWidgets);
        for (final element in labels.evaluate()) {
          final text = element.widget as Text;
          final paragraph = element.renderObject! as RenderParagraph;
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: text.data!.length),
          );
          expect(
            boxes,
            hasLength(1),
            reason: 'Wrapped axis label: ${text.data}',
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.size.width + 0.01),
          );
        }
        final lowestLabel = labels
            .evaluate()
            .map((element) {
              return tester.getBottomLeft(find.byWidget(element.widget)).dy;
            })
            .reduce((a, b) => a > b ? a : b);
        final dates = MaterialLocalizations.of(
          tester.element(find.byType(WeightHistoryChart)),
        );
        final firstDate = find.text(
          dates.formatShortDate(
            DateTime(today.year, today.month, today.day - 1),
          ),
        );
        expect(
          tester.getTopLeft(firstDate).dy - lowestLabel,
          greaterThanOrEqualTo(AppSpacing.md),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    for (final locale in [const Locale('tr', 'TR'), const Locale('en', 'US')]) {
      for (final size in [const Size(320, 568), const Size(640, 320)]) {
        testWidgets(
          'chart fits $size with large text in $locale / $brightness',
          (tester) async {
            final today = DateTime.now();
            await pumpChart(
              tester,
              [
                measurement('new', today, 0.125),
                measurement(
                  'old',
                  DateTime(today.year, today.month, today.day - 5),
                  0.1,
                ),
              ],
              locale: locale,
              brightness: brightness,
              size: size,
              scale: 2,
            );
            expect(find.byType(LineChart), findsOneWidget);
            await tester.ensureVisible(
              find.byKey(const ValueKey(WeightChartRange.all)),
            );
            await tester.tap(find.byKey(const ValueKey(WeightChartRange.all)));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final rect = tester.getRect(find.byType(LineChart));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
          },
        );
      }
    }
  }
}
