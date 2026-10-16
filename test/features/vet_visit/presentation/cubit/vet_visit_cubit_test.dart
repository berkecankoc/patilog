import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';

class MockVetVisitRepository extends Mock implements VetVisitRepository {}

void main() {
  late MockVetVisitRepository repository;
  final visit = VetVisit(
    id: 'visit-1',
    petId: 'pet-1',
    visitedOn: DateTime(2026, 10, 15),
    reason: 'Checkup',
  );
  final older = VetVisit(
    id: 'older',
    petId: visit.petId,
    visitedOn: DateTime(2026, 10, 14),
    reason: 'Follow-up',
  );
  final corrected = VetVisit(
    id: visit.id,
    petId: visit.petId,
    visitedOn: visit.visitedOn,
    reason: 'Updated checkup',
  );

  setUp(() => repository = MockVetVisitRepository());
  VetVisitCubit makeCubit() => VetVisitCubit(repository);

  test('starts in the initial state', () {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    expect(cubit.state, const VetVisitInitial());
  });

  for (final visits in <List<VetVisit>>[
    [],
    [visit, older],
  ]) {
    blocTest<VetVisitCubit, VetVisitState>(
      'loads ${visits.length} visits without changing order',
      build: () {
        when(
          () => repository.getVetVisits(visit.petId),
        ).thenAnswer((_) async => Success(visits));
        return makeCubit();
      },
      act: (cubit) => cubit.loadVetVisits(visit.petId),
      expect: () => [
        const VetVisitLoading(),
        VetVisitsLoaded(visit.petId, visits),
      ],
    );
  }

  blocTest<VetVisitCubit, VetVisitState>(
    'reports an initial list failure',
    build: () {
      when(() => repository.getVetVisits(visit.petId)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Load failed')),
      );
      return makeCubit();
    },
    act: (cubit) => cubit.loadVetVisits(visit.petId),
    expect: () => [const VetVisitLoading(), const VetVisitError('Load failed')],
  );

  blocTest<VetVisitCubit, VetVisitState>(
    'keeps the loaded list on refresh failure and can retry',
    build: () {
      when(() => repository.getVetVisits(visit.petId)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Refresh failed')),
      );
      return makeCubit();
    },
    seed: () => VetVisitsLoaded(visit.petId, [visit, older]),
    act: (cubit) async {
      await cubit.loadVetVisits(visit.petId);
      when(
        () => repository.getVetVisits(visit.petId),
      ).thenAnswer((_) async => Success([visit]));
      await cubit.loadVetVisits(visit.petId);
    },
    expect: () => [
      VetVisitsLoaded(visit.petId, [visit, older], isRefreshing: true),
      VetVisitsLoaded(visit.petId, [
        visit,
        older,
      ], refreshError: 'Refresh failed'),
      VetVisitsLoaded(visit.petId, [visit, older], isRefreshing: true),
      VetVisitsLoaded(visit.petId, [visit]),
    ],
  );

  for (final (result, expected) in <(Result<VetVisit>, VetVisitState)>[
    (Success(visit), VetVisitLoaded(visit)),
    (
      const Error(NotFoundFailure('Visit not found')),
      const VetVisitError('Visit not found'),
    ),
    (
      const Error(LocalDatabaseFailure('Load failed')),
      const VetVisitError('Load failed'),
    ),
  ]) {
    blocTest<VetVisitCubit, VetVisitState>(
      'loads scoped detail and emits $expected',
      build: () {
        when(
          () => repository.getVetVisitById(visit.petId, visit.id),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.loadVetVisit(visit.petId, visit.id),
      expect: () => [const VetVisitLoading(), expected],
      verify: (_) => verify(
        () => repository.getVetVisitById(visit.petId, visit.id),
      ).called(1),
    );
  }

  blocTest<VetVisitCubit, VetVisitState>(
    'keeps detail on refresh failure and replaces it on successful retry',
    build: () {
      when(() => repository.getVetVisitById(visit.petId, visit.id)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Refresh failed')),
      );
      return makeCubit();
    },
    seed: () => VetVisitLoaded(visit),
    act: (cubit) async {
      await cubit.loadVetVisit(visit.petId, visit.id);
      when(
        () => repository.getVetVisitById(visit.petId, visit.id),
      ).thenAnswer((_) async => Success(corrected));
      await cubit.loadVetVisit(visit.petId, visit.id);
    },
    expect: () => [
      VetVisitLoaded(visit, isRefreshing: true),
      VetVisitLoaded(visit, refreshError: 'Refresh failed'),
      VetVisitLoaded(visit, isRefreshing: true),
      VetVisitLoaded(corrected),
    ],
  );

  for (final (result, expected) in <(Result<void>, VetVisitState)>[
    (const Success(null), VetVisitDeleted(visit.id)),
    (
      const Error(LocalDatabaseFailure('Delete failed')),
      VetVisitLoaded(visit, deleteError: 'Delete failed'),
    ),
    (
      const Error(NotFoundFailure('Visit not found')),
      VetVisitLoaded(visit, deleteError: 'Visit not found'),
    ),
  ]) {
    blocTest<VetVisitCubit, VetVisitState>(
      'deletes the loaded visit and emits $expected without rereading',
      build: () {
        when(
          () => repository.deleteVetVisit(visit.petId, visit.id),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      seed: () => VetVisitLoaded(visit),
      act: (cubit) => cubit.deleteVetVisit(),
      expect: () => [VetVisitLoaded(visit, isDeleting: true), expected],
      verify: (_) {
        verify(
          () => repository.deleteVetVisit(visit.petId, visit.id),
        ).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  blocTest<VetVisitCubit, VetVisitState>(
    'retrying deletion clears its old error and can succeed',
    build: () {
      when(
        () => repository.deleteVetVisit(visit.petId, visit.id),
      ).thenAnswer((_) async => const Success(null));
      return makeCubit();
    },
    seed: () => VetVisitLoaded(visit, deleteError: 'Delete failed'),
    act: (cubit) => cubit.deleteVetVisit(),
    expect: () => [
      VetVisitLoaded(visit, isDeleting: true),
      VetVisitDeleted(visit.id),
    ],
  );

  test(
    'a newer pet load wins over an older response without showing old data',
    () async {
      final first = Completer<Result<List<VetVisit>>>();
      final second = Completer<Result<List<VetVisit>>>();
      when(
        () => repository.getVetVisits(visit.petId),
      ).thenAnswer((_) => first.future);
      when(
        () => repository.getVetVisits('pet-2'),
      ).thenAnswer((_) => second.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final firstLoad = cubit.loadVetVisits(visit.petId);
      final secondLoad = cubit.loadVetVisits('pet-2');
      second.complete(const Success([]));
      await secondLoad;
      first.complete(Success([visit]));
      await firstLoad;
      expect(cubit.state, const VetVisitsLoaded('pet-2', []));

      when(() => repository.getVetVisits(visit.petId)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Load failed')),
      );
      await cubit.loadVetVisits(visit.petId);
      expect(cubit.state, const VetVisitError('Load failed'));
    },
  );

  test(
    'the latest detail request wins when reads complete out of order',
    () async {
      final first = Completer<Result<VetVisit>>();
      when(
        () => repository.getVetVisitById(visit.petId, visit.id),
      ).thenAnswer((_) => first.future);
      when(
        () => repository.getVetVisitById(older.petId, older.id),
      ).thenAnswer((_) async => Success(older));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final oldLoad = cubit.loadVetVisit(visit.petId, visit.id);
      await cubit.loadVetVisit(older.petId, older.id);
      first.complete(Success(visit));
      await oldLoad;
      expect(cubit.state, VetVisitLoaded(older));
    },
  );

  test(
    'pending deletion blocks duplicate writes and invalidates an old refresh',
    () async {
      when(
        () => repository.getVetVisitById(visit.petId, visit.id),
      ).thenAnswer((_) async => Success(visit));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadVetVisit(visit.petId, visit.id);
      final refresh = Completer<Result<VetVisit>>();
      when(
        () => repository.getVetVisitById(visit.petId, visit.id),
      ).thenAnswer((_) => refresh.future);
      final oldRefresh = cubit.loadVetVisit(visit.petId, visit.id);
      final deletion = Completer<Result<void>>();
      when(
        () => repository.deleteVetVisit(visit.petId, visit.id),
      ).thenAnswer((_) => deletion.future);
      final deleting = cubit.deleteVetVisit();
      await cubit.deleteVetVisit();
      await cubit.loadVetVisit(visit.petId, visit.id);
      await cubit.loadVetVisits(visit.petId);
      refresh.complete(Success(visit));
      await oldRefresh;
      expect(cubit.state, VetVisitLoaded(visit, isDeleting: true));
      deletion.complete(const Success(null));
      await deleting;
      await cubit.loadVetVisit(visit.petId, visit.id);
      await cubit.deleteVetVisit();
      expect(cubit.state, VetVisitDeleted(visit.id));
      verify(() => repository.deleteVetVisit(visit.petId, visit.id)).called(1);
      verify(() => repository.getVetVisitById(visit.petId, visit.id)).called(2);
      verifyNever(() => repository.getVetVisits(visit.petId));
    },
  );

  test(
    'applies a known deletion locally and ignores an outstanding stale list',
    () async {
      when(
        () => repository.getVetVisits(visit.petId),
      ).thenAnswer((_) async => Success([visit, older]));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadVetVisits(visit.petId);
      final refresh = Completer<Result<List<VetVisit>>>();
      when(
        () => repository.getVetVisits(visit.petId),
      ).thenAnswer((_) => refresh.future);
      final oldRefresh = cubit.loadVetVisits(visit.petId);
      cubit.removeDeletedVisit(visit.id);
      expect(cubit.state, VetVisitsLoaded(visit.petId, [older]));
      refresh.complete(Success([visit, older]));
      await oldRefresh;
      expect(cubit.state, VetVisitsLoaded(visit.petId, [older]));
      verify(() => repository.getVetVisits(visit.petId)).called(2);
      verifyNever(() => repository.deleteVetVisit(visit.petId, visit.id));
    },
  );

  for (final operation in ['list', 'detail', 'delete']) {
    test(
      'does not emit when pending $operation completes after close',
      () async {
        final cubit = makeCubit();
        final pendingList = Completer<Result<List<VetVisit>>>();
        final pendingDetail = Completer<Result<VetVisit>>();
        final pendingDelete = Completer<Result<void>>();
        when(
          () => repository.getVetVisits(visit.petId),
        ).thenAnswer((_) => pendingList.future);
        when(
          () => repository.getVetVisitById(visit.petId, visit.id),
        ).thenAnswer((_) async => Success(visit));
        when(
          () => repository.deleteVetVisit(visit.petId, visit.id),
        ).thenAnswer((_) => pendingDelete.future);
        if (operation == 'delete') {
          await cubit.loadVetVisit(visit.petId, visit.id);
        }
        when(
          () => repository.getVetVisitById(visit.petId, visit.id),
        ).thenAnswer((_) => pendingDetail.future);
        final work = switch (operation) {
          'list' => cubit.loadVetVisits(visit.petId),
          'detail' => cubit.loadVetVisit(visit.petId, visit.id),
          _ => cubit.deleteVetVisit(),
        };
        await cubit.close();
        pendingList.complete(Success([visit]));
        pendingDetail.complete(Success(visit));
        pendingDelete.complete(const Success(null));
        await expectLater(work, completes);
        clearInteractions(repository);
        await cubit.loadVetVisits(visit.petId);
        await cubit.loadVetVisit(visit.petId, visit.id);
        await cubit.deleteVetVisit();
        cubit.removeDeletedVisit(visit.id);
        verifyZeroInteractions(repository);
      },
    );
  }
}
