import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:patilog/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_state.dart';

class MockRepository extends Mock implements VetVisitRepository {}

void main() {
  VetVisit record(String owner, {String? id}) => VetVisit(
    id: id ?? owner,
    petId: owner,
    visitedOn: DateTime(2026, 10, 20),
    reason: 'Checkup',
  );
  final a = record('a');
  final b = record('b');
  const failure = LocalDatabaseFailure('Try again');
  late MockRepository repository;
  late VetVisitCubit cubit;
  VetVisitsLoaded loaded() => cubit.state as VetVisitsLoaded;
  setUp(() {
    repository = MockRepository();
    when(repository.getAllVetVisits).thenAnswer((_) async => Success([a, b]));
    when(() => repository.deleteVetVisit(any(), any()))
        .thenAnswer((_) async => const Success<void>(null));
    cubit = VetVisitCubit(repository)..setPetContext(['a', 'b']);
  });
  tearDown(() => cubit.close());
  test(
    'the same feature Cubit reads all owners without a scoped query',
    () async {
      await cubit.loadAllVetVisits();
      expect(loaded().petId, isNull);
      expect(loaded().visits, [a, b]);
      verify(repository.getAllVetVisits).called(1);
    },
  );
  test('canonical owner is used for deletion and no reread occurs', () async {
    await cubit.loadAllVetVisits();
    await cubit.deleteListedVisit(b);
    expect(loaded().visits, [a]);
    verify(() => repository.deleteVetVisit('b', 'b')).called(1);
    verify(repository.getAllVetVisits).called(1);
  });
  test(
    'missing owner, forged owner, absent record and hidden filter are rejected',
    () async {
      await cubit.loadAllVetVisits();
      cubit.setPetContext(['a']);
      await cubit.deleteListedVisit(b);
      await cubit.deleteListedVisit(record('a', id: 'b'));
      await cubit.deleteListedVisit(record('a', id: 'missing'));
      cubit.setPetContext(['a', 'b'], selectedPetId: 'a');
      await cubit.deleteListedVisit(b);
      verifyNever(() => repository.deleteVetVisit(any(), any()));
    },
  );
  test(
    'failed deletion retains content and intended target for explicit retry',
    () async {
      await cubit.loadAllVetVisits();
      when(() => repository.deleteVetVisit('b', 'b'))
          .thenAnswer((_) async => const Error(failure));
      await cubit.deleteListedVisit(b);
      expect(loaded().visits, [a, b]);
      expect(loaded().deletionVisit, b);
      expect(loaded().deleteError, 'Try again');
      when(() => repository.deleteVetVisit('b', 'b'))
          .thenAnswer((_) async => const Success<void>(null));
      await cubit.deleteListedVisit(loaded().deletionVisit!);
      expect(loaded().visits, [a]);
      expect(loaded().deleteError, isNull);
    },
  );
  test('pending deletion blocks repeated writes and reads', () async {
    await cubit.loadAllVetVisits();
    final pending = Completer<Result<void>>();
    when(() => repository.deleteVetVisit('a', 'a'))
        .thenAnswer((_) => pending.future);
    final write = cubit.deleteListedVisit(a);
    await cubit.deleteListedVisit(b);
    await cubit.loadAllVetVisits();
    expect(loaded().isDeleting, isTrue);
    pending.complete(const Success<void>(null));
    await write;
    expect(loaded().visits, [b]);
    verify(() => repository.deleteVetVisit(any(), any())).called(1);
    verify(repository.getAllVetVisits).called(1);
  });
  for (final fails in [false, true]) {
    test(
      'known deletion survives a late ${fails ? 'failed' : 'successful'} refresh',
      () async {
        await cubit.loadAllVetVisits();
        final pending = Completer<Result<List<VetVisit>>>();
        when(repository.getAllVetVisits).thenAnswer((_) => pending.future);
        final refresh = cubit.loadAllVetVisits();
        cubit.removeDeletedVisit('b', petId: 'b');
        pending.complete(fails ? const Error(failure) : Success([a, b]));
        await refresh;
        expect(loaded().visits, [a]);
        expect(loaded().isRefreshing, isFalse);
        verify(repository.getAllVetVisits).called(2);
      },
    );
  }
  test('initial read reconciles known record and pet deletions', () async {
    final pending = Completer<Result<List<VetVisit>>>();
    when(repository.getAllVetVisits).thenAnswer((_) => pending.future);
    final read = cubit.loadAllVetVisits();
    cubit.removeDeletedVisit('a', petId: 'a');
    cubit.removeDeletedPet('b');
    pending.complete(Success([a, b]));
    await read;
    expect(loaded().visits, isEmpty);
  });
  test('external target deletion removes a stale failed retry', () async {
    await cubit.loadAllVetVisits();
    when(() => repository.deleteVetVisit('b', 'b'))
        .thenAnswer((_) async => const Error(failure));
    await cubit.deleteListedVisit(b);
    cubit.removeDeletedVisit('b', petId: 'b');
    expect(loaded().deleteError, isNull);
    expect(loaded().deletionVisit, isNull);
    expect(loaded().visits, [a]);
  });
  test(
    'refresh failure retains content; invalidated old replies cannot win',
    () async {
      await cubit.loadAllVetVisits();
      when(repository.getAllVetVisits)
          .thenAnswer((_) async => const Error(failure));
      await cubit.loadAllVetVisits();
      expect(loaded().visits, [a, b]);
      expect(loaded().refreshError, 'Try again');
      final pending = Completer<Result<List<VetVisit>>>();
      when(repository.getAllVetVisits).thenAnswer((_) => pending.future);
      final old = cubit.loadAllVetVisits();
      cubit.invalidateList();
      expect(cubit.needsReload, isTrue);
      when(repository.getAllVetVisits).thenAnswer((_) async => Success([b]));
      await cubit.loadAllVetVisits();
      pending.complete(Success([a]));
      await old;
      expect(loaded().visits, [b]);
      expect(cubit.needsReload, isFalse);
    },
  );
  test('closing during global read ignores the completion', () async {
    final pending = Completer<Result<List<VetVisit>>>();
    when(repository.getAllVetVisits).thenAnswer((_) => pending.future);
    final read = cubit.loadAllVetVisits();
    await cubit.close();
    final closed = cubit.state;
    pending.complete(Success([a, b]));
    await read;
    expect(cubit.state, same(closed));
  });
  test('closing during global deletion does not repeat or emit', () async {
    await cubit.loadAllVetVisits();
    final pending = Completer<Result<void>>();
    when(() => repository.deleteVetVisit('a', 'a'))
        .thenAnswer((_) => pending.future);
    final write = cubit.deleteListedVisit(a);
    await cubit.close();
    final closed = cubit.state;
    pending.complete(const Success<void>(null));
    await write;
    expect(cubit.state, same(closed));
    verify(() => repository.deleteVetVisit('a', 'a')).called(1);
  });
}
