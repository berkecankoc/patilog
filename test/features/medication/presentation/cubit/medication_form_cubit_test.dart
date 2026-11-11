import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/domain/entities/medication_suggestions.dart';
import 'package:patilog/features/medication/domain/repositories/medication_repository.dart';
import 'package:patilog/features/medication/domain/use_cases/create_medication.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_form_state.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:patilog/features/vet_visit/domain/repositories/vet_visit_repository.dart';

class MockMedicationRepository extends Mock implements MedicationRepository {}

class MockVetVisitRepository extends Mock implements VetVisitRepository {}

class MockIdGenerator extends Mock implements IdGenerator {}

void main() {
  late MockMedicationRepository repository;
  late MockVetVisitRepository visits;
  late MockIdGenerator ids;
  late MedicationFormCubit cubit;
  final date = DateTime(2026, 10, 20);
  final period = MedicationPeriod(
    id: 'period',
    medicationId: 'med',
    startDate: date,
    intervalDays: 1,
    doseTimes: [480],
  );
  final medication = Medication(
    id: 'med',
    petId: 'pet',
    name: 'Medicine',
    periods: [period],
  );
  final params = CreateMedicationParams(
    petId: 'pet',
    name: 'Medicine',
    startDate: date,
    intervalDays: 1,
    doseTimes: [480],
  );
  const suggestions = MedicationSuggestions(
    medicationNames: ['Medicine'],
    clinicNames: ['Clinic'],
    veterinarianNames: ['Dr. One'],
  );
  const otherSuggestions = MedicationSuggestions(
    medicationNames: ['Medicine'],
    clinicNames: ['Clinic'],
    veterinarianNames: ['Dr. Two'],
  );
  const failure = LocalDatabaseFailure('Try again');
  final visit = VetVisit(
    id: 'visit',
    petId: 'pet',
    visitedOn: date,
    reason: 'Checkup',
  );

  Future<void> savePeriod({
    String? id,
    String petId = 'pet',
    String medicationId = 'med',
  }) => cubit.savePeriod(
    petId: petId,
    medicationId: medicationId,
    periodId: id,
    startDate: date,
    intervalDays: 1,
    doseTimes: [480],
    notes: 'After food',
    clinicName: 'Clinic',
    veterinarianName: 'Dr. One',
    vetVisitId: 'visit',
    dosageInstructions: 'Half',
    endDate: DateTime(2026, 10, 30),
  );

  setUpAll(() {
    registerFallbackValue(medication);
    registerFallbackValue(period);
  });
  setUp(() {
    repository = MockMedicationRepository();
    visits = MockVetVisitRepository();
    ids = MockIdGenerator();
    cubit = MedicationFormCubit(
      repository,
      visits,
      CreateMedication(repository, ids),
      ids,
    );
    when(() => ids.generate()).thenReturn('new');
  });
  tearDown(() => cubit.close());

  blocTest<MedicationFormCubit, MedicationFormState>(
    'creation uses the atomic creation use case and ends the form once',
    build: () {
      var index = 0;
      when(() => ids.generate()).thenAnswer((_) => ['med', 'period'][index++]);
      when(
        () => repository.createMedication(medication),
      ).thenAnswer((_) async => const Success(null));
      return cubit;
    },
    act: (cubit) async {
      await cubit.createMedication(params);
      await cubit.createMedication(params);
    },
    expect: () => [
      const MedicationFormState(isSaving: true),
      const MedicationFormState(isSaved: true),
    ],
    verify: (_) {
      verify(() => repository.createMedication(medication)).called(1);
      verify(() => ids.generate()).called(2);
    },
  );

  test('save failure retains loaded context and can be retried', () async {
    when(
      () => repository.getSuggestions(),
    ).thenAnswer((_) async => const Success(suggestions));
    when(
      () => visits.getVetVisits('pet'),
    ).thenAnswer((_) async => Success([visit]));
    await cubit.loadSuggestions();
    await cubit.loadVisits('pet');
    when(
      () => repository.renameMedication('pet', 'med', 'Changed'),
    ).thenAnswer((_) async => const Error(failure));
    await cubit.renameMedication('pet', 'med', 'Changed');
    expect(cubit.state.saveError, 'Try again');
    expect(cubit.state.suggestions, suggestions);
    expect(cubit.state.visits, [visit]);
    expect(cubit.state.isSaving, false);
    when(
      () => repository.renameMedication('pet', 'med', 'Changed'),
    ).thenAnswer((_) async => const Success(null));
    await cubit.renameMedication('pet', 'med', 'Changed');
    expect(cubit.state.isSaved, true);
    expect(cubit.state.saveError, isNull);
    verifyNever(() => ids.generate());
  });

  test(
    'new period preserves all fields and generates its ID only after the pending guard',
    () async {
      final response = Completer<Result<void>>();
      when(
        () => repository.createPeriod('pet', any()),
      ).thenAnswer((_) => response.future);
      final pending = savePeriod();
      await savePeriod();
      await cubit.renameMedication('pet', 'med', 'Other');
      expect(cubit.state.isSaving, true);
      verify(() => ids.generate()).called(1);
      final saved =
          verify(
                () => repository.createPeriod('pet', captureAny()),
              ).captured.single
              as MedicationPeriod;
      expect(
        saved,
        MedicationPeriod(
          id: 'new',
          medicationId: 'med',
          startDate: date,
          intervalDays: 1,
          doseTimes: [480],
          notes: 'After food',
          clinicName: 'Clinic',
          veterinarianName: 'Dr. One',
          vetVisitId: 'visit',
          dosageInstructions: 'Half',
          endDate: DateTime(2026, 10, 30),
        ),
      );
      response.complete(const Success(null));
      await pending;
      await savePeriod();
      verifyNever(() => ids.generate());
      verifyNever(() => repository.renameMedication(any(), any(), any()));
    },
  );

  for (final hasLogs in [true, false]) {
    test(
      'edit checks period lock ($hasLogs) and updates without generating an ID',
      () async {
        await savePeriod(id: 'period');
        verifyNever(() => repository.updatePeriod(any(), any()));
        when(
          () => repository.hasDoseLogs('pet', 'med', 'period'),
        ).thenAnswer((_) async => Success(hasLogs));
        await cubit.checkPeriod('pet', 'med', 'period');
        expect(cubit.state.hasDoseLogs, hasLogs);
        when(
          () => repository.updatePeriod('pet', any()),
        ).thenAnswer((_) async => const Success(null));
        await savePeriod(id: 'period');
        expect(cubit.state.isSaved, true);
        verify(
          () => repository.updatePeriod(
            'pet',
            any(
              that: isA<MedicationPeriod>().having((p) => p.id, 'id', 'period'),
            ),
          ),
        ).called(1);
        verifyNever(() => ids.generate());
      },
    );
  }

  test(
    'period check failure leaves edit lock unknown and offers a safe retry',
    () async {
      when(
        () => repository.hasDoseLogs('pet', 'med', 'period'),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.checkPeriod('pet', 'med', 'period');
      expect(cubit.state.hasDoseLogs, isNull);
      expect(cubit.state.periodError, 'Try again');
      await savePeriod(id: 'period');
      verifyNever(() => repository.updatePeriod(any(), any()));
      when(
        () => repository.hasDoseLogs('pet', 'med', 'period'),
      ).thenAnswer((_) async => const Success(false));
      await cubit.checkPeriod('pet', 'med', 'period');
      expect(cubit.state.periodError, isNull);
      expect(cubit.state.hasDoseLogs, false);
    },
  );

  test(
    'a lock from another pet/medication/period never enables the edited write',
    () async {
      when(
        () => repository.hasDoseLogs('pet', 'med', 'period'),
      ).thenAnswer((_) async => const Success(false));
      await cubit.checkPeriod('pet', 'med', 'period');
      await savePeriod(id: 'other');
      await savePeriod(id: 'period', petId: 'other');
      await savePeriod(id: 'period', medicationId: 'other');
      verifyNever(() => repository.updatePeriod(any(), any()));
    },
  );

  test(
    'new period check resets the previous lock and ignores its stale response',
    () async {
      final old = Completer<Result<bool>>();
      when(
        () => repository.hasDoseLogs('pet', 'med', 'old'),
      ).thenAnswer((_) => old.future);
      when(
        () => repository.hasDoseLogs('pet', 'med', 'period'),
      ).thenAnswer((_) async => const Success(true));
      final pending = cubit.checkPeriod('pet', 'med', 'old');
      await savePeriod(id: 'old');
      await cubit.checkPeriod('pet', 'med', 'period');
      old.complete(const Success(false));
      await pending;
      expect(cubit.state.periodKey, (
        petId: 'pet',
        medicationId: 'med',
        periodId: 'period',
      ));
      expect(cubit.state.hasDoseLogs, true);
      verifyNever(() => repository.updatePeriod(any(), any()));
    },
  );

  test(
    'suggestion failure is independent and cannot block a valid save',
    () async {
      when(
        () => repository.getSuggestions(),
      ).thenAnswer((_) async => const Error(failure));
      when(
        () => visits.getVetVisits('pet'),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.loadSuggestions();
      await cubit.loadVisits('pet');
      expect(cubit.state.suggestionsError, 'Try again');
      expect(cubit.state.visitsError, 'Try again');
      when(
        () => repository.createMedication(any()),
      ).thenAnswer((_) async => const Success(null));
      await cubit.createMedication(params);
      expect(cubit.state.isSaved, true);
    },
  );

  test(
    'clinic changes clear stale vets and accept only the last suggestion response',
    () async {
      when(
        () => repository.getSuggestions(),
      ).thenAnswer((_) async => const Success(suggestions));
      await cubit.loadSuggestions();
      final old = Completer<Result<MedicationSuggestions>>();
      when(
        () => repository.getSuggestions(clinicName: 'Old'),
      ).thenAnswer((_) => old.future);
      final pending = cubit.loadSuggestions(clinicName: 'Old');
      expect(cubit.state.suggestions.veterinarianNames, isEmpty);
      expect(cubit.state.suggestions.medicationNames, ['Medicine']);
      expect(cubit.state.suggestions.clinicNames, ['Clinic']);
      when(
        () => repository.getSuggestions(clinicName: 'New'),
      ).thenAnswer((_) async => const Success(otherSuggestions));
      await cubit.loadSuggestions(clinicName: 'New');
      old.complete(const Success(suggestions));
      await pending;
      expect(cubit.state.suggestions, otherSuggestions);
    },
  );

  test(
    'switching pet clears its visits and ignores a previous response',
    () async {
      when(
        () => visits.getVetVisits('pet'),
      ).thenAnswer((_) async => Success([visit]));
      await cubit.loadVisits('pet');
      final response = Completer<Result<List<VetVisit>>>();
      when(() => visits.getVetVisits('pet')).thenAnswer((_) => response.future);
      final pending = cubit.loadVisits('pet');
      final other = Completer<Result<List<VetVisit>>>();
      when(() => visits.getVetVisits('other')).thenAnswer((_) => other.future);
      final latest = cubit.loadVisits('other');
      expect(cubit.state.visits, isEmpty);
      expect(cubit.state.visitsPetId, 'other');
      other.complete(const Error(failure));
      await latest;
      response.complete(Success([visit]));
      await pending;
      expect(cubit.state.visits, isEmpty);
      expect(cubit.state.visitsError, 'Try again');
      when(
        () => visits.getVetVisits('other'),
      ).thenAnswer((_) async => const Success([]));
      await cubit.loadVisits('other');
      expect(cubit.state.visitsError, isNull);
    },
  );

  test('successful save makes late option/check replies terminal', () async {
    final suggestionResponse = Completer<Result<MedicationSuggestions>>();
    final visitResponse = Completer<Result<List<VetVisit>>>();
    final checkResponse = Completer<Result<bool>>();
    when(
      () => repository.getSuggestions(),
    ).thenAnswer((_) => suggestionResponse.future);
    when(
      () => visits.getVetVisits('pet'),
    ).thenAnswer((_) => visitResponse.future);
    when(
      () => repository.hasDoseLogs('pet', 'med', 'period'),
    ).thenAnswer((_) => checkResponse.future);
    final options = [
      cubit.loadSuggestions(),
      cubit.loadVisits('pet'),
      cubit.checkPeriod('pet', 'med', 'period'),
    ];
    when(
      () => repository.renameMedication('pet', 'med', 'Changed'),
    ).thenAnswer((_) async => const Success(null));
    await cubit.renameMedication('pet', 'med', 'Changed');
    final saved = cubit.state;
    expect(
      saved.isLoadingSuggestions ||
          saved.isLoadingVisits ||
          saved.isCheckingPeriod,
      false,
    );
    suggestionResponse.complete(const Success(suggestions));
    visitResponse.complete(Success([visit]));
    checkResponse.complete(const Success(true));
    await Future.wait(options);
    await cubit.loadSuggestions();
    await cubit.loadVisits('pet');
    await cubit.checkPeriod('pet', 'med', 'period');
    expect(cubit.state, saved);
    verify(() => repository.getSuggestions()).called(1);
  });

  for (final operation in ['save', 'suggestions', 'visits', 'check']) {
    test('closed form ignores the pending $operation result', () async {
      late Future<void> pending;
      late void Function() complete;
      switch (operation) {
        case 'save':
          final response = Completer<Result<void>>();
          when(
            () => repository.renameMedication('pet', 'med', 'Changed'),
          ).thenAnswer((_) => response.future);
          pending = cubit.renameMedication('pet', 'med', 'Changed');
          complete = () => response.complete(const Success(null));
        case 'suggestions':
          final response = Completer<Result<MedicationSuggestions>>();
          when(
            () => repository.getSuggestions(),
          ).thenAnswer((_) => response.future);
          pending = cubit.loadSuggestions();
          complete = () => response.complete(const Success(suggestions));
        case 'visits':
          final response = Completer<Result<List<VetVisit>>>();
          when(
            () => visits.getVetVisits('pet'),
          ).thenAnswer((_) => response.future);
          pending = cubit.loadVisits('pet');
          complete = () => response.complete(Success([visit]));
        default:
          final response = Completer<Result<bool>>();
          when(
            () => repository.hasDoseLogs('pet', 'med', 'period'),
          ).thenAnswer((_) => response.future);
          pending = cubit.checkPeriod('pet', 'med', 'period');
          complete = () => response.complete(const Success(true));
      }
      await cubit.close();
      final before = cubit.state;
      complete();
      await pending;
      expect(cubit.state, before);
      await cubit.createMedication(params);
      await savePeriod();
      verifyNever(() => ids.generate());
    });
  }
}
