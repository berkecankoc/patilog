import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_view_selector.dart';
import '../../helpers/multi_step_form_helpers.dart';

void main() {
  setUpAll(loadFormTestFont);
  for (final (labels, size, scale) in [
    (['Doses', 'Medications'], const Size(320, 568), 1.0),
    (['Dozlar', 'İlaçlar'], const Size(320, 568), 2.0),
    (['Öğünler', 'Planlar', 'Geçmiş'], const Size(320, 568), 2.0),
    (['Meals', 'Plans', 'History'], const Size(640, 320), 2.0),
  ]) {
    testWidgets(
      'view choices fill the same width and remain usable at $labels $scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: StatefulBuilder(
                  builder: (context, setState) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppViewSelector(
                      labels: labels,
                      selectedIndex: selected,
                      onSelected: (index) => setState(() => selected = index),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final control = find.byType(SegmentedButton<int>);
        expect(tester.getSize(control).width, closeTo(size.width - 48, .1));
        for (final label in labels) {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse,
          );
        }
        await tester.tap(find.text(labels.last));
        await tester.pumpAndSettle();
        expect(selected, labels.length - 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
