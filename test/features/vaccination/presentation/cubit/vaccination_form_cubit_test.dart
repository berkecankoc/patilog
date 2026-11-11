import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:patilog/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:patilog/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_form_state.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:patilog/features/vet_visit/domain/repositories/vet_visit_repository.dart';

class MockVaccinationRepository extends Mock implements VaccinationRepository {}

class MockVetVisitRepository extends Mock implements VetVisitRepository {}

class MockSaveVaccination extends Mock implements SaveVaccination {}

void main() {
  late MockVaccinationRepository repository;
  late MockVetVisitRepository visitRepository;
  late MockSaveVaccination save;
  final params = SaveVaccinationParams(
    petId: 'pet-1',
    vaccineName: 'Rabies',
    status: VaccinationStatus.administered,
    date: DateTime(2020, 1, 2),
  );
  final visit = VetVisit(
    id: 'visit-1',
    petId: 'pet-1',
    visitedOn: params.date,
    reason: 'Checkup',
  );
  final otherVisit = VetVisit(
    id: 'visit-2',
    petId: 'pet-2',
    visitedOn: params.date,
    reason: 'Checkup',
  );
  const suggestions = VaccinationSuggestions(
    vaccineNames: ['Rabies'],
    clinicNames: ['Clinic A', 'Clinic B'],
    veterinarianNames: ['Dr. Smith'],
  );
  const otherSuggestions = VaccinationSuggestions(
    vaccineNames: ['Rabies'],
    clinicNames: ['Clinic A', 'Clinic B'],
    veterinarianNames: ['Dr. Jones'],
  );

  VaccinationFormCubit makeCubit() =>
      VaccinationFormCubit(repository, visitRepository, save);

  setUp(() {
    repository = MockVaccinationRepository();
    visitRepository = MockVetVisitRepository();
    save = MockSaveVaccination();
  });

  test('starts with an idle form and no options', () {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    expect(cubit.state, const VaccinationFormState());
  });

  for (final (result, expected) in <(Result<void>, VaccinationFormState)>[
    (const Success(null), const VaccinationFormState(isSaved: true)),
    (
      const Error(LocalDatabaseFailure('Save failed')),
      const VaccinationFormState(saveError: 'Save failed'),
    ),
    (
      const Error(NotFoundFailure('Vaccination not found')),
      const VaccinationFormState(saveError: 'Vaccination not found'),
    ),
  ]) {
    blocTest<VaccinationFormCubit, VaccinationFormState>(
      'saves through the use case and maps $result',
      build: () {
        when(() => save(params)).thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.saveVaccination(params),
      expect: () => [const VaccinationFormState(isSaving: true), expected],
      verify: (_) => verify(() => save(params)).called(1),
    );
  }

  test('blocks duplicate saves while pending and after success', () async {
    final pending = Completer<Result<void>>();
    when(() => save(params)).thenAnswer((_) => pending.future);
    final cubit = makeCubit();
    addTearDown(cubit.close);
    final first = cubit.saveVaccination(params);
    await cubit.saveVaccination(params);
    expect(cubit.state.isSaving, isTrue);
    pending.complete(const Success(null));
    await first;
    await cubit.saveVaccination(params);
    expect(cubit.state.isSaved, isTrue);
    verify(() => save(params)).called(1);
  });

  test(
    'a failed save can retry and clears its old error while pending',
    () async {
      when(() => save(params)).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Save failed')),
      );
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.saveVaccination(params);
      expect(cubit.state.saveError, 'Save failed');
      final pending = Completer<Result<void>>();
      when(() => save(params)).thenAnswer((_) => pending.future);
      final retry = cubit.saveVaccination(params);
      expect(cubit.state.isSaving, isTrue);
      expect(cubit.state.saveError, isNull);
      pending.complete(const Success(null));
      await retry;
      expect(cubit.state, const VaccinationFormState(isSaved: true));
      verify(() => save(params)).called(2);
    },
  );

  for (final (result, expected)
      in <(Result<VaccinationSuggestions>, VaccinationFormState)>[
        (
          const Success(suggestions),
          const VaccinationFormState(suggestions: suggestions),
        ),
        (
          const Error(LocalDatabaseFailure('Suggestions failed')),
          const VaccinationFormState(suggestionsError: 'Suggestions failed'),
        ),
      ]) {
    blocTest<VaccinationFormCubit, VaccinationFormState>(
      'loads suggestions for the clinic and maps $result',
      build: () {
        when(
          () => repository.getSuggestions(clinicName: 'Clinic A'),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.loadSuggestions(clinicName: 'Clinic A'),
      expect: () => [
        const VaccinationFormState(isLoadingSuggestions: true),
        expected,
      ],
    );
  }

  for (final (result, expected)
      in <(Result<List<VetVisit>>, VaccinationFormState)>[
        (
          Success([visit]),
          VaccinationFormState(visitsPetId: 'pet-1', visits: [visit]),
        ),
        (const Success([]), const VaccinationFormState(visitsPetId: 'pet-1')),
        (
          const Error(LocalDatabaseFailure('Visits failed')),
          const VaccinationFormState(
            visitsPetId: 'pet-1',
            visitsError: 'Visits failed',
          ),
        ),
      ]) {
    blocTest<VaccinationFormCubit, VaccinationFormState>(
      'loads this pet visit options and maps $result',
      build: () {
        when(
          () => visitRepository.getVetVisits('pet-1'),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.loadVisits('pet-1'),
      expect: () => [
        const VaccinationFormState(visitsPetId: 'pet-1', isLoadingVisits: true),
        expected,
      ],
      verify: (_) =>
          verify(() => visitRepository.getVetVisits('pet-1')).called(1),
    );
  }

  test(
    'clinic changes clear old vets, keep other names and allow retry after failure',
    () async {
      when(
        () => repository.getSuggestions(clinicName: 'Clinic A'),
      ).thenAnswer((_) async => const Success(suggestions));
      final pending = Completer<Result<VaccinationSuggestions>>();
      when(
        () => repository.getSuggestions(clinicName: 'Clinic B'),
      ).thenAnswer((_) => pending.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadSuggestions(clinicName: 'Clinic A');
      final loading = cubit.loadSuggestions(clinicName: 'Clinic B');
      expect(cubit.state.suggestions.vaccineNames, suggestions.vaccineNames);
      expect(cubit.state.suggestions.clinicNames, suggestions.clinicNames);
      expect(cubit.state.suggestions.veterinarianNames, isEmpty);
      pending.complete(const Error(LocalDatabaseFailure('Suggestions failed')));
      await loading;
      expect(cubit.state.suggestionsError, 'Suggestions failed');
      when(
        () => repository.getSuggestions(clinicName: 'Clinic B'),
      ).thenAnswer((_) async => const Success(otherSuggestions));
      await cubit.loadSuggestions(clinicName: 'Clinic B');
      expect(cubit.state.suggestions, otherSuggestions);
      expect(cubit.state.suggestionsError, isNull);
    },
  );

  test(
    'visit refresh retains same-pet options but clears another pet options',
    () async {
      when(
        () => visitRepository.getVetVisits('pet-1'),
      ).thenAnswer((_) async => Success([visit]));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.loadVisits('pet-1');
      final refresh = Completer<Result<List<VetVisit>>>();
      when(
        () => visitRepository.getVetVisits('pet-1'),
      ).thenAnswer((_) => refresh.future);
      final loading = cubit.loadVisits('pet-1');
      expect(cubit.state.visits, [visit]);
      refresh.complete(const Error(LocalDatabaseFailure('Visits failed')));
      await loading;
      expect(cubit.state.visits, [visit]);
      expect(cubit.state.visitsError, 'Visits failed');
      final other = Completer<Result<List<VetVisit>>>();
      when(
        () => visitRepository.getVetVisits('pet-2'),
      ).thenAnswer((_) => other.future);
      final switching = cubit.loadVisits('pet-2');
      expect(cubit.state.visits, isEmpty);
      expect(cubit.state.visitsPetId, 'pet-2');
      expect(cubit.state.visitsError, isNull);
      other.complete(Success([otherVisit]));
      await switching;
      expect(cubit.state.visits, [otherVisit]);
    },
  );

  for (final stale in <Result<VaccinationSuggestions>>[
    const Success(suggestions),
    const Error(LocalDatabaseFailure('Stale suggestions failed')),
  ]) {
    test('ignores late suggestions $stale from a previous clinic', () async {
      final pending = Completer<Result<VaccinationSuggestions>>();
      when(
        () => repository.getSuggestions(clinicName: 'Clinic A'),
      ).thenAnswer((_) => pending.future);
      when(
        () => repository.getSuggestions(clinicName: 'Clinic B'),
      ).thenAnswer((_) async => const Success(otherSuggestions));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final old = cubit.loadSuggestions(clinicName: 'Clinic A');
      await cubit.loadSuggestions(clinicName: 'Clinic B');
      pending.complete(stale);
      await old;
      expect(cubit.state.suggestions, otherSuggestions);
      expect(cubit.state.suggestionsError, isNull);
    });
  }

  for (final stale in <Result<List<VetVisit>>>[
    Success([visit]),
    const Error(LocalDatabaseFailure('Stale visits failed')),
  ]) {
    test('ignores late visits $stale after switching pets', () async {
      final pending = Completer<Result<List<VetVisit>>>();
      when(
        () => visitRepository.getVetVisits('pet-1'),
      ).thenAnswer((_) => pending.future);
      when(
        () => visitRepository.getVetVisits('pet-2'),
      ).thenAnswer((_) async => Success([otherVisit]));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final old = cubit.loadVisits('pet-1');
      await cubit.loadVisits('pet-2');
      pending.complete(stale);
      await old;
      expect(cubit.state.visitsPetId, 'pet-2');
      expect(cubit.state.visits, [otherVisit]);
      expect(cubit.state.visitsError, isNull);
    });
  }

  test('option failures do not prevent saving and both can retry', () async {
    when(() => repository.getSuggestions()).thenAnswer(
      (_) async => const Error(LocalDatabaseFailure('Suggestions failed')),
    );
    when(() => visitRepository.getVetVisits('pet-1')).thenAnswer(
      (_) async => const Error(LocalDatabaseFailure('Visits failed')),
    );
    when(
      () => save(params),
    ).thenAnswer((_) async => const Error(LocalDatabaseFailure('Save failed')));
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.loadSuggestions();
    await cubit.loadVisits('pet-1');
    await cubit.saveVaccination(params);
    expect(cubit.state.saveError, 'Save failed');
    when(
      () => repository.getSuggestions(),
    ).thenAnswer((_) async => const Success(suggestions));
    when(
      () => visitRepository.getVetVisits('pet-1'),
    ).thenAnswer((_) async => Success([visit]));
    await cubit.loadSuggestions();
    await cubit.loadVisits('pet-1');
    expect(cubit.state.saveError, 'Save failed');
    expect(cubit.state.suggestionsError, isNull);
    expect(cubit.state.visitsError, isNull);
    when(() => save(params)).thenAnswer((_) async => const Success(null));
    await cubit.saveVaccination(params);
    expect(cubit.state.isSaved, isTrue);
    expect(cubit.state.suggestions, suggestions);
    expect(cubit.state.visits, [visit]);
  });

  test(
    'option responses do not reset a pending save or erase its failure',
    () async {
      final pendingSuggestions = Completer<Result<VaccinationSuggestions>>();
      final pendingVisits = Completer<Result<List<VetVisit>>>();
      final pendingSave = Completer<Result<void>>();
      when(
        () => repository.getSuggestions(),
      ).thenAnswer((_) => pendingSuggestions.future);
      when(
        () => visitRepository.getVetVisits('pet-1'),
      ).thenAnswer((_) => pendingVisits.future);
      when(() => save(params)).thenAnswer((_) => pendingSave.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final suggestionsLoading = cubit.loadSuggestions();
      final visitsLoading = cubit.loadVisits('pet-1');
      final saving = cubit.saveVaccination(params);
      pendingSuggestions.complete(const Success(suggestions));
      await suggestionsLoading;
      expect(cubit.state.isSaving, isTrue);
      pendingSave.complete(const Error(LocalDatabaseFailure('Save failed')));
      await saving;
      pendingVisits.complete(Success([visit]));
      await visitsLoading;
      expect(cubit.state.saveError, 'Save failed');
      expect(cubit.state.suggestions, suggestions);
      expect(cubit.state.visits, [visit]);
    },
  );

  test(
    'successful save is terminal even if option responses arrive later',
    () async {
      final pendingSuggestions = Completer<Result<VaccinationSuggestions>>();
      final pendingVisits = Completer<Result<List<VetVisit>>>();
      when(
        () => repository.getSuggestions(),
      ).thenAnswer((_) => pendingSuggestions.future);
      when(
        () => visitRepository.getVetVisits('pet-1'),
      ).thenAnswer((_) => pendingVisits.future);
      when(() => save(params)).thenAnswer((_) async => const Success(null));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      final options = [cubit.loadSuggestions(), cubit.loadVisits('pet-1')];
      await cubit.saveVaccination(params);
      final saved = cubit.state;
      expect(saved.isSaved, isTrue);
      expect(saved.isLoadingSuggestions, isFalse);
      expect(saved.isLoadingVisits, isFalse);
      pendingSuggestions.complete(const Success(suggestions));
      pendingVisits.complete(Success([visit]));
      await Future.wait(options);
      clearInteractions(repository);
      clearInteractions(visitRepository);
      clearInteractions(save);
      await cubit.loadSuggestions();
      await cubit.loadVisits('pet-1');
      await cubit.saveVaccination(params);
      expect(cubit.state, same(saved));
      verifyZeroInteractions(repository);
      verifyZeroInteractions(visitRepository);
      verifyZeroInteractions(save);
    },
  );

  test('closed forms ignore completions and start no further work', () async {
    final pendingSuggestions = Completer<Result<VaccinationSuggestions>>();
    final pendingVisits = Completer<Result<List<VetVisit>>>();
    final pendingSave = Completer<Result<void>>();
    when(
      () => repository.getSuggestions(),
    ).thenAnswer((_) => pendingSuggestions.future);
    when(
      () => visitRepository.getVetVisits('pet-1'),
    ).thenAnswer((_) => pendingVisits.future);
    when(() => save(params)).thenAnswer((_) => pendingSave.future);
    final cubit = makeCubit();
    final work = [
      cubit.loadSuggestions(),
      cubit.loadVisits('pet-1'),
      cubit.saveVaccination(params),
    ];
    await cubit.close();
    pendingSuggestions.complete(const Success(suggestions));
    pendingVisits.complete(Success([visit]));
    pendingSave.complete(const Success(null));
    await expectLater(Future.wait(work), completes);
    clearInteractions(repository);
    clearInteractions(visitRepository);
    clearInteractions(save);
    await cubit.loadSuggestions();
    await cubit.loadVisits('pet-1');
    await cubit.saveVaccination(params);
    verifyZeroInteractions(repository);
    verifyZeroInteractions(visitRepository);
    verifyZeroInteractions(save);
  });
}
