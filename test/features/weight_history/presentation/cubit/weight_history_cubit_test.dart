import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_state.dart';

class MockWeightHistoryRepository extends Mock
    implements WeightHistoryRepository {}

class MockIdGenerator extends Mock implements IdGenerator {}

void main() {
  late MockWeightHistoryRepository repository;
  late MockIdGenerator idGenerator;
  final entry = WeightEntry(
    id: 'generated-id',
    petId: 'pet-1',
    weight: 5.4,
    measuredAt: DateTime.utc(2026, 10, 13),
  );
  final updated = WeightEntry(
    id: entry.id,
    petId: entry.petId,
    weight: 5.8,
    measuredAt: DateTime.utc(2026, 10, 12),
  );

  setUp(() {
    repository = MockWeightHistoryRepository();
    idGenerator = MockIdGenerator();
  });

  WeightHistoryCubit makeCubit() => WeightHistoryCubit(repository, idGenerator);

  blocTest<WeightHistoryCubit, WeightHistoryState>(
    'refresh failure retains loaded measurements',
    build: () {
      when(() => repository.getWeightEntries(entry.petId)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Refresh failed')),
      );
      return makeCubit();
    },
    seed: () => WeightHistoryLoaded([entry], petId: entry.petId),
    act: (cubit) => cubit.loadWeightHistory(entry.petId),
    expect: () => [
      WeightHistoryLoaded([entry], petId: entry.petId, isRefreshing: true),
      WeightHistoryLoaded(
        [entry],
        petId: entry.petId,
        refreshError: 'Refresh failed',
      ),
    ],
  );

  test('starts in the initial state', () {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    expect(cubit.state, const WeightHistoryInitial());
  });

  for (final entries in <List<WeightEntry>>[
    [],
    [entry],
  ]) {
    blocTest<WeightHistoryCubit, WeightHistoryState>(
      'loads ${entries.length} measurements',
      build: () {
        when(() => repository.getWeightEntries(entry.petId))
            .thenAnswer((_) async => Success(entries));
        return makeCubit();
      },
      act: (cubit) => cubit.loadWeightHistory(entry.petId),
      expect: () => [
        const WeightHistoryLoading(),
        WeightHistoryLoaded(entries, petId: entry.petId),
      ],
      verify: (_) =>
          verify(() => repository.getWeightEntries(entry.petId)).called(1),
    );
  }

  blocTest<WeightHistoryCubit, WeightHistoryState>(
    'reports a history loading failure',
    build: () {
      when(() => repository.getWeightEntries(entry.petId)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Load failed')),
      );
      return makeCubit();
    },
    act: (cubit) => cubit.loadWeightHistory(entry.petId),
    expect: () => [
      const WeightHistoryLoading(),
      const WeightHistoryError(LocalDatabaseFailure('Load failed')),
    ],
  );

  for (final (result, state) in <(Result<void>, WeightHistoryState)>[
    (const Success(null), const WeightEntryCreated()),
    (
      const Error(LocalDatabaseFailure('Save failed')),
      const WeightHistoryError(LocalDatabaseFailure('Save failed')),
    ),
  ]) {
    blocTest<WeightHistoryCubit, WeightHistoryState>(
      'creates a measurement with a generated ID and emits $state',
      build: () {
        when(() => idGenerator.generate()).thenReturn(entry.id);
        when(() => repository.createWeightEntry(entry))
            .thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.createWeightEntry(
        petId: entry.petId,
        weight: entry.weight,
        measuredAt: entry.measuredAt,
      ),
      expect: () => [const WeightHistoryLoading(), state],
      verify: (_) {
        verify(() => idGenerator.generate()).called(1);
        verify(() => repository.createWeightEntry(entry)).called(1);
      },
    );
  }

  for (final (result, state) in <(Result<void>, WeightHistoryState)>[
    (const Success(null), const WeightEntryUpdated()),
    (
      const Error(LocalDatabaseFailure('Update failed')),
      const WeightHistoryError(LocalDatabaseFailure('Update failed')),
    ),
    (
      const Error(NotFoundFailure('Measurement not found')),
      const WeightHistoryError(NotFoundFailure('Measurement not found')),
    ),
  ]) {
    blocTest<WeightHistoryCubit, WeightHistoryState>(
      'preserves measurement identity when updating and emits $state',
      build: () {
        when(() => repository.updateWeightEntry(updated))
            .thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.updateWeightEntry(
        entry,
        weight: updated.weight,
        measuredAt: updated.measuredAt,
      ),
      expect: () => [const WeightHistoryLoading(), state],
      verify: (_) {
        verify(() => repository.updateWeightEntry(updated)).called(1);
        verifyZeroInteractions(idGenerator);
      },
    );
  }

  blocTest<WeightHistoryCubit, WeightHistoryState>(
    'removes a deleted measurement without discarding the loaded list',
    build: () {
      when(() => repository.deleteWeightEntry(entry.id))
          .thenAnswer((_) async => const Success(null));
      return makeCubit();
    },
    seed: () => WeightHistoryLoaded([entry], petId: entry.petId),
    act: (cubit) => cubit.deleteWeightEntry(entry),
    expect: () => [
      WeightHistoryLoaded(
        [entry],
        petId: entry.petId,
        isDeleting: true,
        deletionEntry: entry,
      ),
      const WeightHistoryLoaded([], petId: 'pet-1'),
    ],
    verify: (_) {
      verify(() => repository.deleteWeightEntry(entry.id)).called(1);
      verifyNever(() => repository.getWeightEntries(entry.petId));
    },
  );

  blocTest<WeightHistoryCubit, WeightHistoryState>(
    'keeps the list and failed measurement available for a deletion retry',
    build: () {
      when(() => repository.deleteWeightEntry(entry.id)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Delete failed')),
      );
      return makeCubit();
    },
    seed: () => WeightHistoryLoaded([entry], petId: entry.petId),
    act: (cubit) => cubit.deleteWeightEntry(entry),
    expect: () => [
      WeightHistoryLoaded(
        [entry],
        petId: entry.petId,
        isDeleting: true,
        deletionEntry: entry,
      ),
      WeightHistoryLoaded(
        [entry],
        petId: entry.petId,
        deletionEntry: entry,
        deleteError: 'Delete failed',
      ),
    ],
    verify: (_) => verifyNever(() => repository.getWeightEntries(entry.petId)),
  );

  test(
    'ignores duplicate deletions while keeping the remaining order',
    () async {
      final older = WeightEntry(
        id: 'older',
        petId: entry.petId,
        weight: 5,
        measuredAt: DateTime.utc(2026, 10, 12),
      );
      when(() => repository.getWeightEntries(entry.petId))
          .thenAnswer((_) async => Success([entry, older]));
      final pending = Completer<Result<void>>();
      when(() => repository.deleteWeightEntry(entry.id))
          .thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadWeightHistory(entry.petId);
      final first = cubit.deleteWeightEntry(entry);
      await cubit.deleteWeightEntry(entry);
      pending.complete(const Success(null));
      await first;
      expect(cubit.state, WeightHistoryLoaded([older], petId: entry.petId));
      verify(() => repository.deleteWeightEntry(entry.id)).called(1);
      verify(() => repository.getWeightEntries(entry.petId)).called(1);
    },
  );

  test(
    'does not emit when a pending load finishes after the Cubit closes',
    () async {
      final pending = Completer<Result<List<WeightEntry>>>();
      when(() => repository.getWeightEntries(entry.petId))
          .thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      final operation = cubit.loadWeightHistory(entry.petId);
      await cubit.close();
      pending.complete(Success([entry]));
      await expectLater(operation, completes);
    },
  );

  test(
    'does not emit or reload when a pending deletion finishes after closing',
    () async {
      final pending = Completer<Result<void>>();
      when(() => repository.deleteWeightEntry(entry.id))
          .thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      when(() => repository.getWeightEntries(entry.petId))
          .thenAnswer((_) async => Success([entry]));
      await cubit.loadWeightHistory(entry.petId);
      clearInteractions(repository);
      final operation = cubit.deleteWeightEntry(entry);
      await cubit.close();
      pending.complete(const Success(null));
      await expectLater(operation, completes);
      verifyNever(() => repository.getWeightEntries(entry.petId));
    },
  );
}
