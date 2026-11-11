import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/weight_history/data/data_sources/weight_history_local_data_source.dart';
import 'package:patilog/features/weight_history/data/models/weight_entry_model.dart';
import 'package:patilog/features/weight_history/data/repositories/weight_history_repository_impl.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';

class MockWeightHistoryLocalDataSource extends Mock
    implements WeightHistoryLocalDataSource {}

void main() {
  late MockWeightHistoryLocalDataSource source;
  late WeightHistoryRepositoryImpl repository;
  final entry = WeightEntry(
    id: 'entry-1',
    petId: 'pet-1',
    weight: 5.4,
    measuredAt: DateTime.utc(2026, 10, 13),
  );
  final olderEntry = WeightEntry(
    id: 'entry-2',
    petId: entry.petId,
    weight: 5.2,
    measuredAt: entry.measuredAt.subtract(const Duration(days: 1)),
  );
  final model = WeightEntryModel.fromEntity(entry);

  setUp(() {
    source = MockWeightHistoryLocalDataSource();
    repository = WeightHistoryRepositoryImpl(source);
  });

  group('getAllWeightEntries', () {
    test('maps all pets without per-pet reads or losing their identities and order', () async {
      final other = WeightEntry(
        id: 'other',
        petId: 'pet-2',
        weight: 7,
        measuredAt: entry.measuredAt,
      );
      when(source.getAllWeightEntries)
          .thenAnswer((_) async => [WeightEntryModel.fromEntity(other), model]);
      expect(await repository.getAllWeightEntries(), Success([other, entry]));
      verify(source.getAllWeightEntries).called(1);
      verifyNever(() => source.getWeightEntries(any()));
    });
    test('returns an empty success', () async {
      when(source.getAllWeightEntries).thenAnswer((_) async => []);
      expect(
        await repository.getAllWeightEntries(),
        const Success<List<WeightEntry>>([]),
      );
    });
    test('maps database failures', () async {
      when(source.getAllWeightEntries)
          .thenThrow(const LocalDataSourceException());
      expect(
        await repository.getAllWeightEntries(),
        const Error<List<WeightEntry>>(
          LocalDatabaseFailure('Failed to load weight history'),
        ),
      );
    });
  });

  group('getWeightEntries', () {
    test('maps measurements to entities and preserves their order', () async {
      when(() => source.getWeightEntries(entry.petId)).thenAnswer(
        (_) async => [model, WeightEntryModel.fromEntity(olderEntry)],
      );
      expect(
        await repository.getWeightEntries(entry.petId),
        Success([entry, olderEntry]),
      );
      verify(() => source.getWeightEntries(entry.petId)).called(1);
    });

    test('returns success with an empty history', () async {
      when(
        () => source.getWeightEntries(entry.petId),
      ).thenAnswer((_) async => []);
      expect(
        await repository.getWeightEntries(entry.petId),
        const Success<List<WeightEntry>>([]),
      );
    });

    test('maps database failures', () async {
      when(
        () => source.getWeightEntries(entry.petId),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.getWeightEntries(entry.petId),
        const Error<List<WeightEntry>>(
          LocalDatabaseFailure('Failed to load weight history'),
        ),
      );
    });
  });

  group('createWeightEntry', () {
    test('converts the entity to a model and returns success', () async {
      when(() => source.createWeightEntry(model)).thenAnswer((_) async {});
      expect(
        await repository.createWeightEntry(entry),
        const Success<void>(null),
      );
      verify(() => source.createWeightEntry(model)).called(1);
    });

    test('maps database failures', () async {
      when(
        () => source.createWeightEntry(model),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.createWeightEntry(entry),
        const Error<void>(LocalDatabaseFailure('Failed to create measurement')),
      );
    });
  });

  group('updateWeightEntry', () {
    test('converts the entity to a model and returns success', () async {
      when(() => source.updateWeightEntry(model)).thenAnswer((_) async {});
      expect(
        await repository.updateWeightEntry(entry),
        const Success<void>(null),
      );
      verify(() => source.updateWeightEntry(model)).called(1);
    });

    test('maps database failures', () async {
      when(
        () => source.updateWeightEntry(model),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.updateWeightEntry(entry),
        const Error<void>(LocalDatabaseFailure('Failed to update measurement')),
      );
    });

    test('maps a missing measurement to NotFoundFailure', () async {
      when(
        () => source.updateWeightEntry(model),
      ).thenThrow(const LocalDataNotFoundException());
      expect(
        await repository.updateWeightEntry(entry),
        const Error<void>(NotFoundFailure('Measurement not found')),
      );
    });
  });

  group('deleteWeightEntry', () {
    test('deletes the requested measurement and returns success', () async {
      when(() => source.deleteWeightEntry(entry.id)).thenAnswer((_) async {});
      expect(
        await repository.deleteWeightEntry(entry.id),
        const Success<void>(null),
      );
      verify(() => source.deleteWeightEntry(entry.id)).called(1);
    });

    test('maps database failures', () async {
      when(
        () => source.deleteWeightEntry(entry.id),
      ).thenThrow(const LocalDataSourceException());
      expect(
        await repository.deleteWeightEntry(entry.id),
        const Error<void>(LocalDatabaseFailure('Failed to delete measurement')),
      );
    });

    test('maps a missing measurement to NotFoundFailure', () async {
      when(
        () => source.deleteWeightEntry(entry.id),
      ).thenThrow(const LocalDataNotFoundException());
      expect(
        await repository.deleteWeightEntry(entry.id),
        const Error<void>(NotFoundFailure('Measurement not found')),
      );
    });
  });
}
