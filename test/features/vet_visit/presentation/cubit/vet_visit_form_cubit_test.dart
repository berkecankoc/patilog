import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_state.dart';

class MockVetVisitRepository extends Mock implements VetVisitRepository {}

class MockIdGenerator extends Mock implements IdGenerator {}

void main() {
  late MockVetVisitRepository repository;
  late MockIdGenerator idGenerator;
  final visit = VetVisit(
    id: 'visit-1',
    petId: 'pet-1',
    visitedOn: DateTime(2026, 10, 15),
    reason: 'Checkup',
    clinicName: 'Clinic A',
    veterinarianName: 'Dr. Smith',
    diagnosis: 'Healthy',
    notes: 'Routine visit',
    costMinorUnits: 125050,
    currency: VetVisitCurrency.turkishLira,
  );
  const suggestions = VetVisitSuggestions(
    clinicNames: ['Clinic A', 'Clinic B'],
    veterinarianNames: ['Dr. Smith'],
  );
  const otherSuggestions = VetVisitSuggestions(
    clinicNames: ['Clinic A', 'Clinic B'],
    veterinarianNames: ['Dr. Jones'],
  );

  setUp(() {
    repository = MockVetVisitRepository();
    idGenerator = MockIdGenerator();
    when(() => idGenerator.generate()).thenReturn(visit.id);
  });

  VetVisitFormCubit makeCubit() => VetVisitFormCubit(repository, idGenerator);

  Future<void> save(VetVisitFormCubit cubit, {String? visitId}) =>
      cubit.saveVetVisit(
        visitId: visitId,
        petId: visit.petId,
        visitedOn: visit.visitedOn,
        reason: visit.reason,
        clinicName: visit.clinicName,
        veterinarianName: visit.veterinarianName,
        diagnosis: visit.diagnosis,
        notes: visit.notes,
        costMinorUnits: visit.costMinorUnits,
        currency: visit.currency,
      );

  test('starts with an idle form and empty suggestions', () {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    expect(cubit.state, const VetVisitFormState());
  });

  for (final (visitId, result, expected)
      in <(String?, Result<void>, VetVisitFormState)>[
        (null, const Success(null), const VetVisitFormState(isSaved: true)),
        (
          null,
          const Error(LocalDatabaseFailure('Save failed')),
          const VetVisitFormState(saveError: 'Save failed'),
        ),
        (visit.id, const Success(null), const VetVisitFormState(isSaved: true)),
        (
          visit.id,
          const Error(LocalDatabaseFailure('Update failed')),
          const VetVisitFormState(saveError: 'Update failed'),
        ),
        (
          visit.id,
          const Error(NotFoundFailure('Visit not found')),
          const VetVisitFormState(saveError: 'Visit not found'),
        ),
      ]) {
    blocTest<VetVisitFormCubit, VetVisitFormState>(
      '${visitId == null ? 'creates' : 'updates'} all visit fields and emits $expected',
      build: () {
        if (visitId == null) {
          when(
            () => repository.createVetVisit(visit),
          ).thenAnswer((_) async => result);
        } else {
          when(
            () => repository.updateVetVisit(visit),
          ).thenAnswer((_) async => result);
        }
        return makeCubit();
      },
      act: (cubit) => save(cubit, visitId: visitId),
      expect: () => [const VetVisitFormState(isSaving: true), expected],
      verify: (_) {
        if (visitId == null) {
          verify(() => idGenerator.generate()).called(1);
          verify(() => repository.createVetVisit(visit)).called(1);
          verifyNever(() => repository.updateVetVisit(visit));
        } else {
          verifyNever(() => idGenerator.generate());
          verify(() => repository.updateVetVisit(visit)).called(1);
          verifyNever(() => repository.createVetVisit(visit));
        }
      },
    );
  }

  test('blocks duplicate saves while pending and after success', () async {
    final pending = Completer<Result<void>>();
    when(
      () => repository.createVetVisit(visit),
    ).thenAnswer((_) => pending.future);
    final cubit = makeCubit();
    addTearDown(cubit.close);
    final first = save(cubit);
    await save(cubit);
    expect(cubit.state.isSaving, isTrue);
    pending.complete(const Success(null));
    await first;
    await save(cubit);
    expect(cubit.state.isSaved, isTrue);
    verify(() => repository.createVetVisit(visit)).called(1);
    verify(() => idGenerator.generate()).called(1);
  });

  test(
    'a failed save can retry and clears its previous error while pending',
    () async {
      when(() => repository.updateVetVisit(visit)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Save failed')),
      );
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await save(cubit, visitId: visit.id);
      expect(cubit.state.saveError, 'Save failed');
      final pending = Completer<Result<void>>();
      when(
        () => repository.updateVetVisit(visit),
      ).thenAnswer((_) => pending.future);
      final retry = save(cubit, visitId: visit.id);
      expect(cubit.state.isSaving, isTrue);
      expect(cubit.state.saveError, isNull);
      pending.complete(const Success(null));
      await retry;
      expect(cubit.state, const VetVisitFormState(isSaved: true));
      verify(() => repository.updateVetVisit(visit)).called(2);
      verifyNever(() => idGenerator.generate());
    },
  );

  for (final (result, expected)
      in <(Result<VetVisitSuggestions>, VetVisitFormState)>[
        (
          const Success(suggestions),
          const VetVisitFormState(suggestions: suggestions),
        ),
        (
          const Error(LocalDatabaseFailure('Suggestions failed')),
          const VetVisitFormState(suggestionsError: 'Suggestions failed'),
        ),
      ]) {
    blocTest<VetVisitFormCubit, VetVisitFormState>(
      'loads suggestions and emits $expected',
      build: () {
        when(
          () => repository.getSuggestions(clinicName: 'Clinic A'),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.loadSuggestions(clinicName: 'Clinic A'),
      expect: () => [
        const VetVisitFormState(isLoadingSuggestions: true),
        expected,
      ],
    );
  }

  test('a suggestion failure can be retried before saving', () async {
    when(() => repository.getSuggestions()).thenAnswer(
      (_) async => const Error(LocalDatabaseFailure('Suggestions failed')),
    );
    when(
      () => repository.createVetVisit(visit),
    ).thenAnswer((_) async => const Success(null));
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.loadSuggestions();
    expect(cubit.state.suggestionsError, 'Suggestions failed');
    final pending = Completer<Result<VetVisitSuggestions>>();
    when(() => repository.getSuggestions()).thenAnswer((_) => pending.future);
    final retry = cubit.loadSuggestions();
    expect(cubit.state.suggestionsError, isNull);
    pending.complete(const Success(suggestions));
    await retry;
    await save(cubit);
    expect(cubit.state.isSaved, isTrue);
    expect(cubit.state.suggestions, suggestions);
  });

  test('saving is available even while suggestions have an error', () async {
    when(() => repository.getSuggestions()).thenAnswer(
      (_) async => const Error(LocalDatabaseFailure('Suggestions failed')),
    );
    when(
      () => repository.createVetVisit(visit),
    ).thenAnswer((_) async => const Success(null));
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.loadSuggestions();
    await save(cubit);
    expect(cubit.state.isSaved, isTrue);
    expect(cubit.state.saveError, isNull);
    verify(() => repository.createVetVisit(visit)).called(1);
  });

  test(
    'clears stale veterinarians on clinic change and keeps the clinic list on error',
    () async {
      when(
        () => repository.getSuggestions(clinicName: 'Clinic A'),
      ).thenAnswer((_) async => const Success(suggestions));
      final pending = Completer<Result<VetVisitSuggestions>>();
      when(
        () => repository.getSuggestions(clinicName: 'Clinic B'),
      ).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadSuggestions(clinicName: 'Clinic A');
      final loading = cubit.loadSuggestions(clinicName: 'Clinic B');
      expect(cubit.state.suggestions.clinicNames, suggestions.clinicNames);
      expect(cubit.state.suggestions.veterinarianNames, isEmpty);
      pending.complete(const Error(LocalDatabaseFailure('Suggestions failed')));
      await loading;
      expect(cubit.state.suggestions.clinicNames, suggestions.clinicNames);
      expect(cubit.state.suggestions.veterinarianNames, isEmpty);
      expect(cubit.state.suggestionsError, 'Suggestions failed');
    },
  );

  for (final stale in <Result<VetVisitSuggestions>>[
    const Success(suggestions),
    const Error(LocalDatabaseFailure('Old request failed')),
  ]) {
    test('ignores a late $stale after a newer clinic result', () async {
      final pending = Completer<Result<VetVisitSuggestions>>();
      when(
        () => repository.getSuggestions(clinicName: 'Clinic A'),
      ).thenAnswer((_) => pending.future);
      when(
        () => repository.getSuggestions(clinicName: 'Clinic B'),
      ).thenAnswer((_) async => const Success(otherSuggestions));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final oldRequest = cubit.loadSuggestions(clinicName: 'Clinic A');
      await cubit.loadSuggestions(clinicName: 'Clinic B');
      pending.complete(stale);
      await oldRequest;
      expect(
        cubit.state,
        const VetVisitFormState(suggestions: otherSuggestions),
      );
    });
  }

  test(
    'suggestion responses cannot reset a pending save or erase its failure',
    () async {
      final suggestionsPending = Completer<Result<VetVisitSuggestions>>();
      final savePending = Completer<Result<void>>();
      when(
        () => repository.getSuggestions(),
      ).thenAnswer((_) => suggestionsPending.future);
      when(
        () => repository.createVetVisit(visit),
      ).thenAnswer((_) => savePending.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final loading = cubit.loadSuggestions();
      final saving = save(cubit);
      suggestionsPending.complete(const Success(suggestions));
      await loading;
      expect(cubit.state.isSaving, isTrue);
      expect(cubit.state.suggestions, suggestions);
      savePending.complete(const Error(LocalDatabaseFailure('Save failed')));
      await saving;
      when(() => repository.getSuggestions()).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Suggestions failed')),
      );
      await cubit.loadSuggestions();
      expect(cubit.state.saveError, 'Save failed');
      expect(cubit.state.suggestionsError, 'Suggestions failed');
      expect(cubit.state.isSaved, isFalse);
    },
  );

  test(
    'successful save is terminal even if a suggestion response arrives later',
    () async {
      final pending = Completer<Result<VetVisitSuggestions>>();
      when(() => repository.getSuggestions()).thenAnswer((_) => pending.future);
      when(
        () => repository.createVetVisit(visit),
      ).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final states = <VetVisitFormState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);
      final loading = cubit.loadSuggestions();
      await save(cubit);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isSaved, isTrue);
      expect(cubit.state.isLoadingSuggestions, isFalse);
      final stateCount = states.length;
      pending.complete(const Success(suggestions));
      await loading;
      await cubit.loadSuggestions();
      await Future<void>.delayed(Duration.zero);
      expect(states, hasLength(stateCount));
      verify(() => repository.getSuggestions()).called(1);
    },
  );

  test(
    'does not emit or start work after closing during save and suggestions',
    () async {
      final savePending = Completer<Result<void>>();
      final suggestionsPending = Completer<Result<VetVisitSuggestions>>();
      when(
        () => repository.createVetVisit(visit),
      ).thenAnswer((_) => savePending.future);
      when(
        () => repository.getSuggestions(),
      ).thenAnswer((_) => suggestionsPending.future);
      final cubit = makeCubit();
      final saving = save(cubit);
      final loading = cubit.loadSuggestions();
      await cubit.close();
      savePending.complete(const Success(null));
      suggestionsPending.complete(const Success(suggestions));
      await expectLater(Future.wait([saving, loading]), completes);
      clearInteractions(repository);
      clearInteractions(idGenerator);
      await save(cubit);
      await cubit.loadSuggestions();
      verifyZeroInteractions(repository);
      verifyZeroInteractions(idGenerator);
    },
  );
}
