import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/features/notification/presentation/widgets/reminder_schedule_fields.dart';
import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';
import '../../../../helpers/multi_step_form_helpers.dart';

void main() {
  setUpAll(loadFormTestFont);
  final form = GlobalKey<FormState>();
  VaccinationReminderSchedule? changed;
  Future<void> pump(
    WidgetTester tester, {
    VaccinationReminderSchedule? initial,
  }) async {
    changed = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: form,
              child: ReminderScheduleFields(
                initialValue: initial ?? VaccinationReminderSchedule(),
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('selects reminder days by label without comma-separated input', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: ReminderScheduleFields(
              initialValue: VaccinationReminderSchedule(),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FilterChip), findsNWidgets(4));
    expect(find.byKey(const Key('reminder-days')), findsNothing);
    expect(find.text('Vaccination day'), findsOneWidget);
    expect(find.text('Add day'), findsNothing);
    expect(find.text('Choose up to 3 reminder days.'), findsOneWidget);
  });

  testWidgets('a nonempty day selection is required and recovers inline', (
    tester,
  ) async {
    await pump(tester);
    for (final day in [0, 1, 3]) {
      await tester.tap(find.byKey(ValueKey('reminder-day-$day')));
      await tester.pump();
    }
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Select at least one day'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reminder-day-7')));
    await tester.pump();
    expect(form.currentState!.validate(), isTrue);
    expect(changed, VaccinationReminderSchedule(daysBefore: [7]));
    expect(find.text('Select at least one day'), findsNothing);
  });

  testWidgets('at the limit only selected days can be changed', (tester) async {
    await pump(tester);
    final seven = find.byKey(const ValueKey('reminder-day-7'));
    expect(tester.widget<FilterChip>(seven).onSelected, isNull);
    await tester.tap(find.byKey(const ValueKey('reminder-day-3')));
    await tester.pump();
    expect(tester.widget<FilterChip>(seven).onSelected, isNotNull);
    await tester.tap(seven);
    await tester.pump();
    expect(changed, VaccinationReminderSchedule(daysBefore: [7, 1, 0]));
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('reminder-day-3')))
          .onSelected,
      isNull,
    );
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('rapid choices cannot exceed the limit before the next frame', (
    tester,
  ) async {
    await pump(
      tester,
      initial: VaccinationReminderSchedule(daysBefore: [0, 1]),
    );
    final three = tester
        .widget<FilterChip>(find.byKey(const ValueKey('reminder-day-3')))
        .onSelected!;
    final seven = tester
        .widget<FilterChip>(find.byKey(const ValueKey('reminder-day-7')))
        .onSelected!;
    three(true);
    seven(true);
    await tester.pump();
    expect(changed, VaccinationReminderSchedule());
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('reminder-day-7')))
          .selected,
      isFalse,
    );
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets(
    'time input keeps a short visible error and preserves selected days',
    (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('reminder-time')), '9960');
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Use 00:00–23:59'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reminder-time')), '1030');
      expect(form.currentState!.validate(), isTrue);
      expect(changed, VaccinationReminderSchedule(minuteOfDay: 630));
    },
  );
}
