import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/domain/repositories/medication_repository.dart';
import 'package:patilog/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';

class MockMedications extends Mock implements MedicationRepository {}

void main() {
  const failure = LocalDatabaseFailure('Try again');
  final today = DateTime(2026, 10, 20);
  final yesterday = DateTime(2026, 10, 19);
  final tomorrow = DateTime(2026, 10, 21);
  Medication medication(String owner, {List<int> times = const [480]}) =>
      Medication(
        id: 'med-$owner',
        petId: owner,
        name: 'Medicine',
        periods: [
          MedicationPeriod(
            id: 'period-$owner',
            medicationId: 'med-$owner',
            startDate: yesterday,
            intervalDays: 1,
            doseTimes: times,
          ),
        ],
      );
  final medA = medication('a');
  final medB = medication('b');
  MedicationDoseLog log(
    String owner, {
    DateTime? date,
    MedicationDoseStatus status = MedicationDoseStatus.skipped,
    DateTime? givenAt,
    int minute = 480,
  }) => MedicationDoseLog(
    periodId: 'period-$owner',
    scheduledDate: date ?? today,
    scheduledMinute: minute,
    status: status,
    givenAt: givenAt,
  );

  late MockMedications medications;
  late MedicationCubit cubit;
  late DateTime clock;
  MedicationsLoaded loaded() => cubit.state as MedicationsLoaded;
  bool known() =>
      loaded().doses.hasLoaded &&
      !loaded().doses.isLoading &&
      loaded().doses.error == null &&
      !loaded().isRefreshing &&
      loaded().refreshError == null;
  setUpAll(() {
    registerFallbackValue(today);
    registerFallbackValue(log('a'));
  });
  setUp(() {
    medications = MockMedications();
    clock = DateTime(2026, 10, 20, 10, 15);
    cubit = MedicationCubit(
      medications,
      const CalculateMedicationDoses(),
      now: () => clock,
    )..setPetContext(['a', 'b']);
    when(medications.getAllMedications)
        .thenAnswer((_) async => Success([medA, medB]));
    when(
      () => medications.getAllDoseLogs(
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer((_) async => const Success([]));
    when(() => medications.saveDoseLog(any(), any(), any()))
        .thenAnswer((_) async => const Success<void>(null));
    when(
      () => medications.clearDoseLog(
        any(),
        any(),
        periodId: any(named: 'periodId'),
        scheduledDate: any(named: 'scheduledDate'),
        scheduledMinute: any(named: 'scheduledMinute'),
      ),
    ).thenAnswer((_) async => const Success<void>(null));
  });
  tearDown(() => cubit.close());

  test(
    'pending write blocks duplicate writes, reads and date changes',
    () async {
      await cubit.loadAllMedications();
      final pending = Completer<Result<void>>();
      when(() => medications.saveDoseLog(any(), any(), any()))
          .thenAnswer((_) => pending.future);
      final saving = cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.given,
      );
      await cubit.saveDose(
        loaded().doses.doses.last,
        MedicationDoseStatus.skipped,
      );
      await cubit.loadAllMedications();
      await cubit.loadDoses(yesterday);
      expect(loaded().doses.date, today);
      expect((loaded().pendingAction != null), isTrue);
      pending.complete(const Success<void>(null));
      await saving;
      verify(() => medications.saveDoseLog(any(), any(), any())).called(1);
      expect((loaded().pendingAction != null), isFalse);
    },
  );
  test('today Given uses current instant and canonical owner despite identical medication names', () async {
    await cubit.loadAllMedications();
    final dose = loaded().doses.doses.last;
    await cubit.saveDose(dose, MedicationDoseStatus.given);
    final captured =
        verify(() => medications.saveDoseLog('b', medB.id, captureAny()))
                .captured
                .single
            as MedicationDoseLog;
    expect(captured.givenAt, clock);
    expect(captured.scheduledDate, today);
    expect(captured.periodId, 'period-b');
    expect(loaded().doses.doses.first.log, isNull);
    expect(loaded().doses.doses.last.log, captured);
    verify(() => medications.getAllMedications()).called(1);
    verify(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
        .called(1);
  });
  test(
    'save, correct and clear a dose update only that result without reloading',
    () async {
      await cubit.loadAllMedications();
      await cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.given,
      );
      await cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.skipped,
      );
      final skipped = loaded().doses.doses.first.log!;
      expect(skipped.givenAt, isNull);
      await cubit.performAction(ClearMedicationDoseAction(medA.id, skipped));
      expect(loaded().doses.doses.first.log, isNull);
      expect(loaded().mutationRevision, 3);
      verify(
        () => medications.clearDoseLog(
          'a',
          medA.id,
          periodId: 'period-a',
          scheduledDate: today,
          scheduledMinute: 480,
        ),
      ).called(1);
      verify(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
          .called(1);
    },
  );
  test('dose failure retains exact timestamp for an explicit retry', () async {
    await cubit.loadAllMedications();
    final recordedAt = clock;
    when(() => medications.saveDoseLog(any(), any(), any()))
        .thenAnswer((_) async => const Error(failure));
    await cubit.saveDose(
      loaded().doses.doses.first,
      MedicationDoseStatus.given,
    );
    final retry = loaded().failedAction! as SaveMedicationDoseAction;
    expect(retry.log.givenAt, recordedAt);
    expect(loaded().doses.doses.first.log, isNull);
    clock = clock.add(const Duration(minutes: 1));
    when(() => medications.saveDoseLog(any(), any(), any()))
        .thenAnswer((_) async => const Success<void>(null));
    await cubit.performAction(retry);
    expect(loaded().doses.doses.first.log!.givenAt, recordedAt);
    expect(loaded().mutationRevision, 1);
  });
  test('unknown dose results stay distinct from No record and block writes until retry', () async {
    when(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
        .thenAnswer((_) async => const Error(failure));
    await cubit.loadAllMedications();
    expect(known(), isFalse);
    expect(loaded().doses.error, 'Try again');
    await cubit.saveDose(
      loaded().doses.doses.first,
      MedicationDoseStatus.skipped,
    );
    verifyNever(() => medications.saveDoseLog(any(), any(), any()));
    when(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
        .thenAnswer((_) async => const Success([]));
    await cubit.loadDoses(today);
    expect(known(), isTrue);
    expect(loaded().doses.doses.first.log, isNull);
  });
  test('dose refresh failure keeps recorded outcomes while marking them unavailable for writes', () async {
    await cubit.loadAllMedications();
    await cubit.saveDose(
      loaded().doses.doses.first,
      MedicationDoseStatus.skipped,
    );
    when(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
        .thenAnswer((_) async => const Error(failure));
    await cubit.loadDoses(today);
    expect(
      loaded().doses.doses.first.log!.status,
      MedicationDoseStatus.skipped,
    );
    expect(known(), isFalse);
  });
  test('future days are readable but cannot be recorded', () async {
    await cubit.loadAllMedications();
    await cubit.loadDoses(tomorrow);
    expect(loaded().doses.doses, hasLength(2));
    await cubit.saveDose(
      loaded().doses.doses.first,
      MedicationDoseStatus.given,
    );
    await cubit.saveDose(
      loaded().doses.doses.first,
      MedicationDoseStatus.skipped,
    );
    verifyNever(() => medications.saveDoseLog(any(), any(), any()));
  });
  test('wrong pet, unscheduled time, future Given and clearing an absent log are rejected', () async {
    await cubit.loadAllMedications();
    cubit.setPetContext(['a']);
    await cubit.performAction(SaveMedicationDoseAction(medB.id, log('b')));
    cubit.setPetContext(['a', 'b']);
    await cubit.performAction(
      SaveMedicationDoseAction(medA.id, log('a', minute: 100)),
    );
    await cubit.performAction(
      SaveMedicationDoseAction(
        medA.id,
        log(
          'a',
          status: MedicationDoseStatus.given,
          givenAt: clock.add(const Duration(seconds: 1)),
        ),
      ),
    );
    await cubit.performAction(ClearMedicationDoseAction(medA.id, log('a')));
    verifyNever(() => medications.saveDoseLog(any(), any(), any()));
    verifyNever(
      () => medications.clearDoseLog(
        any(),
        any(),
        periodId: any(named: 'periodId'),
        scheduledDate: any(named: 'scheduledDate'),
        scheduledMinute: any(named: 'scheduledMinute'),
      ),
    );
  });
  test('minute changes are local, midnight follows today, selected history stays fixed', () async {
    await cubit.loadAllMedications();
    clock = clock.add(const Duration(minutes: 1));
    await cubit.refreshForClockChange();
    verify(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
        .called(1);
    clock = DateTime(2026, 10, 21, 0, 1);
    await cubit.refreshForClockChange();
    expect(loaded().doses.date, tomorrow);
    verify(
      () => medications.getAllDoseLogs(fromDate: tomorrow, toDate: tomorrow),
    ).called(1);
    await cubit.loadDoses(yesterday);
    clock = DateTime(2026, 10, 22, 0, 1);
    await cubit.refreshForClockChange();
    expect(loaded().doses.date, yesterday);
    expect(loaded().doses.followsToday, isFalse);
    verify(
      () => medications.getAllDoseLogs(fromDate: yesterday, toDate: yesterday),
    ).called(1);
  });
  test('failed dose retains its selected day at midnight until explicit navigation', () async {
    await cubit.loadAllMedications();
    when(() => medications.saveDoseLog(any(), any(), any()))
        .thenAnswer((_) async => const Error(failure));
    await cubit.saveDose(
      loaded().doses.doses.first,
      MedicationDoseStatus.given,
    );
    clock = DateTime(2026, 10, 21, 0, 1);
    await cubit.refreshForClockChange();
    expect(loaded().doses.date, today);
    expect(loaded().failedAction, isA<SaveMedicationDoseAction>());
    verifyNever(
      () => medications.getAllDoseLogs(fromDate: tomorrow, toDate: tomorrow),
    );
    await cubit.loadDoses(tomorrow);
    expect(loaded().failedAction, isNull);
    expect(loaded().doses.date, tomorrow);
  });
  test('inactive medication section does no clock-driven log reads', () async {
    await cubit.loadAllMedications();
    cubit.setPetContext(['a', 'b'], active: false);
    clock = DateTime(2026, 10, 21, 0, 1);
    await cubit.refreshForClockChange();
    verifyNever(
      () => medications.getAllDoseLogs(fromDate: tomorrow, toDate: tomorrow),
    );
    cubit.setPetContext(['a', 'b']);
    await cubit.refreshForClockChange();
    expect(loaded().doses.date, tomorrow);
    verify(
      () => medications.getAllDoseLogs(fromDate: tomorrow, toDate: tomorrow),
    ).called(1);
  });
  test('a medication refresh completing while hidden reloads its doses on next entry', () async {
    await cubit.loadAllMedications();
    final pending = Completer<Result<List<Medication>>>();
    when(() => medications.getAllMedications())
        .thenAnswer((_) => pending.future);
    final refreshing = cubit.loadAllMedications();
    cubit.setPetContext(['a', 'b'], active: false);
    final changed = medication('a', times: [600, 720]);
    pending.complete(Success([changed]));
    await refreshing;
    expect(loaded().doses.hasLoaded, isFalse);
    cubit.setPetContext(['a', 'b']);
    await cubit.refreshForClockChange();
    expect(loaded().doses.doses.map((d) => d.scheduledMinute), [600, 720]);
    verify(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
        .called(2);
  });
  test('stale day result cannot replace a newer selected day', () async {
    await cubit.loadAllMedications();
    final pending = Completer<Result<List<MedicationDoseLog>>>();
    when(
      () => medications.getAllDoseLogs(fromDate: yesterday, toDate: yesterday),
    ).thenAnswer((_) => pending.future);
    final old = cubit.loadDoses(yesterday);
    await cubit.loadDoses(today);
    pending.complete(Success([log('a', date: yesterday)]));
    await old;
    expect(loaded().doses.date, today);
    expect(
      loaded().doses.doses.every(
        (d) => d.scheduledDate == today && d.log == null,
      ),
      isTrue,
    );
  });
  test('dirty medication data cannot accept writes or fetch logs before canonical refresh', () async {
    await cubit.loadAllMedications();
    cubit.invalidateList();
    expect(known(), isFalse);
    await cubit.saveDose(
      loaded().doses.doses.first,
      MedicationDoseStatus.skipped,
    );
    await cubit.loadDoses(today);
    verifyNever(() => medications.saveDoseLog(any(), any(), any()));
    verify(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
        .called(1);
    await cubit.loadAllMedications();
    expect(known(), isTrue);
    verify(() => medications.getAllMedications()).called(2);
  });
  test(
    'successful external medication changes clear the now-stale dose retry',
    () async {
      await cubit.loadAllMedications();
      when(() => medications.saveDoseLog(any(), any(), any()))
          .thenAnswer((_) async => const Error(failure));
      await cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.given,
      );
      cubit.invalidateList();
      expect(loaded().failedAction, isNull);
      expect(loaded().actionError, isNull);
      expect(known(), isFalse);
    },
  );
  test(
    'known medication deletion removes its doses without a source reread',
    () async {
      await cubit.loadAllMedications();
      cubit.removeDeletedMedication(medB.id, petId: 'b');
      expect(loaded().medications, [medA]);
      expect(
        loaded().doses.doses.every((d) => d.medication.petId == 'a'),
        isTrue,
      );
      verify(() => medications.getAllMedications()).called(1);
      verify(() => medications.getAllDoseLogs(fromDate: today, toDate: today))
          .called(1);
    },
  );
  test(
    'known medication deletion survives a pending canonical medication read',
    () async {
      await cubit.loadAllMedications();
      final pending = Completer<Result<List<Medication>>>();
      when(() => medications.getAllMedications())
          .thenAnswer((_) => pending.future);
      final refreshing = cubit.loadAllMedications();
      cubit.removeDeletedMedication(medB.id, petId: 'b');
      pending.complete(Success([medA, medB]));
      await refreshing;
      expect(loaded().medications, [medA]);
      expect(loaded().doses.doses.single.medication, medA);
      verify(() => medications.getAllMedications()).called(2);
    },
  );
  test(
    'successful mutation notifications include the updated result atomically',
    () async {
      await cubit.loadAllMedications();
      final states = <MedicationState>[];
      final subscription = cubit.stream.listen(states.add);
      await cubit.saveDose(
        loaded().doses.doses.first,
        MedicationDoseStatus.given,
      );
      await Future<void>.delayed(Duration.zero);
      final notification = states.whereType<MedicationsLoaded>().firstWhere(
        (s) => s.mutationRevision == 1,
      );
      expect(
        notification.doses.doses.first.log!.status,
        MedicationDoseStatus.given,
      );
      expect(notification.pendingAction, isNull);
      await subscription.cancel();
    },
  );

  for (final fails in [false, true]) {
    test(
      'pet removal survives a late ${fails ? 'failed' : 'successful'} medication refresh',
      () async {
        await cubit.loadAllMedications();
        final pending = Completer<Result<List<Medication>>>();
        when(medications.getAllMedications).thenAnswer((_) => pending.future);
        final read = cubit.loadAllMedications();
        cubit.removeDeletedPet('b');
        pending.complete(fails ? const Error(failure) : Success([medA, medB]));
        await read;
        expect(loaded().medications, [medA]);
        expect(
          loaded().doses.doses.every((d) => d.medication.petId == 'a'),
          isTrue,
        );
        verify(medications.getAllMedications).called(2);
      },
    );
  }
  test(
    'a deleted owner is removed even during the first medication read',
    () async {
      final pending = Completer<Result<List<Medication>>>();
      when(medications.getAllMedications).thenAnswer((_) => pending.future);
      final read = cubit.loadAllMedications();
      cubit.removeDeletedPet('b');
      pending.complete(Success([medA, medB]));
      await read;
      expect(loaded().medications, [medA]);
    },
  );
  test('filter context rejects doses from hidden owners', () async {
    await cubit.loadAllMedications();
    cubit.setPetContext(['a', 'b'], selectedPetId: 'a');
    await cubit.saveDose(loaded().doses.doses.last, MedicationDoseStatus.given);
    verifyNever(() => medications.saveDoseLog(any(), any(), any()));
  });

  for (final active in [true, false]) {
    test(
      'canonical refresh preserves a failed dose intent, active=$active',
      () async {
        await cubit.loadAllMedications();
        final recordedAt = clock;
        when(() => medications.saveDoseLog(any(), any(), any()))
            .thenAnswer((_) async => const Error(failure));
        await cubit.saveDose(
          loaded().doses.doses.first,
          MedicationDoseStatus.given,
        );
        cubit.setPetContext(['a', 'b'], active: active);
        clock = tomorrow;
        await cubit.loadAllMedications();
        expect(loaded().failedAction, isA<SaveMedicationDoseAction>());
        expect(loaded().actionError, 'Try again');
        expect(loaded().doses.date, today);
        cubit.setPetContext(['a', 'b']);
        await cubit.refreshForClockChange();
        expect(loaded().doses.hasLoaded, isTrue);
        when(() => medications.saveDoseLog(any(), any(), any()))
            .thenAnswer((_) async => const Success<void>(null));
        await cubit.performAction(loaded().failedAction!);
        final saved =
            verify(() => medications.saveDoseLog('a', medA.id, captureAny()))
                    .captured
                    .last
                as MedicationDoseLog;
        expect(saved.givenAt, recordedAt);
        expect(saved.scheduledDate, today);
      },
    );
  }
}
