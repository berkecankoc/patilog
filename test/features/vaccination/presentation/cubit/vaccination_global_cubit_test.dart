import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';

class MockRepository extends Mock implements VaccinationRepository {}

void main() {
  Vaccination record(String owner, {String? id}) => Vaccination(
    id: id ?? owner,
    petId: owner,
    date: DateTime(2026, 10, 20),
    vaccineName: 'Rabies',
    status: VaccinationStatus.planned,
  );
  final a = record('a');
  final b = record('b');
  const failure = LocalDatabaseFailure('Try again');
  late MockRepository repository;
  late VaccinationCubit cubit;
  VaccinationsLoaded loaded() => cubit.state as VaccinationsLoaded;
  setUp(() {
    repository = MockRepository();
    when(repository.getAllVaccinations)
        .thenAnswer((_) async => Success([a, b]));
    when(() => repository.deleteVaccination(any(), any()))
        .thenAnswer((_) async => const Success<void>(null));
    cubit = VaccinationCubit(repository)..setPetContext(['a', 'b']);
  });
  tearDown(() => cubit.close());
  test(
    'the same feature Cubit reads all owners without a scoped query',
    () async {
      await cubit.loadAllVaccinations();
      expect(loaded().petId, isNull);
      expect(loaded().vaccinations, [a, b]);
      verify(repository.getAllVaccinations).called(1);
    },
  );
  test('canonical owner is used for deletion and no reread occurs', () async {
    await cubit.loadAllVaccinations();
    await cubit.deleteListedVaccination(b);
    expect(loaded().vaccinations, [a]);
    verify(() => repository.deleteVaccination('b', 'b')).called(1);
    verify(repository.getAllVaccinations).called(1);
  });
  test(
    'missing owner, forged owner, absent record and hidden filter are rejected',
    () async {
      await cubit.loadAllVaccinations();
      cubit.setPetContext(['a']);
      await cubit.deleteListedVaccination(b);
      await cubit.deleteListedVaccination(record('a', id: 'b'));
      await cubit.deleteListedVaccination(record('a', id: 'missing'));
      cubit.setPetContext(['a', 'b'], selectedPetId: 'a');
      await cubit.deleteListedVaccination(b);
      verifyNever(() => repository.deleteVaccination(any(), any()));
    },
  );
  test(
    'failed deletion retains content and intended target for explicit retry',
    () async {
      await cubit.loadAllVaccinations();
      when(() => repository.deleteVaccination('b', 'b'))
          .thenAnswer((_) async => const Error(failure));
      await cubit.deleteListedVaccination(b);
      expect(loaded().vaccinations, [a, b]);
      expect(loaded().deletionVaccination, b);
      expect(loaded().deleteError, 'Try again');
      when(() => repository.deleteVaccination('b', 'b'))
          .thenAnswer((_) async => const Success<void>(null));
      await cubit.deleteListedVaccination(loaded().deletionVaccination!);
      expect(loaded().vaccinations, [a]);
      expect(loaded().deleteError, isNull);
    },
  );
  test('pending deletion blocks repeated writes and reads', () async {
    await cubit.loadAllVaccinations();
    final pending = Completer<Result<void>>();
    when(() => repository.deleteVaccination('a', 'a'))
        .thenAnswer((_) => pending.future);
    final write = cubit.deleteListedVaccination(a);
    await cubit.deleteListedVaccination(b);
    await cubit.loadAllVaccinations();
    expect(loaded().isDeleting, isTrue);
    pending.complete(const Success<void>(null));
    await write;
    expect(loaded().vaccinations, [b]);
    verify(() => repository.deleteVaccination(any(), any())).called(1);
    verify(repository.getAllVaccinations).called(1);
  });
  for (final fails in [false, true]) {
    test(
      'known deletion survives a late ${fails ? 'failed' : 'successful'} refresh',
      () async {
        await cubit.loadAllVaccinations();
        final pending = Completer<Result<List<Vaccination>>>();
        when(repository.getAllVaccinations).thenAnswer((_) => pending.future);
        final refresh = cubit.loadAllVaccinations();
        cubit.removeDeletedVaccination('b', petId: 'b');
        pending.complete(fails ? const Error(failure) : Success([a, b]));
        await refresh;
        expect(loaded().vaccinations, [a]);
        expect(loaded().isRefreshing, isFalse);
        verify(repository.getAllVaccinations).called(2);
      },
    );
  }
  test('initial read reconciles known record and pet deletions', () async {
    final pending = Completer<Result<List<Vaccination>>>();
    when(repository.getAllVaccinations).thenAnswer((_) => pending.future);
    final read = cubit.loadAllVaccinations();
    cubit.removeDeletedVaccination('a', petId: 'a');
    cubit.removeDeletedPet('b');
    pending.complete(Success([a, b]));
    await read;
    expect(loaded().vaccinations, isEmpty);
  });
  test('external target deletion removes a stale failed retry', () async {
    await cubit.loadAllVaccinations();
    when(() => repository.deleteVaccination('b', 'b'))
        .thenAnswer((_) async => const Error(failure));
    await cubit.deleteListedVaccination(b);
    cubit.removeDeletedVaccination('b', petId: 'b');
    expect(loaded().deleteError, isNull);
    expect(loaded().deletionVaccination, isNull);
    expect(loaded().vaccinations, [a]);
  });
  test(
    'refresh failure retains content; invalidated old replies cannot win',
    () async {
      await cubit.loadAllVaccinations();
      when(repository.getAllVaccinations)
          .thenAnswer((_) async => const Error(failure));
      await cubit.loadAllVaccinations();
      expect(loaded().vaccinations, [a, b]);
      expect(loaded().refreshError, 'Try again');
      final pending = Completer<Result<List<Vaccination>>>();
      when(repository.getAllVaccinations).thenAnswer((_) => pending.future);
      final old = cubit.loadAllVaccinations();
      cubit.invalidateList();
      expect(cubit.needsReload, isTrue);
      when(repository.getAllVaccinations).thenAnswer((_) async => Success([b]));
      await cubit.loadAllVaccinations();
      pending.complete(Success([a]));
      await old;
      expect(loaded().vaccinations, [b]);
      expect(cubit.needsReload, isFalse);
    },
  );
  test('closing during global read ignores the completion', () async {
    final pending = Completer<Result<List<Vaccination>>>();
    when(repository.getAllVaccinations).thenAnswer((_) => pending.future);
    final read = cubit.loadAllVaccinations();
    await cubit.close();
    final closed = cubit.state;
    pending.complete(Success([a, b]));
    await read;
    expect(cubit.state, same(closed));
  });
  test('closing during global deletion does not repeat or emit', () async {
    await cubit.loadAllVaccinations();
    final pending = Completer<Result<void>>();
    when(() => repository.deleteVaccination('a', 'a'))
        .thenAnswer((_) => pending.future);
    final write = cubit.deleteListedVaccination(a);
    await cubit.close();
    final closed = cubit.state;
    pending.complete(const Success<void>(null));
    await write;
    expect(cubit.state, same(closed));
    verify(() => repository.deleteVaccination('a', 'a')).called(1);
  });
}
