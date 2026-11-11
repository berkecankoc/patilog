import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';
import 'package:patilog/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_state.dart';

class MockVaccinationRepository extends Mock implements VaccinationRepository {}

void main() {
  late MockVaccinationRepository repository;
  final vaccination = Vaccination(
    status: VaccinationStatus.administered,
    id: 'vaccination-1',
    petId: 'pet-1',
    date: DateTime(2026, 10, 15),
    vaccineName: 'Rabies',
  );
  final older = Vaccination(
    status: VaccinationStatus.administered,
    id: 'older',
    petId: vaccination.petId,
    date: DateTime(2026, 10, 14),
    vaccineName: 'Booster',
  );
  final corrected = Vaccination(
    status: VaccinationStatus.administered,
    id: vaccination.id,
    petId: vaccination.petId,
    date: vaccination.date,
    vaccineName: 'Rabies (corrected)',
  );

  setUp(() => repository = MockVaccinationRepository());
  VaccinationCubit makeCubit() => VaccinationCubit(repository);

  blocTest<VaccinationCubit, VaccinationState>(
    'does not retain a vaccination removed through nested navigation',
    build: () {
      when(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      ).thenAnswer(
        (_) async => const Error(NotFoundFailure('Vaccination not found')),
      );
      return makeCubit();
    },
    seed: () => VaccinationLoaded(vaccination),
    act: (cubit) => cubit.loadVaccination(vaccination.petId, vaccination.id),
    expect: () => [
      VaccinationLoaded(vaccination, isRefreshing: true),
      const VaccinationError(NotFoundFailure('Vaccination not found')),
    ],
  );

  test(
    'visit scopes preserve refresh content, retry and discard stale loads',
    () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);
      when(
        () => repository.getVaccinations('pet-1', vetVisitId: 'visit-1'),
      ).thenAnswer((_) async => Success([vaccination]));
      await cubit.loadVaccinations('pet-1', vetVisitId: 'visit-1');
      expect(
        cubit.state,
        VaccinationsLoaded('pet-1', [vaccination], vetVisitId: 'visit-1'),
      );
      when(
        () => repository.getVaccinations('pet-1', vetVisitId: 'visit-1'),
      ).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Retry linked records')),
      );
      await cubit.loadVaccinations('pet-1', vetVisitId: 'visit-1');
      expect(
        cubit.state,
        VaccinationsLoaded(
          'pet-1',
          [vaccination],
          vetVisitId: 'visit-1',
          refreshError: 'Retry linked records',
        ),
      );
      final pending = Completer<Result<List<Vaccination>>>();
      when(
        () => repository.getVaccinations('pet-1', vetVisitId: 'visit-1'),
      ).thenAnswer((_) => pending.future);
      final old = cubit.loadVaccinations('pet-1', vetVisitId: 'visit-1');
      when(
        () => repository.getVaccinations('pet-1', vetVisitId: 'visit-2'),
      ).thenAnswer((_) async => const Success([]));
      await cubit.loadVaccinations('pet-1', vetVisitId: 'visit-2');
      pending.complete(Success([vaccination]));
      await old;
      expect(
        cubit.state,
        const VaccinationsLoaded('pet-1', [], vetVisitId: 'visit-2'),
      );
      verifyNever(() => repository.getVaccinations('pet-1'));
    },
  );

  test('a linked read completing after close does not emit', () async {
    final pending = Completer<Result<List<Vaccination>>>();
    when(
      () => repository.getVaccinations('pet-1', vetVisitId: 'visit-1'),
    ).thenAnswer((_) => pending.future);
    final cubit = makeCubit();
    final load = cubit.loadVaccinations('pet-1', vetVisitId: 'visit-1');
    await cubit.close();
    pending.complete(const Success([]));
    await load;
    expect(cubit.state, const VaccinationLoading());
  });

  test('starts in the initial state', () {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    expect(cubit.state, const VaccinationInitial());
  });

  for (final vaccinations in <List<Vaccination>>[
    [],
    [vaccination, older],
  ]) {
    blocTest<VaccinationCubit, VaccinationState>(
      'loads ${vaccinations.length} vaccinations without changing order',
      build: () {
        when(
          () => repository.getVaccinations(vaccination.petId),
        ).thenAnswer((_) async => Success(vaccinations));
        return makeCubit();
      },
      act: (cubit) => cubit.loadVaccinations(vaccination.petId),
      expect: () => [
        const VaccinationLoading(),
        VaccinationsLoaded(vaccination.petId, vaccinations),
      ],
    );
  }

  blocTest<VaccinationCubit, VaccinationState>(
    'reports an initial list failure',
    build: () {
      when(() => repository.getVaccinations(vaccination.petId)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Load failed')),
      );
      return makeCubit();
    },
    act: (cubit) => cubit.loadVaccinations(vaccination.petId),
    expect: () => [
      const VaccinationLoading(),
      const VaccinationError(LocalDatabaseFailure('Load failed')),
    ],
  );

  blocTest<VaccinationCubit, VaccinationState>(
    'keeps the loaded list on refresh failure and can retry',
    build: () {
      when(() => repository.getVaccinations(vaccination.petId)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Refresh failed')),
      );
      return makeCubit();
    },
    seed: () => VaccinationsLoaded(vaccination.petId, [vaccination, older]),
    act: (cubit) async {
      await cubit.loadVaccinations(vaccination.petId);
      when(
        () => repository.getVaccinations(vaccination.petId),
      ).thenAnswer((_) async => Success([vaccination]));
      await cubit.loadVaccinations(vaccination.petId);
    },
    expect: () => [
      VaccinationsLoaded(vaccination.petId, [
        vaccination,
        older,
      ], isRefreshing: true),
      VaccinationsLoaded(vaccination.petId, [
        vaccination,
        older,
      ], refreshError: 'Refresh failed'),
      VaccinationsLoaded(vaccination.petId, [
        vaccination,
        older,
      ], isRefreshing: true),
      VaccinationsLoaded(vaccination.petId, [vaccination]),
    ],
  );

  for (final (result, expected) in <(Result<Vaccination>, VaccinationState)>[
    (Success(vaccination), VaccinationLoaded(vaccination)),
    (
      const Error(NotFoundFailure('Vaccination not found')),
      const VaccinationError(NotFoundFailure('Vaccination not found')),
    ),
    (
      const Error(LocalDatabaseFailure('Load failed')),
      const VaccinationError(LocalDatabaseFailure('Load failed')),
    ),
  ]) {
    blocTest<VaccinationCubit, VaccinationState>(
      'loads scoped detail and emits $expected',
      build: () {
        when(
          () =>
              repository.getVaccinationById(vaccination.petId, vaccination.id),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.loadVaccination(vaccination.petId, vaccination.id),
      expect: () => [const VaccinationLoading(), expected],
      verify: (_) => verify(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      ).called(1),
    );
  }

  blocTest<VaccinationCubit, VaccinationState>(
    'keeps detail on refresh failure and replaces it on successful retry',
    build: () {
      when(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      ).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Refresh failed')),
      );
      return makeCubit();
    },
    seed: () => VaccinationLoaded(vaccination),
    act: (cubit) async {
      await cubit.loadVaccination(vaccination.petId, vaccination.id);
      when(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      ).thenAnswer((_) async => Success(corrected));
      await cubit.loadVaccination(vaccination.petId, vaccination.id);
    },
    expect: () => [
      VaccinationLoaded(vaccination, isRefreshing: true),
      VaccinationLoaded(vaccination, refreshError: 'Refresh failed'),
      VaccinationLoaded(vaccination, isRefreshing: true),
      VaccinationLoaded(corrected),
    ],
  );

  for (final (result, expected) in <(Result<void>, VaccinationState)>[
    (const Success(null), VaccinationDeleted(vaccination.id)),
    (
      const Error(LocalDatabaseFailure('Delete failed')),
      VaccinationLoaded(vaccination, deleteError: 'Delete failed'),
    ),
    (
      const Error(NotFoundFailure('Vaccination not found')),
      VaccinationLoaded(vaccination, deleteError: 'Vaccination not found'),
    ),
  ]) {
    blocTest<VaccinationCubit, VaccinationState>(
      'deletes the loaded vaccination and emits $expected without rereading',
      build: () {
        when(
          () => repository.deleteVaccination(vaccination.petId, vaccination.id),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      seed: () => VaccinationLoaded(vaccination),
      act: (cubit) => cubit.deleteVaccination(),
      expect: () => [
        VaccinationLoaded(vaccination, isDeleting: true),
        expected,
      ],
      verify: (_) {
        verify(
          () => repository.deleteVaccination(vaccination.petId, vaccination.id),
        ).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  blocTest<VaccinationCubit, VaccinationState>(
    'retrying deletion clears its old error and can succeed',
    build: () {
      when(
        () => repository.deleteVaccination(vaccination.petId, vaccination.id),
      ).thenAnswer((_) async => const Success(null));
      return makeCubit();
    },
    seed: () => VaccinationLoaded(vaccination, deleteError: 'Delete failed'),
    act: (cubit) => cubit.deleteVaccination(),
    expect: () => [
      VaccinationLoaded(vaccination, isDeleting: true),
      VaccinationDeleted(vaccination.id),
    ],
  );

  test(
    'a newer pet load wins over an older response without showing old data',
    () async {
      final first = Completer<Result<List<Vaccination>>>();
      final second = Completer<Result<List<Vaccination>>>();
      when(
        () => repository.getVaccinations(vaccination.petId),
      ).thenAnswer((_) => first.future);
      when(
        () => repository.getVaccinations('pet-2'),
      ).thenAnswer((_) => second.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final firstLoad = cubit.loadVaccinations(vaccination.petId);
      final secondLoad = cubit.loadVaccinations('pet-2');
      second.complete(const Success([]));
      await secondLoad;
      first.complete(Success([vaccination]));
      await firstLoad;
      expect(cubit.state, const VaccinationsLoaded('pet-2', []));

      when(() => repository.getVaccinations(vaccination.petId)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Load failed')),
      );
      await cubit.loadVaccinations(vaccination.petId);
      expect(
        cubit.state,
        const VaccinationError(LocalDatabaseFailure('Load failed')),
      );
    },
  );

  test(
    'the latest detail request wins when reads complete out of order',
    () async {
      final first = Completer<Result<Vaccination>>();
      when(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      ).thenAnswer((_) => first.future);
      when(
        () => repository.getVaccinationById(older.petId, older.id),
      ).thenAnswer((_) async => Success(older));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final oldLoad = cubit.loadVaccination(vaccination.petId, vaccination.id);
      await cubit.loadVaccination(older.petId, older.id);
      first.complete(Success(vaccination));
      await oldLoad;
      expect(cubit.state, VaccinationLoaded(older));
    },
  );

  test(
    'pending deletion blocks duplicate writes and invalidates an old refresh',
    () async {
      when(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      ).thenAnswer((_) async => Success(vaccination));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadVaccination(vaccination.petId, vaccination.id);
      final refresh = Completer<Result<Vaccination>>();
      when(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      ).thenAnswer((_) => refresh.future);
      final oldRefresh = cubit.loadVaccination(
        vaccination.petId,
        vaccination.id,
      );
      final deletion = Completer<Result<void>>();
      when(
        () => repository.deleteVaccination(vaccination.petId, vaccination.id),
      ).thenAnswer((_) => deletion.future);
      final deleting = cubit.deleteVaccination();
      await cubit.deleteVaccination();
      await cubit.loadVaccination(vaccination.petId, vaccination.id);
      await cubit.loadVaccinations(vaccination.petId);
      refresh.complete(Success(vaccination));
      await oldRefresh;
      expect(cubit.state, VaccinationLoaded(vaccination, isDeleting: true));
      deletion.complete(const Success(null));
      await deleting;
      await cubit.loadVaccination(vaccination.petId, vaccination.id);
      await cubit.deleteVaccination();
      expect(cubit.state, VaccinationDeleted(vaccination.id));
      verify(
        () => repository.deleteVaccination(vaccination.petId, vaccination.id),
      ).called(1);
      verify(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      ).called(2);
      verifyNever(() => repository.getVaccinations(vaccination.petId));
    },
  );

  test(
    'applies a known deletion locally and ignores an outstanding stale list',
    () async {
      when(
        () => repository.getVaccinations(vaccination.petId),
      ).thenAnswer((_) async => Success([vaccination, older]));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadVaccinations(vaccination.petId);
      final refresh = Completer<Result<List<Vaccination>>>();
      when(
        () => repository.getVaccinations(vaccination.petId),
      ).thenAnswer((_) => refresh.future);
      final oldRefresh = cubit.loadVaccinations(vaccination.petId);
      cubit.removeDeletedVaccination(vaccination.id);
      expect(cubit.state, VaccinationsLoaded(vaccination.petId, [older]));
      refresh.complete(Success([vaccination, older]));
      await oldRefresh;
      expect(cubit.state, VaccinationsLoaded(vaccination.petId, [older]));
      verify(() => repository.getVaccinations(vaccination.petId)).called(2);
      verifyNever(
        () => repository.deleteVaccination(vaccination.petId, vaccination.id),
      );
    },
  );

  for (final (result, error) in <(Result<void>, String?)>[
    (const Success(null), null),
    (const Error(LocalDatabaseFailure('Delete failed')), 'Delete failed'),
    (
      const Error(NotFoundFailure('Vaccination not found')),
      'Vaccination not found',
    ),
  ]) {
    blocTest<VaccinationCubit, VaccinationState>(
      'list deletion retains rows while pending and maps $result',
      build: () {
        when(
          () => repository.deleteVaccination(vaccination.petId, vaccination.id),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      seed: () => VaccinationsLoaded(vaccination.petId, [vaccination, older]),
      act: (cubit) => cubit.deleteListedVaccination(vaccination),
      expect: () => [
        VaccinationsLoaded(
          vaccination.petId,
          [vaccination, older],
          isDeleting: true,
          deletionVaccination: vaccination,
        ),
        if (error == null)
          VaccinationsLoaded(vaccination.petId, [older])
        else
          VaccinationsLoaded(
            vaccination.petId,
            [vaccination, older],
            deletionVaccination: vaccination,
            deleteError: error,
          ),
      ],
      verify: (_) {
        verify(
          () => repository.deleteVaccination(vaccination.petId, vaccination.id),
        ).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  test(
    'pending list deletion blocks other writes and refreshes and can retry after failure',
    () async {
      when(
        () => repository.getVaccinations(vaccination.petId),
      ).thenAnswer((_) async => Success([vaccination, older]));
      final pending = Completer<Result<void>>();
      when(
        () => repository.deleteVaccination(vaccination.petId, vaccination.id),
      ).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadVaccinations(vaccination.petId);
      final deleting = cubit.deleteListedVaccination(vaccination);
      await cubit.deleteListedVaccination(vaccination);
      await cubit.deleteListedVaccination(older);
      await cubit.loadVaccinations(vaccination.petId);
      await cubit.loadVaccination(vaccination.petId, vaccination.id);
      pending.complete(const Error(LocalDatabaseFailure('Delete failed')));
      await deleting;
      when(
        () => repository.deleteVaccination(vaccination.petId, vaccination.id),
      ).thenAnswer((_) async => const Success(null));
      await cubit.deleteListedVaccination(vaccination);
      expect(cubit.state, VaccinationsLoaded(vaccination.petId, [older]));
      verify(
        () => repository.deleteVaccination(vaccination.petId, vaccination.id),
      ).called(2);
      verify(() => repository.getVaccinations(vaccination.petId)).called(1);
      verifyNever(() => repository.deleteVaccination(older.petId, older.id));
      verifyNever(
        () => repository.getVaccinationById(vaccination.petId, vaccination.id),
      );
    },
  );

  test(
    'list deletion ignores IDs that are missing or belong to another pet',
    () async {
      when(
        () => repository.getVaccinations(vaccination.petId),
      ).thenAnswer((_) async => Success([vaccination]));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadVaccinations(vaccination.petId);
      clearInteractions(repository);
      await cubit.deleteListedVaccination(older);
      await cubit.deleteListedVaccination(
        Vaccination(
          status: VaccinationStatus.administered,
          id: vaccination.id,
          petId: 'pet-2',
          date: vaccination.date,
          vaccineName: vaccination.vaccineName,
        ),
      );
      expect(cubit.state, VaccinationsLoaded(vaccination.petId, [vaccination]));
      verifyZeroInteractions(repository);
    },
  );

  for (final operation in ['list', 'detail', 'delete', 'list-delete']) {
    test(
      'does not emit when pending $operation completes after close',
      () async {
        final cubit = makeCubit();
        final pendingList = Completer<Result<List<Vaccination>>>();
        final pendingDetail = Completer<Result<Vaccination>>();
        final pendingDelete = Completer<Result<void>>();
        when(
          () => repository.getVaccinations(vaccination.petId),
        ).thenAnswer((_) => pendingList.future);
        when(
          () =>
              repository.getVaccinationById(vaccination.petId, vaccination.id),
        ).thenAnswer((_) async => Success(vaccination));
        when(
          () => repository.deleteVaccination(vaccination.petId, vaccination.id),
        ).thenAnswer((_) => pendingDelete.future);
        if (operation == 'delete') {
          await cubit.loadVaccination(vaccination.petId, vaccination.id);
        }
        if (operation == 'list-delete') {
          when(
            () => repository.getVaccinations(vaccination.petId),
          ).thenAnswer((_) async => Success([vaccination]));
          await cubit.loadVaccinations(vaccination.petId);
        }
        when(
          () =>
              repository.getVaccinationById(vaccination.petId, vaccination.id),
        ).thenAnswer((_) => pendingDetail.future);
        final work = switch (operation) {
          'list' => cubit.loadVaccinations(vaccination.petId),
          'detail' => cubit.loadVaccination(vaccination.petId, vaccination.id),
          'list-delete' => cubit.deleteListedVaccination(vaccination),
          _ => cubit.deleteVaccination(),
        };
        await cubit.close();
        pendingList.complete(Success([vaccination]));
        pendingDetail.complete(Success(vaccination));
        pendingDelete.complete(const Success(null));
        await expectLater(work, completes);
        clearInteractions(repository);
        await cubit.loadVaccinations(vaccination.petId);
        await cubit.loadVaccination(vaccination.petId, vaccination.id);
        await cubit.deleteVaccination();
        await cubit.deleteListedVaccination(vaccination);
        cubit.removeDeletedVaccination(vaccination.id);
        verifyZeroInteractions(repository);
      },
    );
  }
}
