import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vet_visit/data/data_sources/vet_visit_local_data_source.dart';
import 'package:petlytics/features/vet_visit/data/models/vet_visit_model.dart';
import 'package:petlytics/features/vet_visit/data/repositories/vet_visit_repository_impl.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';

class MockVetVisitLocalDataSource extends Mock
    implements VetVisitLocalDataSource {}

void main() {
  late MockVetVisitLocalDataSource source;
  late VetVisitRepositoryImpl repository;
  final date = DateTime(2026, 10, 15);
  final visit = VetVisit(
    id: 'visit-1',
    petId: 'pet-1',
    visitedOn: date,
    reason: 'Checkup',
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    diagnosis: 'Healthy',
    notes: 'Routine visit',
    costMinorUnits: 125050,
    currency: VetVisitCurrency.turkishLira,
  );
  final model = VetVisitModel(
    id: 'visit-1',
    petId: 'pet-1',
    visitedOn: date,
    reason: 'Checkup',
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    diagnosis: 'Healthy',
    notes: 'Routine visit',
    costMinorUnits: 125050,
    currency: VetVisitCurrency.turkishLira,
  );
  const suggestions = VetVisitSuggestions(
    clinicNames: ['Clinic'],
    veterinarianNames: ['Dr. Smith'],
  );

  setUp(() {
    source = MockVetVisitLocalDataSource();
    repository = VetVisitRepositoryImpl(source);
  });

  group('getVetVisits', () {
    test('maps all fields to entities and preserves source order', () async {
      final olderModel = VetVisitModel(
        id: 'older',
        petId: visit.petId,
        visitedOn: DateTime(2026, 10, 14),
        reason: 'Follow-up',
      );
      when(
        () => source.getVetVisits(visit.petId),
      ).thenAnswer((_) async => [model, olderModel]);
      expect(
        await repository.getVetVisits(visit.petId),
        Success([visit, olderModel.toEntity()]),
      );
      verify(() => source.getVetVisits(visit.petId)).called(1);
    });

    test('returns success with an empty list', () async {
      when(() => source.getVetVisits(visit.petId)).thenAnswer((_) async => []);
      expect(
        await repository.getVetVisits(visit.petId),
        const Success<List<VetVisit>>([]),
      );
    });

    test('maps database failures', () async {
      when(
        () => source.getVetVisits(visit.petId),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.getVetVisits(visit.petId),
        const Error<List<VetVisit>>(
          LocalDatabaseFailure('Failed to load vet visits'),
        ),
      );
    });
  });

  group('getVetVisitById', () {
    test('passes both IDs and returns the converted entity', () async {
      when(
        () => source.getVetVisitById(visit.petId, visit.id),
      ).thenAnswer((_) async => model);
      expect(
        await repository.getVetVisitById(visit.petId, visit.id),
        Success(visit),
      );
      verify(() => source.getVetVisitById(visit.petId, visit.id)).called(1);
    });

    test('maps a missing or wrong-pet record to NotFoundFailure', () async {
      when(
        () => source.getVetVisitById(visit.petId, visit.id),
      ).thenThrow(const LocalDataNotFoundException());
      expect(
        await repository.getVetVisitById(visit.petId, visit.id),
        const Error<VetVisit>(NotFoundFailure('Vet visit not found')),
      );
    });

    test('maps database failures', () async {
      when(
        () => source.getVetVisitById(visit.petId, visit.id),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.getVetVisitById(visit.petId, visit.id),
        const Error<VetVisit>(LocalDatabaseFailure('Failed to load vet visit')),
      );
    });
  });

  group('createVetVisit', () {
    test('passes all fields as a model and returns success', () async {
      when(() => source.createVetVisit(model)).thenAnswer((_) async {});
      expect(await repository.createVetVisit(visit), const Success<void>(null));
      verify(() => source.createVetVisit(model)).called(1);
    });

    test('maps database failures', () async {
      when(
        () => source.createVetVisit(model),
      ).thenAnswer((_) async => throw const LocalDataSourceException());
      expect(
        await repository.createVetVisit(visit),
        const Error<void>(LocalDatabaseFailure('Failed to create vet visit')),
      );
    });
  });

  group('updateVetVisit', () {
    test('passes all fields including pet ID and returns success', () async {
      when(() => source.updateVetVisit(model)).thenAnswer((_) async {});
      expect(await repository.updateVetVisit(visit), const Success<void>(null));
      verify(() => source.updateVetVisit(model)).called(1);
    });

    test('maps a missing or wrong-pet record to NotFoundFailure', () async {
      when(
        () => source.updateVetVisit(model),
      ).thenThrow(const LocalDataNotFoundException());
      expect(
        await repository.updateVetVisit(visit),
        const Error<void>(NotFoundFailure('Vet visit not found')),
      );
    });

    test('maps database failures', () async {
      when(
        () => source.updateVetVisit(model),
      ).thenAnswer((_) async => throw const LocalDataSourceException());
      expect(
        await repository.updateVetVisit(visit),
        const Error<void>(LocalDatabaseFailure('Failed to update vet visit')),
      );
    });
  });

  group('deleteVetVisit', () {
    test('passes both IDs and returns success', () async {
      when(
        () => source.deleteVetVisit(visit.petId, visit.id),
      ).thenAnswer((_) async {});
      expect(
        await repository.deleteVetVisit(visit.petId, visit.id),
        const Success<void>(null),
      );
      verify(() => source.deleteVetVisit(visit.petId, visit.id)).called(1);
    });

    test('maps a missing or wrong-pet record to NotFoundFailure', () async {
      when(
        () => source.deleteVetVisit(visit.petId, visit.id),
      ).thenThrow(const LocalDataNotFoundException());
      expect(
        await repository.deleteVetVisit(visit.petId, visit.id),
        const Error<void>(NotFoundFailure('Vet visit not found')),
      );
    });

    test('maps database failures', () async {
      when(
        () => source.deleteVetVisit(visit.petId, visit.id),
      ).thenAnswer((_) async => throw const LocalDataSourceException());
      expect(
        await repository.deleteVetVisit(visit.petId, visit.id),
        const Error<void>(LocalDatabaseFailure('Failed to delete vet visit')),
      );
    });
  });

  group('getSuggestions', () {
    test('returns suggestions for the selected clinic', () async {
      when(
        () => source.getSuggestions(clinicName: 'Clinic'),
      ).thenAnswer((_) async => suggestions);
      expect(
        await repository.getSuggestions(clinicName: 'Clinic'),
        const Success(suggestions),
      );
      verify(() => source.getSuggestions(clinicName: 'Clinic')).called(1);
    });

    test('passes no clinic filter when none is supplied', () async {
      when(() => source.getSuggestions()).thenAnswer((_) async => suggestions);
      expect(await repository.getSuggestions(), const Success(suggestions));
      verify(() => source.getSuggestions()).called(1);
    });

    test('returns empty suggestions as success', () async {
      const empty = VetVisitSuggestions(clinicNames: [], veterinarianNames: []);
      when(() => source.getSuggestions()).thenAnswer((_) async => empty);
      expect(await repository.getSuggestions(), const Success(empty));
    });

    test('maps database failures', () async {
      when(
        () => source.getSuggestions(),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.getSuggestions(),
        const Error<VetVisitSuggestions>(
          LocalDatabaseFailure('Failed to load suggestions'),
        ),
      );
    });
  });
}
