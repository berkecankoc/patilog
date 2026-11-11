import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/router/pet_care_route_extra.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_doses.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_dose_calendar.dart';

import '../../../../helpers/pet_care_test_harness.dart';

void main() {
  late PetCareTestHarness app;
  final past = DateTime(2026, 11, 10);

  setUpAll(() {
    final period = MedicationPeriod(
      id: 'fallback',
      medicationId: 'fallback',
      startDate: past,
      intervalDays: 1,
      doseTimes: [0],
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
        scheduledDate: past,
        scheduledMinute: 0,
        status: MedicationDoseStatus.skipped,
      ),
    );
  });

  setUp(() {
    app = PetCareTestHarness();
    app.register();
    app.clock = DateTime(2026, 11, 15, 12, 15);
  });

  void schedule(int count) {
    app.medications = [
      app.sample(
        periods: [
          MedicationPeriod(
            id: 'period',
            medicationId: 'med',
            startDate: DateTime(2026, 11),
            intervalDays: 1,
            doseTimes: List.generate(count, (i) => i * 5),
          ),
        ],
      ),
    ];
  }

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    Locale locale = const Locale('en', 'US'),
  }) async {
    await app.pump(
      tester,
      location: AppRoutes.medicationDetail('pet', 'med'),
      size: size,
      scale: scale,
      dark: dark,
      locale: locale,
    );
    final button = find.byIcon(Icons.calendar_month_outlined);
    await tester.scrollUntilVisible(button, 400, maxScrolls: 40);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(MedicationDoseCalendar),
      300,
      maxScrolls: 40,
    );
    await tester.pumpAndSettle();
    expect(find.byType(MedicationDoseCalendar), findsOneWidget);
  }

  for (final config in [
    (width: 320.0, scale: 1.0, dark: true, locale: const Locale('en', 'US')),
    (width: 320.0, scale: 1.4, dark: false, locale: const Locale('en', 'US')),
    (width: 320.0, scale: 2.0, dark: true, locale: const Locale('tr', 'TR')),
    (width: 390.0, scale: 1.0, dark: false, locale: const Locale('tr', 'TR')),
  ]) {
    testWidgets('day geometry remains stable with mixed results $config', (
      tester,
    ) async {
      schedule(24);
      for (var i = 0; i < 16; i++) {
        app.logs.add(
          MedicationDoseLog(
            periodId: 'period',
            scheduledDate: past,
            scheduledMinute: i * 5,
            status: i < 8
                ? MedicationDoseStatus.given
                : MedicationDoseStatus.skipped,
            givenAt: i < 8 ? DateTime(2026, 11, 10, 0, i * 5) : null,
          ),
        );
      }
      await open(
        tester,
        size: Size(config.width, 844),
        scale: config.scale,
        dark: config.dark,
        locale: config.locale,
      );
      final mixed = find.byKey(ValueKey(('dose-calendar-day', past)));
      final empty = find.byKey(
        ValueKey(('dose-calendar-day', DateTime(2026, 11, 9))),
      );
      final future = find.byKey(
        ValueKey(('dose-calendar-day', DateTime(2026, 11, 16))),
      );
      expect(
        find.descendant(of: mixed, matching: find.byType(Icon)),
        findsOneWidget,
      );
      expect(tester.getSize(mixed).height, tester.getSize(empty).height);
      expect(tester.getSize(mixed).height, tester.getSize(future).height);
      expect(tester.getSize(mixed).height, greaterThanOrEqualTo(48));
      expect(
        find.descendant(
          of: find.byType(MedicationDoseCalendar),
          matching: find.byType(IntrinsicHeight),
        ),
        findsNothing,
      );
      await Scrollable.ensureVisible(tester.element(mixed), alignment: 0.4);
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      try {
        expect(
          find.bySemanticsLabel(
            RegExp(
              config.locale.languageCode == 'en'
                  ? '8 given, 8 skipped, 8 with no record'
                  : '8 verildi, 8 atlandı, 8 kayıt yok',
            ),
          ),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
      await tester.tap(mixed);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(config.locale.languageCode == 'en' ? '8 given' : '8 verildi'),
        400,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(config.locale.languageCode == 'en' ? '8 given' : '8 verildi'),
        findsOneWidget,
      );
      expect(
        find.text(
          config.locale.languageCode == 'en' ? '8 skipped' : '8 atlandı',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          config.locale.languageCode == 'en'
              ? '8 with no record'
              : '8 kayıt yok',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'unknown month results stay unknown after failure and retry restores counts; future days stay scheduled',
    (tester) async {
      schedule(3);
      await app.pump(
        tester,
        location: AppRoutes.medicationDetail('pet', 'med'),
      );
      final pending = Completer<Result<List<MedicationDoseLog>>>();
      when(
        () => app.repository.getDoseLogs(
          'pet',
          medicationId: 'med',
          fromDate: DateTime(2026, 11),
          toDate: DateTime(2026, 11, 30),
        ),
      ).thenAnswer((_) => pending.future);
      final button = find.byIcon(Icons.calendar_month_outlined);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(
        find.text('Dose records unavailable', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('3 with no record', skipOffstage: false), findsNothing);
      pending.complete(const Error(LocalDatabaseFailure('Unavailable')));
      await tester.pumpAndSettle();
      expect(
        find.text('Dose records unavailable', skipOffstage: false),
        findsOneWidget,
      );
      final log = MedicationDoseLog(
        periodId: 'period',
        scheduledDate: DateUtils.dateOnly(app.clock),
        scheduledMinute: 0,
        status: MedicationDoseStatus.given,
        givenAt: DateTime(2026, 11, 15),
      );
      when(
        () => app.repository.getDoseLogs(
          'pet',
          medicationId: 'med',
          fromDate: DateTime(2026, 11),
          toDate: DateTime(2026, 11, 30),
        ),
      ).thenAnswer((_) async => Success([log]));
      await tester.scrollUntilVisible(
        find.text('Retry calendar'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry calendar'));
      await tester.pumpAndSettle();
      expect(find.text('1 given', skipOffstage: false), findsOneWidget);
      expect(
        find.text('2 with no record', skipOffstage: false),
        findsOneWidget,
      );
      final future = find.byKey(
        ValueKey(('dose-calendar-day', DateTime(2026, 11, 16))),
      );
      await tester.ensureVisible(future);
      await tester.pumpAndSettle();
      await tester.tap(future);
      await tester.pumpAndSettle();
      expect(find.text('3 scheduled', skipOffstage: false), findsOneWidget);
      expect(find.text('3 with no record', skipOffstage: false), findsNothing);
      verifyNever(() => app.repository.saveDoseLog(any(), any(), any()));
    },
  );

  testWidgets(
    'reminder entry reaches the requested calendar even below a long schedule summary',
    (tester) async {
      schedule(120);
      final router = await app.pump(tester);
      unawaited(
        router.push(
          AppRoutes.medicationDetail('pet', 'med'),
          extra: MedicationDetailExtra(
            petId: 'pet',
            medicationId: 'med',
            doseDate: past,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final calendar = tester.widget<MedicationDoseCalendar>(
        find.byType(MedicationDoseCalendar),
      );
      expect(calendar.state.doses.date, past);
      expect(
        tester.getTopLeft(find.byIcon(Icons.calendar_month_outlined)).dy,
        inInclusiveRange(0, 844),
      );
      expect(app.logs, isEmpty);
      verifyNever(() => app.repository.saveDoseLog(any(), any(), any()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long day lists build only visible doses and retain the correct result identity after scrolling',
    (tester) async {
      schedule(120);
      await open(tester);
      final builtDoses = find.descendant(
        of: find.byType(MedicationDoseCalendar, skipOffstage: false),
        matching: find.byType(MedicationDoseTile, skipOffstage: false),
        skipOffstage: false,
      );
      expect(builtDoses.evaluate().length, lessThan(20));
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.scrollUntilVisible(
        find.text('09:55'),
        500,
        scrollable: scrollable,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      expect(find.text('09:55').hitTestable(), findsOneWidget);
      expect(builtDoses.evaluate().length, lessThan(20));
      expect(
        find.byKey(
          ValueKey(('period', DateUtils.dateOnly(app.clock), 0)),
          skipOffstage: false,
        ),
        findsNothing,
      );
      await tester.tap(find.text('09:55'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skipped').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();
      expect(app.logs.single.scheduledMinute, 595);
      expect(app.logs.single.scheduledDate, DateUtils.dateOnly(app.clock));
      expect(app.logs.single.status, MedicationDoseStatus.skipped);
      expect(find.text('Skipped · Edit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
