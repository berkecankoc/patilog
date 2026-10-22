import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';

class MockMedicationRepository extends Mock implements MedicationRepository {}

void main() {
  late MockMedicationRepository repository;
  late MedicationCubit cubit;
  late DateTime clock;
  final today = DateTime(2026, 10, 20);
  final tomorrow = DateTime(2026, 10, 21);
  final past = DateTime(2026, 10, 19);
  const failure = LocalDatabaseFailure('Try again');
  final period = MedicationPeriod(
    id: 'period',
    medicationId: 'med',
    startDate: past,
    intervalDays: 1,
    doseTimes: [480, 1200],
  );
  final medication = Medication(
    id: 'med',
    petId: 'pet',
    name: 'Medicine',
    periods: [period],
  );
  MedicationsLoaded loaded() => cubit.state as MedicationsLoaded;

  void stubLogs(
    DateTime date, {
    String? medicationId,
    List<MedicationDoseLog> logs = const [],
  }) {
    when(
      () => repository.getDoseLogs(
        'pet',
        medicationId: medicationId,
        fromDate: date,
        toDate: date,
      ),
    ).thenAnswer((_) async => Success(logs));
  }

  setUpAll(() {
    registerFallbackValue(today);
    registerFallbackValue(
      MedicationDoseLog(
        periodId: 'period',
        scheduledDate: today,
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      ),
    );
  });
  setUp(() {
    repository = MockMedicationRepository();
    clock = DateTime(2026, 10, 20, 10);
    cubit = MedicationCubit(
      repository,
      const CalculateMedicationDoses(),
      now: () => clock,
    );
    when(
      () => repository.getMedications('pet'),
    ).thenAnswer((_) async => Success([medication]));
    when(
      () => repository.getMedicationById('pet', 'med'),
    ).thenAnswer((_) async => Success(medication));
    stubLogs(today);
    stubLogs(today, medicationId: 'med');
  });
  tearDown(() => cubit.close());

  group('dose calendar', () {
    final month = DateTime(2026, 10);
    final end = DateTime(2026, 10, 31);
    void stubMonth(Future<Result<List<MedicationDoseLog>>> Function() answer) {
      when(
        () => repository.getDoseLogs(
          'pet',
          medicationId: 'med',
          fromDate: month,
          toDate: end,
        ),
      ).thenAnswer((_) => answer());
    }

    test(
      'reads one bounded month; day selection retains mixed outcomes without another read',
      () async {
        final log = MedicationDoseLog(
          periodId: 'period',
          scheduledDate: past,
          scheduledMinute: 480,
          status: MedicationDoseStatus.skipped,
        );
        stubMonth(() async => Success([log]));
        await cubit.loadMedication('pet', 'med');
        await cubit.loadCalendar(month);
        cubit.selectCalendarDay(past);
        expect(loaded().doses.doses.first.log, log);
        expect(loaded().doses.doses.last.log, isNull);
        expect(loaded().doses.hasLoaded, true);
        cubit.selectCalendarDay(tomorrow);
        expect(loaded().doses.date, tomorrow);
        expect(loaded().doses.hasLoaded, true);
        verify(
          () => repository.getDoseLogs(
            'pet',
            medicationId: 'med',
            fromDate: month,
            toDate: end,
          ),
        ).called(1);
        verifyNever(
          () => repository.getDoseLogs(
            'pet',
            medicationId: 'med',
            fromDate: past,
            toDate: past,
          ),
        );
      },
    );

    test(
      'unknown results remain unknown on failure; Retry and writes update both day and month',
      () async {
        stubMonth(() async => const Error(failure));
        await cubit.loadMedication('pet', 'med');
        await cubit.loadCalendar(month);
        expect(loaded().calendar!.hasLoaded, false);
        expect(loaded().calendar!.error, failure.message);
        expect(loaded().doses.hasLoaded, false);
        stubMonth(() async => const Success([]));
        await cubit.loadCalendar(month);
        cubit.selectCalendarDay(today);
        when(
          () => repository.saveDoseLog('pet', 'med', any()),
        ).thenAnswer((_) async => const Success(null));
        await cubit.saveDose(
          loaded().doses.doses.first,
          MedicationDoseStatus.skipped,
        );
        expect(
          loaded().calendar!.doses
              .where((dose) => dose.log != null)
              .single
              .log!
              .status,
          MedicationDoseStatus.skipped,
        );
        when(
          () => repository.clearDoseLog(
            'pet',
            'med',
            periodId: 'period',
            scheduledDate: today,
            scheduledMinute: 480,
          ),
        ).thenAnswer((_) async => const Success(null));
        await cubit.performAction(
          ClearMedicationDoseAction('med', loaded().doses.doses.first.log!),
        );
        expect(
          loaded().calendar!.doses.every((dose) => dose.log == null),
          true,
        );
      },
    );

    test(
      'old month results and completion after close cannot replace current state',
      () async {
        final response = Completer<Result<List<MedicationDoseLog>>>();
        stubMonth(() => response.future);
        when(
          () => repository.getDoseLogs(
            'pet',
            medicationId: 'med',
            fromDate: DateTime(2026, 11),
            toDate: DateTime(2026, 11, 30),
          ),
        ).thenAnswer((_) async => const Success([]));
        await cubit.loadMedication('pet', 'med');
        final old = cubit.loadCalendar(month);
        await cubit.loadCalendar(DateTime(2026, 11));
        response.complete(const Error(failure));
        await old;
        expect(loaded().calendar!.month, DateTime(2026, 11));
        expect(loaded().calendar!.error, isNull);
        final closingResponse = Completer<Result<List<MedicationDoseLog>>>();
        stubMonth(() => closingResponse.future);
        final closing = cubit.loadCalendar(month);
        await cubit.close();
        final before = cubit.state;
        closingResponse.complete(const Success([]));
        await closing;
        expect(cubit.state, before);
      },
    );

    test(
      'resume across a month boundary follows today and reloads its month',
      () async {
        clock = DateTime(2026, 10, 31, 23, 59);
        stubLogs(DateTime(2026, 10, 31), medicationId: 'med');
        stubMonth(() async => const Success([]));
        when(
          () => repository.getDoseLogs(
            'pet',
            medicationId: 'med',
            fromDate: DateTime(2026, 11),
            toDate: DateTime(2026, 11, 30),
          ),
        ).thenAnswer((_) async => const Success([]));
        await cubit.loadMedication('pet', 'med');
        await cubit.loadCalendar(month);
        clock = DateTime(2026, 11, 1, 0, 1);
        await cubit.loadMedication('pet', 'med');
        expect(loaded().calendar!.month, DateTime(2026, 11));
        expect(loaded().doses.date, DateTime(2026, 11, 1));
        expect(loaded().doses.followsToday, true);
      },
    );
  });

  blocTest<MedicationCubit, MedicationState>(
    'initial load separates records from the dose section and calculates the day',
    build: () => cubit,
    act: (cubit) => cubit.loadMedications('pet'),
    expect: () => [
      const MedicationLoading(),
      isA<MedicationsLoaded>()
          .having((s) => s.medications, 'records', [medication])
          .having((s) => s.doses.hasLoaded, 'not yet read', false),
      isA<MedicationsLoaded>().having(
        (s) => s.doses.isLoading,
        'loading doses',
        true,
      ),
      isA<MedicationsLoaded>()
          .having(
            (s) => s.doses.doses.map((d) => d.scheduledMinute).toList(),
            'times',
            [480, 1200],
          )
          .having((s) => s.doses.hasLoaded, 'loaded', true)
          .having(
            (s) => s.doses.doses.every((d) => d.log == null),
            'no inferred skipped',
            true,
          ),
    ],
  );

  blocTest<MedicationCubit, MedicationState>(
    'initial record failure produces an error without requesting doses',
    build: () {
      when(
        () => repository.getMedications('pet'),
      ).thenAnswer((_) async => const Error(failure));
      return cubit;
    },
    act: (cubit) => cubit.loadMedications('pet'),
    expect: () => [
      const MedicationLoading(),
      const MedicationError('Try again'),
    ],
    verify: (_) => verifyNever(
      () => repository.getDoseLogs(
        any(),
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ),
  );

  test(
    'empty overview is loaded and dose failure is independently recoverable',
    () async {
      when(
        () => repository.getMedications('pet'),
      ).thenAnswer((_) async => const Success([]));
      when(
        () => repository.getDoseLogs('pet', fromDate: today, toDate: today),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.loadMedications('pet');
      expect(loaded().medications, isEmpty);
      expect(loaded().doses.error, 'Try again');
      expect(loaded().doses.hasLoaded, false);
      stubLogs(today);
      await cubit.loadDoses(today);
      expect(loaded().doses.error, isNull);
      expect(loaded().doses.hasLoaded, true);
    },
  );

  test(
    'refresh failure preserves records and dose results; missing detail removes stale actions',
    () async {
      await cubit.loadMedication('pet', 'med');
      final before = loaded();
      when(
        () => repository.getMedicationById('pet', 'med'),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.loadMedication('pet', 'med');
      expect(loaded().medications, before.medications);
      expect(loaded().doses, before.doses);
      expect(loaded().isRefreshing, false);
      expect(loaded().refreshError, 'Try again');
      when(
        () => repository.getMedicationById('pet', 'med'),
      ).thenAnswer((_) async => const Error(NotFoundFailure('Missing')));
      await cubit.loadMedication('pet', 'med');
      expect(cubit.state, const MedicationError('Missing'));
    },
  );

  test(
    'same-day refresh retains dose content while its new query is pending or fails',
    () async {
      await cubit.loadMedications('pet');
      final before = loaded().doses.doses;
      final response = Completer<Result<List<MedicationDoseLog>>>();
      when(
        () => repository.getDoseLogs('pet', fromDate: today, toDate: today),
      ).thenAnswer((_) => response.future);
      final refresh = cubit.loadMedications('pet');
      await Future<void>.delayed(Duration.zero);
      expect(loaded().doses.doses, before);
      expect(loaded().doses.isLoading, true);
      response.complete(const Error(failure));
      await refresh;
      expect(loaded().doses.doses, before);
      expect(loaded().doses.error, 'Try again');
    },
  );

  test('visit summaries keep full periods and do not read dose logs', () async {
    when(
      () => repository.getMedications('pet', vetVisitId: 'visit'),
    ).thenAnswer((_) async => Success([medication]));
    await cubit.loadMedications('pet', vetVisitId: 'visit');
    expect(loaded().medications, [medication]);
    expect(loaded().vetVisitId, 'visit');
    await cubit.loadDoses(today);
    verifyNever(
      () => repository.getDoseLogs(
        any(),
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    );
  });

  test(
    'old pet and old selected-day reads cannot overwrite the current scope',
    () async {
      final old = Completer<Result<List<Medication>>>();
      when(
        () => repository.getMedications('old'),
      ).thenAnswer((_) => old.future);
      final oldLoad = cubit.loadMedications('old');
      await cubit.loadMedication('pet', 'med');
      old.complete(const Success([]));
      await oldLoad;
      expect(loaded().petId, 'pet');
      final oldDay = Completer<Result<List<MedicationDoseLog>>>();
      when(
        () => repository.getDoseLogs(
          'pet',
          medicationId: 'med',
          fromDate: past,
          toDate: past,
        ),
      ).thenAnswer((_) => oldDay.future);
      final read = cubit.loadDoses(past);
      stubLogs(tomorrow, medicationId: 'med');
      await cubit.loadDoses(tomorrow);
      oldDay.complete(const Error(failure));
      await read;
      expect(loaded().doses.date, tomorrow);
      expect(loaded().doses.error, isNull);
    },
  );

  test(
    'dose failure retains exact intent; retry preserves given time and updates locally',
    () async {
      await cubit.loadMedications('pet');
      when(
        () => repository.saveDoseLog('pet', 'med', any()),
      ).thenAnswer((_) async => const Error(failure));
      final before = loaded().doses.doses;
      await cubit.saveDose(before.first, MedicationDoseStatus.given);
      expect(loaded().doses.doses, before);
      final action = loaded().failedAction as SaveMedicationDoseAction;
      expect(action.log.givenAt, clock);
      expect(loaded().actionError, 'Try again');
      clock = clock.add(const Duration(minutes: 10));
      when(
        () => repository.saveDoseLog('pet', 'med', action.log),
      ).thenAnswer((_) async => const Success(null));
      await cubit.performAction(action);
      expect(loaded().doses.doses.first.log, action.log);
      expect(loaded().actionError, isNull);
      expect(loaded().failedAction, isNull);
      verify(() => repository.getMedications('pet')).called(1);
      verify(
        () => repository.getDoseLogs('pet', fromDate: today, toDate: today),
      ).called(1);
    },
  );

  test(
    'Given can be corrected to Skipped, then cleared to no record',
    () async {
      await cubit.loadMedication('pet', 'med');
      when(
        () => repository.saveDoseLog('pet', 'med', any()),
      ).thenAnswer((_) async => const Success(null));
      await cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.given,
        givenAt: clock.subtract(const Duration(minutes: 30)),
      );
      await cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.skipped,
      );
      final log = loaded().doses.doses.first.log!;
      expect(log.status, MedicationDoseStatus.skipped);
      expect(log.givenAt, isNull);
      when(
        () => repository.clearDoseLog(
          'pet',
          'med',
          periodId: 'period',
          scheduledDate: today,
          scheduledMinute: 480,
        ),
      ).thenAnswer((_) async => const Error(failure));
      final action = ClearMedicationDoseAction('med', log);
      await cubit.performAction(action);
      expect(loaded().failedAction, action);
      expect(loaded().doses.doses.first.log, log);
      when(
        () => repository.clearDoseLog(
          'pet',
          'med',
          periodId: 'period',
          scheduledDate: today,
          scheduledMinute: 480,
        ),
      ).thenAnswer((_) async => const Success(null));
      await cubit.performAction(action);
      expect(loaded().doses.doses.first.log, isNull);
    },
  );

  test(
    'pending write blocks duplicate writes, reads, date changes and local removals',
    () async {
      await cubit.loadMedications('pet');
      final response = Completer<Result<void>>();
      when(
        () => repository.deleteMedication('pet', 'med'),
      ).thenAnswer((_) => response.future);
      final write = cubit.performAction(const DeleteMedicationAction('med'));
      await cubit.performAction(const DeleteMedicationAction('med'));
      await cubit.loadMedication('pet', 'med');
      await cubit.loadDoses(past);
      cubit.removeDeletedMedication('med');
      expect(loaded().pendingAction, const DeleteMedicationAction('med'));
      response.complete(const Error(failure));
      await write;
      expect(loaded().medications, [medication]);
      expect(loaded().pendingAction, isNull);
      expect(loaded().failedAction, const DeleteMedicationAction('med'));
      verify(() => repository.deleteMedication('pet', 'med')).called(1);
      verifyNever(() => repository.getMedicationById('pet', 'med'));
    },
  );

  test('list deletion removes known ID without a follow-up read', () async {
    await cubit.loadMedications('pet');
    when(
      () => repository.deleteMedication('pet', 'med'),
    ).thenAnswer((_) async => const Success(null));
    await cubit.performAction(const DeleteMedicationAction('med'));
    expect(loaded().medications, isEmpty);
    expect(loaded().doses.doses, isEmpty);
    expect(loaded().actionError, isNull);
    verify(() => repository.getMedications('pet')).called(1);
  });

  test(
    'detail deletion is terminal; caller can remove a nested deleted ID locally',
    () async {
      await cubit.loadMedication('pet', 'med');
      when(
        () => repository.deleteMedication('pet', 'med'),
      ).thenAnswer((_) async => const Success(null));
      await cubit.performAction(const DeleteMedicationAction('med'));
      expect(cubit.state, const MedicationDeleted('med'));
      await cubit.loadMedication('pet', 'med');
      verify(() => repository.getMedicationById('pet', 'med')).called(1);
    },
  );

  test(
    'removing a future period recalculates the previous plan on the selected future day',
    () async {
      final next = MedicationPeriod(
        id: 'next',
        medicationId: 'med',
        startDate: tomorrow,
        intervalDays: 1,
        doseTimes: [600],
      );
      final withNext = Medication(
        id: 'med',
        petId: 'pet',
        name: 'Medicine',
        periods: [period, next],
      );
      when(
        () => repository.getMedicationById('pet', 'med'),
      ).thenAnswer((_) async => Success(withNext));
      await cubit.loadMedication('pet', 'med');
      stubLogs(tomorrow, medicationId: 'med');
      await cubit.loadDoses(tomorrow);
      expect(loaded().doses.doses.single.scheduledMinute, 600);
      when(
        () => repository.deletePeriod('pet', 'med', 'next'),
      ).thenAnswer((_) async => const Error(failure));
      const action = DeleteMedicationPeriodAction('med', 'next');
      await cubit.performAction(action);
      expect(loaded().medications.single.periods, [period, next]);
      expect(loaded().failedAction, action);
      when(
        () => repository.deletePeriod('pet', 'med', 'next'),
      ).thenAnswer((_) async => const Success(null));
      await cubit.performAction(action);
      expect(loaded().medications.single.periods, [period]);
      expect(loaded().doses.doses.map((d) => d.scheduledMinute), [480, 1200]);
    },
  );

  test(
    'unknown ownership, unscheduled/future doses and started/final periods do not write',
    () async {
      await cubit.loadMedication('pet', 'med');
      await cubit.performAction(const DeleteMedicationAction('other'));
      await cubit.performAction(
        const DeleteMedicationPeriodAction('med', 'period'),
      );
      for (final log in [
        MedicationDoseLog(
          periodId: 'wrong',
          scheduledDate: today,
          scheduledMinute: 480,
          status: MedicationDoseStatus.skipped,
        ),
        MedicationDoseLog(
          periodId: 'period',
          scheduledDate: today,
          scheduledMinute: 481,
          status: MedicationDoseStatus.skipped,
        ),
      ]) {
        await cubit.performAction(SaveMedicationDoseAction('med', log));
      }
      stubLogs(tomorrow, medicationId: 'med');
      await cubit.loadDoses(tomorrow);
      await cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.given,
      );
      verifyNever(() => repository.saveDoseLog(any(), any(), any()));
      verifyNever(() => repository.deleteMedication(any(), any()));
      verifyNever(() => repository.deletePeriod(any(), any(), any()));
    },
  );

  test(
    'clock changes update time without same-day reads and reload on midnight',
    () async {
      await cubit.loadMedications('pet');
      clock = clock.add(const Duration(minutes: 1));
      await cubit.refreshForClockChange();
      expect(loaded().currentTime, clock);
      stubLogs(tomorrow);
      clock = tomorrow;
      await cubit.refreshForClockChange();
      expect(loaded().doses.date, tomorrow);
      verify(() => repository.getMedications('pet')).called(1);
      verify(
        () => repository.getDoseLogs('pet', fromDate: today, toDate: today),
      ).called(1);
      verify(
        () =>
            repository.getDoseLogs('pet', fromDate: tomorrow, toDate: tomorrow),
      ).called(1);
    },
  );

  test(
    'explicit historical day survives clock rollover and canonical detail refresh',
    () async {
      await cubit.loadMedication('pet', 'med');
      stubLogs(past, medicationId: 'med');
      await cubit.loadDoses(past);
      clock = tomorrow;
      await cubit.refreshForClockChange();
      await cubit.loadMedication('pet', 'med');
      expect(loaded().doses.date, past);
      expect(loaded().currentTime, tomorrow);
      verifyNever(
        () => repository.getDoseLogs(
          'pet',
          medicationId: 'med',
          fromDate: tomorrow,
          toDate: tomorrow,
        ),
      );
    },
  );

  for (final detail in [false, true]) {
    test(
      'a write spanning midnight stays visible on failure and moves to today after exact retry (detail: $detail)',
      () async {
        if (detail) {
          await cubit.loadMedication('pet', 'med');
        } else {
          await cubit.loadMedications('pet');
        }
        final response = Completer<Result<void>>();
        when(
          () => repository.saveDoseLog('pet', 'med', any()),
        ).thenAnswer((_) => response.future);
        final write = cubit.saveDose(
          loaded().doses.doses.first,
          MedicationDoseStatus.given,
        );
        clock = tomorrow;
        await cubit.refreshForClockChange();
        response.complete(const Error(failure));
        await write;
        await cubit.refreshForClockChange();
        expect(loaded().doses.date, today);
        expect(loaded().currentTime, tomorrow);
        final failed = loaded().failedAction!;
        stubLogs(tomorrow, medicationId: detail ? 'med' : null);
        when(
          () => repository.saveDoseLog('pet', 'med', any()),
        ).thenAnswer((_) async => const Success(null));
        await cubit.performAction(failed);
        expect(loaded().doses.date, tomorrow);
        expect(loaded().failedAction, isNull);
      },
    );
  }

  test(
    'failed day refresh after a committed dose stays a read error, not a write error',
    () async {
      await cubit.loadMedications('pet');
      final response = Completer<Result<void>>();
      when(
        () => repository.saveDoseLog('pet', 'med', any()),
      ).thenAnswer((_) => response.future);
      final write = cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.given,
      );
      clock = tomorrow;
      when(
        () =>
            repository.getDoseLogs('pet', fromDate: tomorrow, toDate: tomorrow),
      ).thenAnswer((_) async => const Error(failure));
      response.complete(const Success(null));
      await write;
      expect(loaded().doses.date, tomorrow);
      expect(loaded().doses.error, 'Try again');
      expect(loaded().actionError, isNull);
      expect(loaded().failedAction, isNull);
      expect(loaded().pendingAction, isNull);
    },
  );

  for (final detail in [false, true]) {
    test(
      'canonical refresh retains a failed dose and its day after midnight (detail: $detail)',
      () async {
        if (detail) {
          await cubit.loadMedication('pet', 'med');
        } else {
          await cubit.loadMedications('pet');
        }
        when(
          () => repository.saveDoseLog('pet', 'med', any()),
        ).thenAnswer((_) async => const Error(failure));
        await cubit.saveDose(
          loaded().doses.doses.first,
          MedicationDoseStatus.given,
        );
        final failed = loaded().failedAction;
        clock = tomorrow;
        stubLogs(tomorrow, medicationId: detail ? 'med' : null);
        if (detail) {
          await cubit.loadMedication('pet', 'med');
        } else {
          await cubit.loadMedications('pet');
        }
        expect(loaded().failedAction, failed);
        expect(loaded().actionError, 'Try again');
        expect(loaded().doses.date, today);
        expect(loaded().currentTime, tomorrow);
      },
    );
  }

  test(
    'canonical refresh clears failed recovery if its target was removed',
    () async {
      await cubit.loadMedications('pet');
      when(
        () => repository.deleteMedication('pet', 'med'),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.performAction(const DeleteMedicationAction('med'));
      expect(loaded().failedAction, isNotNull);
      when(
        () => repository.getMedications('pet'),
      ).thenAnswer((_) async => const Success([]));
      await cubit.loadMedications('pet');
      expect(loaded().failedAction, isNull);
      expect(loaded().actionError, isNull);
    },
  );

  test(
    'known deletion invalidates an old refresh so it cannot resurrect the record',
    () async {
      await cubit.loadMedications('pet');
      final response = Completer<Result<List<Medication>>>();
      when(
        () => repository.getMedications('pet'),
      ).thenAnswer((_) => response.future);
      final refresh = cubit.loadMedications('pet');
      cubit.removeDeletedMedication('med');
      response.complete(Success([medication]));
      await refresh;
      expect(loaded().medications, isEmpty);
      expect(loaded().isRefreshing, false);
    },
  );

  for (final operation in ['records', 'doses', 'write']) {
    test('closing during $operation ignores its completion', () async {
      late Future<void> pending;
      late void Function() complete;
      if (operation == 'records') {
        final response = Completer<Result<List<Medication>>>();
        when(
          () => repository.getMedications('pet'),
        ).thenAnswer((_) => response.future);
        pending = cubit.loadMedications('pet');
        complete = () => response.complete(Success([medication]));
      } else {
        await cubit.loadMedications('pet');
        if (operation == 'doses') {
          final response = Completer<Result<List<MedicationDoseLog>>>();
          when(
            () => repository.getDoseLogs('pet', fromDate: today, toDate: today),
          ).thenAnswer((_) => response.future);
          pending = cubit.loadDoses(today);
          complete = () => response.complete(const Success([]));
        } else {
          final response = Completer<Result<void>>();
          when(
            () => repository.deleteMedication('pet', 'med'),
          ).thenAnswer((_) => response.future);
          pending = cubit.performAction(const DeleteMedicationAction('med'));
          complete = () => response.complete(const Success(null));
        }
      }
      await cubit.close();
      final before = cubit.state;
      complete();
      await pending;
      expect(cubit.state, before);
      await cubit.loadMedications('pet');
      await cubit.refreshForClockChange();
    });
  }
}
