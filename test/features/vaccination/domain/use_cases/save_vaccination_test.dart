import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/domain/use_cases/save_vaccination.dart';

class MockVaccinationRepository extends Mock implements VaccinationRepository {}

class MockIdGenerator extends Mock implements IdGenerator {}

void main() {
  late MockVaccinationRepository repository;
  late MockIdGenerator idGenerator;
  late SaveVaccination save;
  final date = DateTime(2020, 1, 2);
  final nextDate = DateTime(2021, 1, 2);
  final original = Vaccination(
    id: 'vaccination-1',
    petId: 'pet-1',
    vaccineName: 'Rabies',
    status: VaccinationStatus.administered,
    date: date,
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    notes: 'No reaction',
    vetVisitId: 'visit-1',
  );
  final next = Vaccination(
    id: 'next-dose',
    petId: 'pet-1',
    vaccineName: 'Rabies',
    status: VaccinationStatus.planned,
    date: nextDate,
  );

  SaveVaccinationParams params({
    String? id,
    DateTime? nextDoseDate,
    VaccinationStatus status = VaccinationStatus.administered,
  }) => SaveVaccinationParams(
    petId: original.petId,
    vaccinationId: id,
    vaccineName: original.vaccineName,
    status: status,
    date: date,
    clinicName: original.clinicName,
    veterinarianName: original.veterinarianName,
    notes: original.notes,
    vetVisitId: original.vetVisitId,
    nextDoseDate: nextDoseDate,
  );

  setUp(() {
    repository = MockVaccinationRepository();
    idGenerator = MockIdGenerator();
    final ids = [original.id, next.id].iterator;
    when(() => idGenerator.generate()).thenAnswer((_) {
      ids.moveNext();
      return ids.current;
    });
    save = SaveVaccination(repository, idGenerator);
  });

  test(
    'creates the administration and a new plan in one repository call',
    () async {
      when(
        () => repository.createVaccination(original, nextDose: next),
      ).thenAnswer((_) async => const Success(null));
      expect(
        await save(params(nextDoseDate: nextDate)),
        const Success<void>(null),
      );
      verify(
        () => repository.createVaccination(original, nextDose: next),
      ).called(1);
      verifyNoMoreInteractions(repository);
      verify(() => idGenerator.generate()).called(2);
    },
  );

  test('creation without a next date generates only one ID', () async {
    when(
      () => repository.createVaccination(original),
    ).thenAnswer((_) async => const Success(null));
    expect(await save(params()), const Success<void>(null));
    verify(() => repository.createVaccination(original)).called(1);
    verify(() => idGenerator.generate()).called(1);
  });

  test('an ordinary edit keeps the ID and creates no new plan', () async {
    when(
      () => repository.updateVaccination(original),
    ).thenAnswer((_) async => const Success(null));
    expect(await save(params(id: original.id)), const Success<void>(null));
    verify(() => repository.updateVaccination(original)).called(1);
    verifyZeroInteractions(idGenerator);
  });

  test(
    'recording an existing plan keeps its ID and generates only the next ID',
    () async {
      when(() => idGenerator.generate()).thenReturn(next.id);
      when(
        () => repository.updateVaccination(original, nextDose: next),
      ).thenAnswer((_) async => const Success(null));
      expect(
        await save(params(id: original.id, nextDoseDate: nextDate)),
        const Success<void>(null),
      );
      verify(
        () => repository.updateVaccination(original, nextDose: next),
      ).called(1);
      verifyNoMoreInteractions(repository);
      verify(() => idGenerator.generate()).called(1);
    },
  );

  test(
    'changing an administration back to planned clears its obsolete visit link',
    () async {
      final planned = Vaccination(
        id: original.id,
        petId: original.petId,
        vaccineName: original.vaccineName,
        status: VaccinationStatus.planned,
        date: date,
        clinicName: original.clinicName,
        veterinarianName: original.veterinarianName,
        notes: original.notes,
      );
      when(
        () => repository.updateVaccination(planned),
      ).thenAnswer((_) async => const Success(null));
      await save(params(id: original.id, status: VaccinationStatus.planned));
      verify(() => repository.updateVaccination(planned)).called(1);
      verifyZeroInteractions(idGenerator);
    },
  );

  for (final (id, result) in <(String?, Result<void>)>[
    (null, const Error(LocalDatabaseFailure('Create failed'))),
    ('vaccination-1', const Error(LocalDatabaseFailure('Update failed'))),
    ('vaccination-1', const Error(NotFoundFailure('Vaccination not found'))),
  ]) {
    test('preserves the repository failure $result', () async {
      if (id == null) {
        when(
          () => repository.createVaccination(original),
        ).thenAnswer((_) async => result);
      } else {
        when(
          () => repository.updateVaccination(original),
        ).thenAnswer((_) async => result);
      }
      expect(await save(params(id: id)), same(result));
    });
  }
}
