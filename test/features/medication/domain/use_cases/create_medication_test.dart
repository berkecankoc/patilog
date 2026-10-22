import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/create_medication.dart';

class MockMedicationRepository extends Mock implements MedicationRepository {}

class MockIdGenerator extends Mock implements IdGenerator {}

void main() {
  late MockMedicationRepository repository;
  late MockIdGenerator generator;
  late CreateMedication create;
  final start = DateTime(2026, 10, 20);
  final expected = Medication(
    id: 'medicine',
    petId: 'pet',
    name: 'Medicine',
    periods: [
      MedicationPeriod(
        id: 'period',
        medicationId: 'medicine',
        startDate: start,
        endDate: DateTime(2026, 10, 25),
        intervalDays: 2,
        doseTimes: [480, 1200],
        dosageInstructions: 'Half',
        vetVisitId: 'visit',
        clinicName: 'Clinic',
        veterinarianName: 'Dr. Smith',
        notes: 'After food',
      ),
    ],
  );
  CreateMedicationParams params() => CreateMedicationParams(
    petId: 'pet',
    name: 'Medicine',
    startDate: start,
    endDate: DateTime(2026, 10, 25),
    intervalDays: 2,
    doseTimes: [1200, 480],
    dosageInstructions: 'Half',
    vetVisitId: 'visit',
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    notes: 'After food',
  );

  setUpAll(() => registerFallbackValue(expected));
  setUp(() {
    repository = MockMedicationRepository();
    generator = MockIdGenerator();
    var index = 0;
    when(
      () => generator.generate(),
    ).thenAnswer((_) => ['medicine', 'period'][index++]);
    create = CreateMedication(repository, generator);
  });

  test(
    'creates linked identities and all fields through one atomic repository call',
    () async {
      when(
        () => repository.createMedication(any()),
      ).thenAnswer((_) async => const Success(null));
      expect(await create(params()), const Success<void>(null));
      verify(() => generator.generate()).called(2);
      expect(
        verify(() => repository.createMedication(captureAny())).captured.single,
        expected,
      );
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'past initial use and omitted optional details reach storage unchanged',
    () async {
      when(
        () => repository.createMedication(any()),
      ).thenAnswer((_) async => const Success(null));
      final past = DateTime(2020, 1, 1);
      await create(
        CreateMedicationParams(
          petId: 'pet',
          name: 'Medicine',
          startDate: past,
          intervalDays: 1,
          doseTimes: [480],
        ),
      );
      final saved =
          verify(
                () => repository.createMedication(captureAny()),
              ).captured.single
              as Medication;
      expect(saved.periods.single.startDate, past);
      expect(saved.periods.single.endDate, isNull);
      expect(saved.periods.single.vetVisitId, isNull);
    },
  );

  test(
    'repository failures are returned without attempting separate writes',
    () async {
      const failure = Error<void>(
        LocalDatabaseFailure('Failed to create medication'),
      );
      when(
        () => repository.createMedication(any()),
      ).thenAnswer((_) async => failure);
      expect(identical(await create(params()), failure), isTrue);
      verify(() => repository.createMedication(any())).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'creation captures the plan before awaiting repository completion',
    () async {
      final pending = Completer<Result<void>>();
      when(
        () => repository.createMedication(any()),
      ).thenAnswer((_) => pending.future);
      final times = [480];
      final result = create(
        CreateMedicationParams(
          petId: 'pet',
          name: 'Medicine',
          startDate: start,
          intervalDays: 1,
          doseTimes: times,
        ),
      );
      times.add(1200);
      final saved =
          verify(
                () => repository.createMedication(captureAny()),
              ).captured.single
              as Medication;
      expect(saved.periods.single.doseTimes, [480]);
      pending.complete(const Success(null));
      expect(await result, const Success<void>(null));
    },
  );
}
