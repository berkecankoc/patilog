import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vaccination/data/data_sources/vaccination_local_data_source.dart';
import 'package:petlytics/features/vaccination/data/models/vaccination_model.dart';
import 'package:petlytics/features/vaccination/data/repositories/vaccination_repository_impl.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';

class MockVaccinationLocalDataSource extends Mock
    implements VaccinationLocalDataSource {}

void main() {
  late MockVaccinationLocalDataSource source;
  late VaccinationRepositoryImpl repository;
  final vaccination = Vaccination(
    id: 'vaccination-1',
    petId: 'pet-1',
    vaccineName: 'Rabies',
    status: VaccinationStatus.administered,
    date: DateTime(2020, 1, 2),
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    notes: 'No reaction',
    vetVisitId: 'visit-1',
  );
  final nextDose = Vaccination(
    id: 'next-dose',
    petId: 'pet-1',
    vaccineName: 'Rabies',
    status: VaccinationStatus.planned,
    date: DateTime(2021, 1, 2),
  );
  final model = VaccinationModel.fromEntity(vaccination);
  final nextModel = VaccinationModel.fromEntity(nextDose);
  const suggestions = VaccinationSuggestions(
    vaccineNames: ['Rabies'],
    clinicNames: ['Clinic'],
    veterinarianNames: ['Dr. Smith'],
  );

  setUp(() {
    source = MockVaccinationLocalDataSource();
    repository = VaccinationRepositoryImpl(source);
  });

  group('getVaccinations', () {
    test('maps all fields and preserves the data source order', () async {
      when(
        () => source.getVaccinations('pet-1'),
      ).thenAnswer((_) async => [nextModel, model]);
      expect(
        await repository.getVaccinations('pet-1'),
        Success([nextDose, vaccination]),
      );
      verify(() => source.getVaccinations('pet-1')).called(1);
    });

    test('returns an empty list as success', () async {
      when(() => source.getVaccinations('pet-1')).thenAnswer((_) async => []);
      expect(
        await repository.getVaccinations('pet-1'),
        const Success<List<Vaccination>>([]),
      );
    });

    test('maps storage errors to a safe failure', () async {
      when(
        () => source.getVaccinations('pet-1'),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.getVaccinations('pet-1'),
        const Error<List<Vaccination>>(
          LocalDatabaseFailure('Failed to load vaccinations'),
        ),
      );
    });
  });

  group('getVaccinationById', () {
    test('reads by both IDs and converts the complete record', () async {
      when(
        () => source.getVaccinationById('pet-1', vaccination.id),
      ).thenAnswer((_) async => model);
      expect(
        await repository.getVaccinationById('pet-1', vaccination.id),
        Success(vaccination),
      );
      verify(
        () => source.getVaccinationById('pet-1', vaccination.id),
      ).called(1);
    });

    test('maps missing or wrong-pet records to NotFoundFailure', () async {
      when(
        () => source.getVaccinationById('pet-1', vaccination.id),
      ).thenThrow(const LocalDataNotFoundException());
      expect(
        await repository.getVaccinationById('pet-1', vaccination.id),
        const Error<Vaccination>(NotFoundFailure('Vaccination not found')),
      );
    });

    test('maps storage errors', () async {
      when(
        () => source.getVaccinationById('pet-1', vaccination.id),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.getVaccinationById('pet-1', vaccination.id),
        const Error<Vaccination>(
          LocalDatabaseFailure('Failed to load vaccination'),
        ),
      );
    });
  });

  group('createVaccination', () {
    test('passes both converted records in one write', () async {
      when(
        () => source.createVaccination(model, nextDose: nextModel),
      ).thenAnswer((_) async {});
      expect(
        await repository.createVaccination(vaccination, nextDose: nextDose),
        const Success<void>(null),
      );
      verify(
        () => source.createVaccination(model, nextDose: nextModel),
      ).called(1);
    });

    test('does not supply a next dose unless requested', () async {
      when(() => source.createVaccination(model)).thenAnswer((_) async {});
      expect(
        await repository.createVaccination(vaccination),
        const Success<void>(null),
      );
      verify(() => source.createVaccination(model)).called(1);
    });

    test('maps a failed atomic write', () async {
      when(
        () => source.createVaccination(model, nextDose: nextModel),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.createVaccination(vaccination, nextDose: nextDose),
        const Error<void>(LocalDatabaseFailure('Failed to create vaccination')),
      );
    });
  });

  group('updateVaccination', () {
    test('passes both records to the atomic update', () async {
      when(
        () => source.updateVaccination(model, nextDose: nextModel),
      ).thenAnswer((_) async {});
      expect(
        await repository.updateVaccination(vaccination, nextDose: nextDose),
        const Success<void>(null),
      );
      verify(
        () => source.updateVaccination(model, nextDose: nextModel),
      ).called(1);
    });

    test('supports corrections without creating a new plan', () async {
      when(() => source.updateVaccination(model)).thenAnswer((_) async {});
      expect(
        await repository.updateVaccination(vaccination),
        const Success<void>(null),
      );
      verify(() => source.updateVaccination(model)).called(1);
    });

    test('maps missing or wrong-pet records to NotFoundFailure', () async {
      when(
        () => source.updateVaccination(model),
      ).thenThrow(const LocalDataNotFoundException());
      expect(
        await repository.updateVaccination(vaccination),
        const Error<void>(NotFoundFailure('Vaccination not found')),
      );
    });

    test('maps a failed atomic update', () async {
      when(
        () => source.updateVaccination(model, nextDose: nextModel),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.updateVaccination(vaccination, nextDose: nextDose),
        const Error<void>(LocalDatabaseFailure('Failed to update vaccination')),
      );
    });
  });

  group('deleteVaccination', () {
    test('passes both IDs and returns success', () async {
      when(
        () => source.deleteVaccination('pet-1', vaccination.id),
      ).thenAnswer((_) async {});
      expect(
        await repository.deleteVaccination('pet-1', vaccination.id),
        const Success<void>(null),
      );
      verify(() => source.deleteVaccination('pet-1', vaccination.id)).called(1);
    });

    test('maps missing or wrong-pet records to NotFoundFailure', () async {
      when(
        () => source.deleteVaccination('pet-1', vaccination.id),
      ).thenThrow(const LocalDataNotFoundException());
      expect(
        await repository.deleteVaccination('pet-1', vaccination.id),
        const Error<void>(NotFoundFailure('Vaccination not found')),
      );
    });

    test('maps storage errors', () async {
      when(
        () => source.deleteVaccination('pet-1', vaccination.id),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.deleteVaccination('pet-1', vaccination.id),
        const Error<void>(LocalDatabaseFailure('Failed to delete vaccination')),
      );
    });
  });

  group('getSuggestions', () {
    test(
      'passes the clinic filter and returns all suggestion groups',
      () async {
        when(
          () => source.getSuggestions(clinicName: 'Clinic'),
        ).thenAnswer((_) async => suggestions);
        expect(
          await repository.getSuggestions(clinicName: 'Clinic'),
          const Success(suggestions),
        );
        verify(() => source.getSuggestions(clinicName: 'Clinic')).called(1);
      },
    );

    test('passes no filter when none is supplied', () async {
      when(() => source.getSuggestions()).thenAnswer((_) async => suggestions);
      expect(await repository.getSuggestions(), const Success(suggestions));
      verify(() => source.getSuggestions()).called(1);
    });

    test('maps storage errors', () async {
      when(
        () => source.getSuggestions(),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.getSuggestions(),
        const Error<VaccinationSuggestions>(
          LocalDatabaseFailure('Failed to load vaccination suggestions'),
        ),
      );
    });
  });
}
