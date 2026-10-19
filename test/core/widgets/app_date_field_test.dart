import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';

void main() {
  testWidgets(
    'read-only date stays legible and cannot open or clear until unlocked',
    (tester) async {
      final locked = ValueNotifier(true);
      addTearDown(locked.dispose);
      DateTime? selected = DateTime(2020, 1, 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: locked,
              builder: (_, readOnly, _) => AppDateField(
                labelText: 'Date',
                value: selected,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                clearable: true,
                readOnly: readOnly,
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Jan 2, 2020'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(selected, DateTime(2020, 1, 2));
      locked.value = false;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear date'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    },
  );

  testWidgets(
    'an empty future-date field opens on today rather than the upper limit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDateField(
              labelText: 'Next dose',
              value: null,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Choose next dose'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        DateUtils.dateOnly(DateTime.now()),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed bounds clamp picker initial date without changing the stored value on cancel',
    (tester) async {
      DateTime? selected = DateTime(2030, 1, 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDateField(
              labelText: 'Date',
              value: selected,
              firstDate: DateTime(2000),
              lastDate: DateTime(2020),
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Choose date'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        DateTime(2020),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2030, 1, 2));
      expect(tester.takeException(), isNull);
    },
  );

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
