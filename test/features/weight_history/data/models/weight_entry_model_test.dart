import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/weight_history/data/models/weight_entry_model.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';

void main() {
  final measuredAt = DateTime.utc(2026, 10, 13, 10, 30);
  final model = WeightEntryModel(
    id: 'entry-1',
    petId: 'pet-1',
    weight: 5.4,
    measuredAt: measuredAt,
  );
  final entity = WeightEntry(
    id: model.id,
    petId: model.petId,
    weight: model.weight,
    measuredAt: measuredAt,
  );
  const json = {
    'id': 'entry-1',
    'pet_id': 'pet-1',
    'weight': 5.4,
    'measured_at': '2026-10-13T10:30:00.000000Z',
  };

  test('serializes the measurement using database column names', () {
    expect(model.toJson(), json);
  });

  test('deserializes a stored measurement', () {
    expect(WeightEntryModel.fromJson(json), model);
  });

  test('maps the model to an entity', () {
    expect(model.toEntity(), entity);
  });

  test('maps an entity to the model', () {
    expect(WeightEntryModel.fromEntity(entity), model);
  });

  test('converts integer weights to double', () {
    final result = WeightEntryModel.fromJson({...json, 'weight': 5});
    expect(result.weight, 5.0);
    expect(result.weight, isA<double>());
  });

  test('normalizes a timestamp with an offset to UTC', () {
    final result = WeightEntryModel.fromJson({
      ...json,
      'measured_at': '2026-10-13T13:30:00+03:00',
    });
    expect(result.measuredAt, measuredAt);
    expect(result.measuredAt.isUtc, isTrue);
  });

  test(
    'preserves a local measurement instant and precision through storage',
    () {
      final localTime = DateTime(2026, 10, 13, 13, 30, 12, 123, 456);
      final localModel = WeightEntryModel(
        id: model.id,
        petId: model.petId,
        weight: model.weight,
        measuredAt: localTime,
      );

      final stored = localModel.toJson();
      final restored = WeightEntryModel.fromJson(stored);
      expect(stored['measured_at'], localTime.toUtc().toIso8601String());
      expect(restored.measuredAt.isAtSameMomentAs(localTime), isTrue);
      expect(restored.measuredAt.isUtc, isTrue);
    },
  );

  test('rejects an unparseable timestamp rather than inventing a date', () {
    expect(
      () => WeightEntryModel.fromJson({...json, 'measured_at': 'not-a-date'}),
      throwsFormatException,
    );
  });

  test(
    'stored timestamps sort chronologically within the same millisecond',
    () {
      final times = [
        DateTime.utc(2026, 10, 13, 10, 30, 0, 123),
        DateTime.utc(2026, 10, 13, 10, 30, 0, 123, 1),
      ];
      final storedTimes = times
          .map(
            (time) =>
                WeightEntryModel(
                      id: model.id,
                      petId: model.petId,
                      weight: model.weight,
                      measuredAt: time,
                    ).toJson()['measured_at']
                    as String,
          )
          .toList();

      expect(storedTimes.first.compareTo(storedTimes.last), lessThan(0));
      for (var i = 0; i < times.length; i++) {
        expect(DateTime.parse(storedTimes[i]), times[i]);
      }
    },
  );
}
