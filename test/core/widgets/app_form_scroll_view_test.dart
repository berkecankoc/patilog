import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/widgets/app_form_scroll_view.dart';

void main() {
  testWidgets(
    'form scroll decoration is disabled without replacing iOS physics',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const Scaffold(
            body: AppFormScrollView(
              child: SizedBox(width: double.infinity, height: 2000),
            ),
          ),
        ),
      );
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.physics, isA<BouncingScrollPhysics>());
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      await tester.drag(find.byType(Scrollable), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
    },
  );
}
