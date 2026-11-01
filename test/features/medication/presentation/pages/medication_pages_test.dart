import '../../../../helpers/pet_care_test_harness.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/widgets/app_form_scroll_view.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_suggestions.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_dose_calendar.dart';

void main() {
  late PetCareTestHarness app;
  setUpAll(() {
    final period = MedicationPeriod(
      id: 'fallback',
      medicationId: 'fallback',
      startDate: DateTime(2026),
      intervalDays: 1,
      doseTimes: [480],
    );
    registerFallbackValue(period);
    registerFallbackValue(
      Medication(
        id: 'fallback',
        petId: 'pet',
        name: 'Fallback',
        periods: [period],
      ),
    );
    registerFallbackValue(
      MedicationDoseLog(
        periodId: 'fallback',
        scheduledDate: DateTime(2026),
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      ),
    );
  });
  setUp(() {
    app = PetCareTestHarness();
    app.register();
  });

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ElevatedButton, label));
    await tester.pumpAndSettle();
  }

  testWidgets('medication suggestions clear the fixed Continue action', (
    tester,
  ) async {
    when(
      () => app.repository.getSuggestions(clinicName: any(named: 'clinicName')),
    ).thenAnswer(
      (_) async => const Success(
        MedicationSuggestions(
          medicationNames: ['Medicine A', 'Medicine B', 'Medicine C'],
          clinicNames: [],
          veterinarianNames: [],
        ),
      ),
    );
    await app.pump(
      tester,
      location: '/pets/pet/medications/form',
      keyboard: 280,
    );
    final name = find.widgetWithText(TextFormField, 'Medication name');
    await tester.enterText(name, 'Med');
    await tester.pumpAndSettle();
    final menu = find
        .ancestor(
          of: find.byType(MenuItemButton).first,
          matching: find.byType(Material),
        )
        .first;
    final actions = find.byKey(const ValueKey('multi-step-form-actions'));
    expect(
      tester.getRect(menu).bottom,
      lessThanOrEqualTo(tester.getRect(actions).top),
    );
    expect(find.text('Continue').hitTestable(), findsOneWidget);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Medicine A'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(name).controller!.text, 'Medicine A');
    verifyNever(() => app.repository.createMedication(any()));
  });

  testWidgets('dosage example is visible only for focused empty input', (
    tester,
  ) async {
    await app.pump(tester, location: AppRoutes.addEditMedication('pet'));
    final dosage = find.widgetWithText(
      TextFormField,
      'Dosage instructions (optional)',
    );
    double hintOpacity() => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.text('e.g. half a tablet'),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;
    expect(hintOpacity(), 0);
    await tester.tap(dosage);
    await tester.pumpAndSettle();
    expect(hintOpacity(), 1);
    await tester.enterText(dosage, 'One tablet');
    await tester.pumpAndSettle();
    expect(hintOpacity(), 0);
    await tester.enterText(dosage, '');
    await tester.tap(find.widgetWithText(TextFormField, 'Medication name'));
    await tester.pumpAndSettle();
    expect(hintOpacity(), 0);
  });

  testWidgets('Android medication form suppresses stretch across all steps', (
    tester,
  ) async {
    await app.pump(tester, location: AppRoutes.addEditMedication('pet'));
    final name = find.widgetWithText(TextFormField, 'Medication name');
    expect(
      find.ancestor(
        of: name,
        matching: find.byType(StretchingOverscrollIndicator),
      ),
      findsNothing,
    );
    await tester.enterText(name, 'Medication');
    await tap(tester, 'Continue');
    final time = find.widgetWithText(TextFormField, 'Dose time');
    expect(
      find.ancestor(
        of: time,
        matching: find.byType(StretchingOverscrollIndicator),
      ),
      findsNothing,
    );
    await tester.enterText(time, '09');
    expect(tester.widget<TextFormField>(time).controller!.text, '09:');
    expect(
      tester.widget<TextFormField>(time).controller!.selection.extentOffset,
      3,
    );
    await tester.enterText(time, '0930');
    expect(tester.widget<TextFormField>(time).controller!.text, '09:30');
    await tap(tester, 'Continue');
    await tester.tap(find.text('Clinic & notes (optional)'));
    await tester.pumpAndSettle();
    final notes = find.widgetWithText(TextFormField, 'Notes (optional)');
    await tester.scrollUntilVisible(
      notes,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.ancestor(
        of: notes,
        matching: find.byType(StretchingOverscrollIndicator),
      ),
      findsNothing,
    );
    await tester.drag(find.byType(AppFormScrollView), const Offset(0, -700));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'Android dose panel suppresses stretch and formats numeric time',
    (tester) async {
      app.medications = [app.sample()];
      await app.pump(tester);
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record dose').first);
      await tester.pumpAndSettle();
      final time = find.widgetWithText(TextFormField, 'Given at');
      expect(
        find.ancestor(
          of: time,
          matching: find.byType(StretchingOverscrollIndicator),
        ),
        findsNothing,
      );
      await tester.enterText(time, '09');
      expect(tester.widget<TextFormField>(time).controller!.text, '09:');
      expect(
        tester.widget<TextFormField>(time).controller!.selection.extentOffset,
        3,
      );
      await tester.enterText(time, '0930');
      expect(tester.widget<TextFormField>(time).controller!.text, '09:30');
      await tap(tester, 'Save');
      expect(app.logs.single.givenAt!.hour, 9);
      expect(app.logs.single.givenAt!.minute, 30);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('empty medication list has one creation action through its FAB', (
    tester,
  ) async {
    await app.pump(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Add medication'), findsNothing);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3 · Medication'), findsOneWidget);
  });

  testWidgets(
    'calendar month heading and Go to today distinguish navigation from selection',
    (tester) async {
      app.medications = [app.sample()];
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      final open = find.widgetWithText(FilledButton, 'Dose calendar');
      await tester.scrollUntilVisible(
        open,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      final next = find.byTooltip('Next month');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      final dates = MaterialLocalizations.of(
        tester.element(find.byType(MedicationDoseCalendar)),
      );
      expect(
        find.text(
          dates.formatMonthYear(DateTime(app.today.year, app.today.month + 1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MedicationDoseCalendar),
          matching: find.text('Today'),
        ),
        findsNothing,
      );
      final go = find.widgetWithText(TextButton, 'Go to today');
      await tester.ensureVisible(go);
      await tester.pumpAndSettle();
      await tester.tap(go);
      await tester.pumpAndSettle();
      expect(find.text(dates.formatMonthYear(app.today)), findsOneWidget);
      expect(tester.widget<TextButton>(go).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'section editing has one Done action; invalid fields cannot return to Review',
    (tester) async {
      app.medications = [app.sample()];
      final router = await app.pump(tester);
      unawaited(
        router.push<bool>(
          AppRoutes.addEditMedication('pet'),
          extra: MedicationFormExtra(
            petId: 'pet',
            medication: app.medications.single,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Back'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        '',
      );
      await tap(tester, 'Done');
      expect(find.text('Enter a medication name.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        'Updated name',
      );
      await tap(tester, 'Done');
      expect(find.text('Step 3 of 3 · Review'), findsOneWidget);
      expect(find.text('Updated name'), findsOneWidget);
      verifyNever(() => app.repository.renameMedication(any(), any(), any()));
    },
  );

  testWidgets('form action surface paints through the bottom safe area', (
    tester,
  ) async {
    await app.pump(
      tester,
      location: AppRoutes.addEditMedication('pet'),
      bottomInset: 34,
    );
    final footer = find.byKey(const ValueKey('multi-step-form-actions'));
    expect(tester.getBottomRight(footer).dy, 844);
    expect(
      tester.getBottomRight(find.widgetWithText(ElevatedButton, 'Continue')).dy,
      lessThanOrEqualTo(810),
    );
  });

  testWidgets(
    'new schedule starts at Schedule and Back preserves its draft before exit',
    (tester) async {
      app.medications = [app.sample()];
      final router = await app.pump(tester);
      unawaited(
        router.push<bool>(
          AppRoutes.addEditMedication('pet'),
          extra: MedicationFormExtra(
            petId: 'pet',
            petName: 'Simba',
            medication: app.medications.single,
            newSchedule: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppMultiStepForm), findsOneWidget);
      expect(find.text('Step 2 of 3 · Schedule'), findsOneWidget);
      final time = find.widgetWithText(TextFormField, '08:00');
      await tester.ensureVisible(time);
      await tester.enterText(time, '0930');
      await tap(tester, 'Continue');
      expect(find.text('Step 3 of 3 · Review'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3 · Schedule'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '09:30'), findsOneWidget);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
      await tester.pumpAndSettle();
      await tap(tester, 'Continue');
      await tap(tester, 'Schedule doses');
      expect(app.medications.single.periods.length, 2);
      expect(app.medications.single.periods.last.doseTimes, [570, 1200]);
      verify(
        () => app.repository.createPeriod(
          'pet',
          any(),
          medicationName: 'Medication A',
        ),
      ).called(1);
    },
  );

  testWidgets(
    'dose history failure keeps the edited draft and retry unlocks saving',
    (tester) async {
      final pending = Completer<Result<bool>>();
      when(
        () => app.repository.hasDoseLogs('pet', 'med', 'period'),
      ).thenAnswer((_) => pending.future);
      app.medications = [app.sample()];
      final router = await app.pump(tester);
      unawaited(
        router.push<bool>(
          AppRoutes.addEditMedication('pet'),
          extra: MedicationFormExtra(
            petId: 'pet',
            medication: app.medications.single,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        'Draft name',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Save changes'),
            )
            .onPressed,
        isNull,
      );
      pending.complete(
        const Error(LocalDatabaseFailure('History unavailable')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Failed to check dose history').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Draft name'), findsOneWidget);
      when(
        () => app.repository.hasDoseLogs('pet', 'med', 'period'),
      ).thenAnswer((_) async => const Success(false));
      await tester.tap(find.text('Retry dose history'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to check dose history'), findsNothing);
      expect(find.text('Draft name'), findsOneWidget);
      await tap(tester, 'Save changes');
      expect(app.medications.single.name, 'Draft name');
      expect(app.medications.single.periods.length, 1);
    },
  );

  testWidgets(
    'dose calendar stays in detail and opens mixed day records without a list round trip',
    (tester) async {
      app.medications = [app.sample()];
      final past = DateTime(app.today.year, app.today.month, app.today.day - 1);
      app.logs.addAll([
        MedicationDoseLog(
          periodId: 'period',
          scheduledDate: past,
          scheduledMinute: 480,
          status: MedicationDoseStatus.given,
          givenAt: DateTime(past.year, past.month, past.day, 8, 5),
        ),
        MedicationDoseLog(
          periodId: 'period',
          scheduledDate: past,
          scheduledMinute: 1200,
          status: MedicationDoseStatus.skipped,
        ),
      ]);
      final router = await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      final button = find.widgetWithText(FilledButton, 'Dose calendar');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(MedicationDoseCalendar), findsOneWidget);
      final day = find.byKey(ValueKey(('dose-calendar-day', past)));
      await Scrollable.ensureVisible(tester.element(day), alignment: 0.4);
      await tester.pumpAndSettle();
      await tester.tap(day);
      await tester.pumpAndSettle();
      final given = find.text('Given at 08:05 · Edit');
      await tester.ensureVisible(given);
      await tester.pumpAndSettle();
      expect(given, findsOneWidget);
      expect(find.text('Skipped · Edit'), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.medicationDetail('pet', 'med'));
      verify(
        () => app.repository.getDoseLogs(
          'pet',
          medicationId: 'med',
          fromDate: DateTime(app.today.year, app.today.month),
          toDate: DateTime(app.today.year, app.today.month + 1, 0),
        ),
      ).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create validates steps and saves once from Review, preserving blank optional fields',
    (tester) async {
      await app.pump(tester, location: AppRoutes.addEditMedication('pet'));
      await tap(tester, 'Continue');
      expect(find.text('Enter a medication name.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        'New medication',
      );
      await tap(tester, 'Continue');
      expect(find.text('Step 2 of 3 · Schedule'), findsOneWidget);
      await tap(tester, 'Continue');
      expect(find.text('Step 3 of 3 · Review'), findsOneWidget);
      verifyNever(() => app.repository.createMedication(any()));
      await tap(tester, 'Add medication');
      expect(app.medications.single.name, 'New medication');
      expect(app.medications.single.periods.single.notes, '');
      verify(() => app.repository.createMedication(any())).called(1);
      expect(find.text('Step 3 of 3 · Review'), findsNothing);
    },
  );

  testWidgets(
    'failed and pending creation keeps Review/draft and blocks duplicate save and Back',
    (tester) async {
      await app.pump(tester, location: AppRoutes.addEditMedication('pet'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        'Draft medication',
      );
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      app.pendingCreate = Completer();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add medication'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Step 3 of 3 · Review'), findsOneWidget);
      verify(() => app.repository.createMedication(any())).called(1);
      app.pendingCreate!.complete(
        const Error(LocalDatabaseFailure('Save failed')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Draft medication'), findsOneWidget);
      expect(find.text('Failed to save medication'), findsOneWidget);
      expect(find.text('Retry saving'), findsNothing);
      app.pendingCreate = null;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add medication'));
      await tester.pumpAndSettle();
      expect(app.medications.single.name, 'Draft medication');
    },
  );

  testWidgets(
    'edit opens Review; logged schedule changes create one future plan and retain old logs',
    (tester) async {
      app.medications = [app.sample()];
      final oldLog = MedicationDoseLog(
        periodId: 'period',
        scheduledDate: app.today,
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      );
      app.logs.add(oldLog);
      final router = await app.pump(tester);
      unawaited(
        router.push<bool>(
          AppRoutes.addEditMedication('pet'),
          extra: MedicationFormExtra(
            petId: 'pet',
            petName: 'Simba',
            medication: app.medications.single,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 3 · Review'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Save changes'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Edit').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextFormField, '08:00'));
      await tester.enterText(
        find.widgetWithText(TextFormField, '08:00'),
        '09:00',
      );
      await tap(tester, 'Done');
      expect(find.textContaining('Changes from'), findsOneWidget);
      await tap(tester, 'Save changes');
      expect(app.medications.single.periods.length, 2);
      expect(app.medications.single.periods.first.doseTimes, [480, 1200]);
      expect(app.logs, [oldLog]);
      expect(
        app.medications.single.periods.last.startDate,
        DateTime(app.today.year, app.today.month, app.today.day + 1),
      );
    },
  );

  testWidgets(
    'Given saves now once; edit uses a fixed day and clear needs confirmation',
    (tester) async {
      app.medications = [app.sample()];
      await app.pump(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Given').first);
      await tester.pumpAndSettle();
      expect(app.logs.single.givenAt, app.clock);
      expect(find.text('Given at 12:15 · Edit'), findsOneWidget);
      await tester.tap(find.text('Given at 12:15 · Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Given at'), findsOneWidget);
      await tester.tap(find.text('Clear record'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(app.logs.length, 1);
      await tester.tap(find.text('Clear record'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear record'));
      await tester.pumpAndSettle();
      expect(app.logs, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'future days are read-only and past selection survives resume refresh',
    (tester) async {
      app.medications = [app.sample()];
      await app.pump(tester);
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      expect(find.text('Scheduled'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Given'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Scheduled'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(find.text('No record'), findsNWidgets(2));
      await tester.tap(find.text('Record dose').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '23:59');
      await tap(tester, 'Save');
      expect(
        app.logs.single.scheduledDate,
        DateTime(app.today.year, app.today.month, app.today.day - 1),
      );
      expect(app.logs.single.givenAt!.hour, 23);
    },
  );

  testWidgets(
    'detail deletion failure retains content; retry asks again and removes known ID',
    (tester) async {
      app.medications = [app.sample()];
      app.failDelete = true;
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      await tester.tap(find.byTooltip('Delete medication'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Medication A'), findsOneWidget);
      expect(find.text('Failed to delete medication'), findsOneWidget);
      app.failDelete = false;
      await tester.tap(find.text('Retry action'));
      await tester.pumpAndSettle();
      expect(find.text('Delete medication?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(app.medications, isEmpty);
      expect(find.text('No medications yet'), findsOneWidget);
    },
  );

  testWidgets(
    'final validation catches a required field cleared then left using Back',
    (tester) async {
      app.medications = [app.sample()];
      final router = await app.pump(tester);
      unawaited(
        router.push<bool>(
          AppRoutes.addEditMedication('pet'),
          extra: MedicationFormExtra(
            petId: 'pet',
            medication: app.medications.single,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication A'),
        '',
      );
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      await tap(tester, 'Save changes');
      expect(find.text('Enter a medication name.'), findsOneWidget);
      verifyNever(
        () => app.repository.updatePeriod(
          any(),
          any(),
          medicationName: any(named: 'medicationName'),
        ),
      );
    },
  );

  testWidgets(
    'failed save recovery returns to Review before persisting edited input',
    (tester) async {
      app.failCreate = true;
      await app.pump(tester, location: AppRoutes.addEditMedication('pet'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        'Original',
      );
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      await tap(tester, 'Add medication');
      await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Original'),
        'Corrected',
      );
      app.failCreate = false;
      await tester.tap(find.text('Review changes'));
      await tester.pumpAndSettle();
      expect(app.medications, isEmpty);
      expect(find.text('Step 3 of 3 · Review'), findsOneWidget);
      await tap(tester, 'Add medication');
      expect(app.medications.single.name, 'Corrected');
    },
  );

  testWidgets(
    'Given failure can retry the intended write; unchanged dose edit does not resubmit',
    (tester) async {
      app.medications = [app.sample()];
      app.failDose = true;
      await app.pump(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Given').first);
      await tester.pumpAndSettle();
      expect(app.logs, isEmpty);
      expect(find.text('Failed to save dose record'), findsOneWidget);
      app.failDose = false;
      await tester.tap(find.text('Retry action'));
      await tester.pumpAndSettle();
      expect(app.logs.single.givenAt, app.clock);
      await tester.tap(find.text('Given at 12:15 · Edit'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Save changes'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField), '23:59');
      await tester.pump();
      await tap(tester, 'Save changes');
      expect(find.text('Given time cannot be in the future.'), findsOneWidget);
      expect(app.logs.single.givenAt, app.clock);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      verify(() => app.repository.saveDoseLog(any(), any(), any())).called(2);
    },
  );

  testWidgets(
    'pending schedule editing updates the same record and cancellation preserves old usage',
    (tester) async {
      final pending = MedicationPeriod(
        id: 'future',
        medicationId: 'med',
        startDate: DateTime(app.today.year, app.today.month, app.today.day + 1),
        intervalDays: 1,
        doseTimes: [600],
      );
      final medication = app.sample();
      app.medications = [
        app.sample(periods: [...medication.periods, pending]),
      ];
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit medication'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Editing scheduled changes from'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication A'),
        'Renamed',
      );
      await tap(tester, 'Done');
      await tap(tester, 'Save changes');
      expect(app.medications.single.periods.length, 2);
      expect(app.medications.single.periods.last.id, 'future');
      final change = find.byKey(
        const PageStorageKey(('medication-change', 'med', 'future')),
      );
      await tester.ensureVisible(change);
      await tester.pumpAndSettle();
      await tester.tap(change);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel change'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(app.medications.single.periods.length, 2);
      await tester.tap(find.text('Cancel change'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel changes'));
      await tester.pumpAndSettle();
      expect(app.medications.single.periods, medication.periods);
    },
  );

  testWidgets(
    'one Schedule card contains a compact change and shows single-day dates once',
    (tester) async {
      final tomorrow = DateTime(
        app.today.year,
        app.today.month,
        app.today.day + 1,
      );
      final current = MedicationPeriod(
        id: 'period',
        medicationId: 'med',
        startDate: app.today,
        intervalDays: 1,
        doseTimes: [480],
      );
      final pending = MedicationPeriod(
        id: 'future',
        medicationId: 'med',
        startDate: tomorrow,
        endDate: tomorrow,
        intervalDays: 1,
        doseTimes: [540],
        dosageInstructions: 'Half a tablet',
      );
      app.medications = [
        app.sample(periods: [current, pending]),
      ];
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      final card = find.byKey(const ValueKey(('medication-schedule', 'med')));
      expect(
        find.descendant(of: card, matching: find.byType(Card)),
        findsNothing,
      );
      final dates = MaterialLocalizations.of(tester.element(card));
      expect(find.text(dates.formatShortDate(app.today)), findsOneWidget);
      expect(
        find.text('From ${dates.formatShortDate(tomorrow)}: Daily · 09:00'),
        findsOneWidget,
      );
      expect(find.text('Half a tablet'), findsNothing);
      expect(find.text('Cancel change'), findsNothing);
      final change = find.byKey(
        const PageStorageKey(('medication-change', 'med', 'future')),
      );
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(find.text('Half a tablet'), findsOneWidget);
      expect(find.text('One day'), findsOneWidget);
      expect(find.text('Edit change'), findsOneWidget);
    },
  );

  testWidgets(
    'editing a later compact change targets its own record and retains the earlier plan',
    (tester) async {
      final current = app.sample().periods.single;
      final first = MedicationPeriod(
        id: 'first',
        medicationId: 'med',
        startDate: DateTime(app.today.year, app.today.month, app.today.day + 1),
        intervalDays: 1,
        doseTimes: [600],
      );
      final second = MedicationPeriod(
        id: 'second',
        medicationId: 'med',
        startDate: DateTime(app.today.year, app.today.month, app.today.day + 3),
        intervalDays: 1,
        doseTimes: [660],
      );
      app.medications = [
        app.sample(periods: [current, first, second]),
      ];
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      final change = find.byKey(
        const PageStorageKey(('medication-change', 'med', 'second')),
      );
      await tester.ensureVisible(change);
      await tester.pumpAndSettle();
      await tester.tap(change);
      await tester.pumpAndSettle();
      final edit = find.widgetWithText(TextButton, 'Edit change');
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Edit').last);
      await tester.pumpAndSettle();
      final time = find.widgetWithText(TextFormField, '11:00');
      await tester.ensureVisible(time);
      await tester.enterText(time, '1130');
      await tap(tester, 'Done');
      await tap(tester, 'Save changes');
      expect(app.medications.single.periods.take(2), [current, first]);
      expect(app.medications.single.periods.last.id, 'second');
      expect(app.medications.single.periods.last.doseTimes, [690]);
      verifyNever(
        () => app.repository.createPeriod(
          any(),
          any(),
          medicationName: any(named: 'medicationName'),
        ),
      );
    },
  );

  testWidgets(
    'a due change becomes the main schedule and keeps previous dose history',
    (tester) async {
      final current = app.sample().periods.single;
      final tomorrow = DateTime(
        app.today.year,
        app.today.month,
        app.today.day + 1,
      );
      final pending = MedicationPeriod(
        id: 'future',
        medicationId: 'med',
        startDate: tomorrow,
        intervalDays: 1,
        doseTimes: [540],
        dosageInstructions: 'New instructions',
      );
      final log = MedicationDoseLog(
        periodId: current.id,
        scheduledDate: app.today,
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      );
      app.medications = [
        app.sample(periods: [current, pending]),
      ];
      app.logs.add(log);
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      expect(find.text('New instructions'), findsNothing);
      app.clock = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey(('medication-schedule', 'med')));
      expect(
        find.descendant(of: card, matching: find.text('Daily · 09:00')),
        findsOneWidget,
      );
      expect(find.text('New instructions'), findsOneWidget);
      expect(
        find.byKey(
          const PageStorageKey(('medication-change', 'med', 'future')),
        ),
        findsNothing,
      );
      expect(find.text('Previous schedules'), findsOneWidget);
      expect(app.logs, [log]);
      expect(app.medications.single.periods, [current, pending]);
    },
  );

  testWidgets(
    'an initial upcoming plan has no unavailable cancellation action',
    (tester) async {
      final pending = MedicationPeriod(
        id: 'future',
        medicationId: 'med',
        startDate: DateTime(app.today.year, app.today.month, app.today.day + 1),
        intervalDays: 1,
        doseTimes: [540],
      );
      app.medications = [
        app.sample(periods: [pending]),
      ];
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      await tester.tap(
        find.byKey(
          const PageStorageKey(('medication-change', 'med', 'future')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit change'), findsOneWidget);
      expect(find.text('Cancel change'), findsNothing);
    },
  );

  testWidgets('medication and visit links open scoped reciprocal summaries', (
    tester,
  ) async {
    final source = app.sample().periods.single;
    app.medications = [
      app.sample(
        periods: [
          MedicationPeriod(
            id: source.id,
            medicationId: source.medicationId,
            startDate: source.startDate,
            intervalDays: 1,
            doseTimes: source.doseTimes,
            vetVisitId: 'visit',
            clinicName: 'Clinic A',
          ),
        ],
      ),
    ];
    await app.pump(tester, location: AppRoutes.medicationDetail('pet', 'med'));
    await tester.ensureVisible(find.text('Linked vet visit'));
    await tester.tap(find.text('Linked vet visit'));
    await tester.pumpAndSettle();
    expect(find.text('Check-up'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Open vet visit'));
    await tester.tap(find.byTooltip('Open vet visit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Linked medications'));
    await tester.tap(find.text('Linked medications'));
    await tester.pumpAndSettle();
    expect(find.text('Medication A'), findsOneWidget);
    verify(
      () => app.repository.getMedications('pet', vetVisitId: 'visit'),
    ).called(1);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'expanded compact schedule actions fit short large-text screens $dark',
      (tester) async {
        final current = app.sample().periods.single;
        final pending = MedicationPeriod(
          id: 'future',
          medicationId: 'med',
          startDate: DateTime(
            app.today.year,
            app.today.month,
            app.today.day + 1,
          ),
          intervalDays: 2,
          doseTimes: [540, 720, 1080],
          dosageInstructions: 'Half a tablet with food',
        );
        app.medications = [
          app.sample(periods: [current, pending]),
        ];
        await app.pump(
          tester,
          location: AppRoutes.medicationDetail('pet', 'med'),
          size: const Size(320, 568),
          scale: 2,
          dark: dark,
        );
        final change = find.byKey(
          const PageStorageKey(('medication-change', 'med', 'future')),
        );
        await tester.ensureVisible(change);
        await tester.pumpAndSettle();
        await tester.tap(change);
        await tester.pumpAndSettle();
        final cancel = find.widgetWithText(TextButton, 'Cancel change');
        await tester.scrollUntilVisible(
          cancel,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(find.text('Cancel scheduled changes?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'calendar remains usable with large text on a short screen $dark',
      (tester) async {
        app.medications = [app.sample()];
        await app.pump(
          tester,
          location: AppRoutes.medicationDetail('pet', 'med'),
          size: const Size(320, 568),
          scale: 2,
          dark: dark,
        );
        final open = find.widgetWithText(FilledButton, 'Dose calendar');
        await tester.scrollUntilVisible(
          open,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(open);
        await tester.pumpAndSettle();
        final next = find.byTooltip('Next month');
        await tester.scrollUntilVisible(
          next,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(
          find.text(
            MaterialLocalizations.of(
              tester.element(find.byType(MedicationDoseCalendar)),
            ).formatMonthYear(DateTime(app.today.year, app.today.month + 1)),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'form actions and dose panel clear simulated keyboard in $dark theme',
      (tester) async {
        app.medications = [app.sample()];
        app.logs.add(
          MedicationDoseLog(
            periodId: 'period',
            scheduledDate: app.today,
            scheduledMinute: 480,
            status: MedicationDoseStatus.skipped,
          ),
        );
        final router = await app.pump(
          tester,
          size: const Size(320, 568),
          scale: 2,
          dark: dark,
          keyboard: 240,
        );
        await tester.scrollUntilVisible(
          find.text('Skipped · Edit'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skipped · Edit'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Given').last);
        await tester.tap(find.text('Given').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Save changes'),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getBottomRight(
                find.widgetWithText(ElevatedButton, 'Save changes'),
              )
              .dy,
          lessThanOrEqualTo(328),
        );
        await tester.ensureVisible(find.byTooltip('Close'));
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Discard changes'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();
        unawaited(
          router.push<bool>(
            AppRoutes.addEditMedication('pet'),
            extra: const MedicationFormExtra(petId: 'pet', petName: 'Simba'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getBottomRight(find.widgetWithText(ElevatedButton, 'Continue'))
              .dy,
          lessThanOrEqualTo(328),
        );
        expect(tester.takeException(), isNull);
      },
    );
    for (final location in [
      '/pets/pet/medications',
      '/pets/pet/medications/med',
      '/pets/pet/medications/form',
    ]) {
      testWidgets('narrow short large-text layout $dark $location', (
        tester,
      ) async {
        app.medications = [app.sample()];
        await app.pump(
          tester,
          location: location,
          size: const Size(320, 568),
          scale: 2,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        if (location.endsWith('form')) {
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Medication name'),
            'Name',
          );
          await tap(tester, 'Continue');
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
