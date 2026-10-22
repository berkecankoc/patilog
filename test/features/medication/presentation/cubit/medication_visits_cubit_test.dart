import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_visits_cubit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';

class MockVisits extends Mock implements VetVisitRepository {}

void main() {
  test(
    'linked visits load independently, retain data on failure and ignore stale responses',
    () async {
      final repository = MockVisits();
      final cubit = MedicationVisitsCubit(repository);
      final first = VetVisit(
        id: 'one',
        petId: 'pet',
        visitedOn: DateTime(2026, 10, 20),
        reason: 'First',
      );
      final second = VetVisit(
        id: 'two',
        petId: 'pet',
        visitedOn: first.visitedOn,
        reason: 'Second',
      );
      when(
        () => repository.getVetVisitById('pet', 'one'),
      ).thenAnswer((_) async => Success(first));
      when(
        () => repository.getVetVisitById('pet', 'two'),
      ).thenAnswer((_) async => Success(second));
      await cubit.loadVisit('pet', 'one');
      await cubit.loadVisit('pet', 'two');
      expect((cubit.state['one'] as VetVisitLoaded).visit, first);
      expect((cubit.state['two'] as VetVisitLoaded).visit, second);
      when(
        () => repository.getVetVisitById('pet', 'one'),
      ).thenAnswer((_) async => const Error(LocalDatabaseFailure('Failed')));
      await cubit.loadVisit('pet', 'one');
      expect((cubit.state['one'] as VetVisitLoaded).visit, first);
      expect((cubit.state['one'] as VetVisitLoaded).refreshError, 'Failed');
      final pending = Completer<Result<VetVisit>>();
      when(
        () => repository.getVetVisitById('pet', 'one'),
      ).thenAnswer((_) => pending.future);
      final read = cubit.loadVisit('pet', 'one');
      when(
        () => repository.getVetVisitById('other', 'two'),
      ).thenAnswer((_) async => Success(second));
      await cubit.loadVisit('other', 'two');
      when(
        () => repository.getVetVisitById('pet', 'one'),
      ).thenAnswer((_) async => Success(first));
      await cubit.loadVisit('pet', 'one');
      pending.complete(const Error(LocalDatabaseFailure('Stale')));
      await read;
      expect((cubit.state['one'] as VetVisitLoaded).refreshError, isNull);
      await cubit.close();
    },
  );

  test('closed cubit ignores pending visit lookup', () async {
    final repository = MockVisits();
    final cubit = MedicationVisitsCubit(repository);
    final result = Completer<Result<VetVisit>>();
    when(
      () => repository.getVetVisitById('pet', 'one'),
    ).thenAnswer((_) => result.future);
    final loading = cubit.loadVisit('pet', 'one');
    await cubit.close();
    result.complete(const Error(LocalDatabaseFailure('Failed')));
    await loading;
    expect(cubit.isClosed, true);
  });
}
