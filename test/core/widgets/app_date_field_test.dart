import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';

void main() {
  Future<void> pumpField(
    WidgetTester tester,
    ValueNotifier<DateTime?> value,
  ) async {
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ValueListenableBuilder<DateTime?>(
            valueListenable: value,
            builder: (context, date, _) => AppDateField(
              labelText: 'Birth date',
              value: date,
              clearable: true,
              firstDate: DateTime(1980),
              lastDate: DateTime(2026, 10, 13),
              onChanged: (selected) => value.value = selected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('displays a date and can clear the optional value', (
    tester,
  ) async {
    final value = ValueNotifier<DateTime?>(DateTime(2022, 7, 11));
    await pumpField(tester, value);
    expect(find.text('Jul 11, 2022'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear birth date'));
    await tester.pumpAndSettle();
    expect(value.value, isNull);
    expect(find.text('Jul 11, 2022'), findsNothing);
    expect(find.byTooltip('Choose birth date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection updates the field and cancellation preserves it', (
    tester,
  ) async {
    final value = ValueNotifier<DateTime?>(null);
    await pumpField(tester, value);
    await tester.tap(find.byTooltip('Choose birth date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(value.value, DateTime(2026, 10, 12));
    expect(find.text('Oct 12, 2026'), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(value.value, DateTime(2026, 10, 12));
    expect(tester.takeException(), isNull);
  });
}
