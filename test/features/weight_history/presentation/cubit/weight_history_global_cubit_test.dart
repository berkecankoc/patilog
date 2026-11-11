import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_state.dart';

class _Repository extends Mock implements WeightHistoryRepository {}

class _Ids extends Mock implements IdGenerator {}

void main() {
  late _Repository repository;
  late WeightHistoryCubit cubit;
  final a = WeightEntry(
    id: 'a',
    petId: 'pet-a',
    weight: 5,
    measuredAt: DateTime(2026, 11, 6),
  );
  final b = WeightEntry(
    id: 'b',
    petId: 'pet-b',
    weight: 7,
    measuredAt: DateTime(2026, 11, 5),
  );
  setUp(() {
    repository = _Repository();
    cubit = WeightHistoryCubit(repository, _Ids())
      ..setPetContext(['pet-a', 'pet-b']);
    when(repository.getAllWeightEntries)
        .thenAnswer((_) async => Success([a, b]));
    when(() => repository.deleteWeightEntry(any()))
        .thenAnswer((_) async => const Success(null));
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test('loads once across pets and retains the current history after refresh failure', () async {
    await cubit.loadAllWeightHistory();
    expect(cubit.state, WeightHistoryLoaded([a, b]));
    verify(repository.getAllWeightEntries).called(1);
    verifyNever(() => repository.getWeightEntries(any()));
    when(repository.getAllWeightEntries)
        .thenAnswer((_) async => const Error(LocalDatabaseFailure('Failed')));
    await cubit.loadAllWeightHistory();
    expect(cubit.state, WeightHistoryLoaded([a, b], refreshError: 'Failed'));
  });

  test('does not reuse another scope even if its list is empty', () async {
    when(repository.getAllWeightEntries)
        .thenAnswer((_) async => const Success([]));
    when(() => repository.getWeightEntries('pet-a'))
        .thenAnswer((_) async => const Error(LocalDatabaseFailure('Failed')));
    await cubit.loadAllWeightHistory();
    await cubit.loadWeightHistory('pet-a');
    expect(
      cubit.state,
      const WeightHistoryError(LocalDatabaseFailure('Failed')),
    );
  });

  test(
    'guards unknown, foreign, filtered-out and refreshing deletion targets',
    () async {
      await cubit.loadAllWeightHistory();
      cubit.setPetContext(['pet-a', 'pet-b'], selectedPetId: 'pet-a');
      await cubit.deleteWeightEntry(b);
      cubit.setPetContext(['pet-a']);
      await cubit.deleteWeightEntry(b);
      await cubit.deleteWeightEntry(
        WeightEntry(
          id: 'missing',
          petId: a.petId,
          weight: 5,
          measuredAt: a.measuredAt,
        ),
      );
      final pending = Completer<Result<List<WeightEntry>>>();
      when(repository.getAllWeightEntries).thenAnswer((_) => pending.future);
      final refresh = cubit.loadAllWeightHistory();
      await cubit.deleteWeightEntry(a);
      verifyNever(() => repository.deleteWeightEntry(any()));
      pending.complete(Success([a, b]));
      await refresh;
    },
  );

  test('removes only the selected measurement without reading again and blocks duplicate writes', () async {
    await cubit.loadAllWeightHistory();
    final pending = Completer<Result<void>>();
    when(() => repository.deleteWeightEntry(a.id))
        .thenAnswer((_) => pending.future);
    final write = cubit.deleteWeightEntry(a);
    await cubit.deleteWeightEntry(a);
    await cubit.loadAllWeightHistory();
    pending.complete(const Success(null));
    await write;
    expect(cubit.state, WeightHistoryLoaded([b]));
    verify(repository.getAllWeightEntries).called(1);
    verify(() => repository.deleteWeightEntry(a.id)).called(1);
  });

  for (final fails in [false, true]) {
    test(
      'known entry and pet deletions survive a late ${fails ? 'failed' : 'successful'} refresh',
      () async {
        await cubit.loadAllWeightHistory();
        final pending = Completer<Result<List<WeightEntry>>>();
        when(repository.getAllWeightEntries).thenAnswer((_) => pending.future);
        final read = cubit.loadAllWeightHistory();
        cubit.removeDeletedEntry(a.id, petId: a.petId);
        cubit.removeDeletedPet(b.petId);
        pending.complete(
          fails ? const Error(LocalDatabaseFailure('Failed')) : Success([a, b]),
        );
        await read;
        expect((cubit.state as WeightHistoryLoaded).entries, isEmpty);
        if (fails) {
          expect((cubit.state as WeightHistoryLoaded).refreshError, 'Failed');
        }
      },
    );
  }

  test('late loads and closed state cannot replace current results or start writes', () async {
    final pending = Completer<Result<List<WeightEntry>>>();
    when(repository.getAllWeightEntries).thenAnswer((_) => pending.future);
    final first = cubit.loadAllWeightHistory();
    when(repository.getAllWeightEntries).thenAnswer((_) async => Success([b]));
    await cubit.loadAllWeightHistory();
    pending.complete(Success([a]));
    await first;
    expect(cubit.state, WeightHistoryLoaded([b]));
    final pendingClose = Completer<Result<List<WeightEntry>>>();
    when(repository.getAllWeightEntries).thenAnswer((_) => pendingClose.future);
    final read = cubit.loadAllWeightHistory();
    await cubit.close();
    pendingClose.complete(Success([a, b]));
    await read;
    await cubit.deleteWeightEntry(a);
    verifyNever(() => repository.deleteWeightEntry(any()));
  });
}
