import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/presentation/utils/weight_chart_data.dart';

WeightEntry entry(String id, DateTime day, [double weight = 5]) =>
    WeightEntry(id: id, petId: 'pet', weight: weight, measuredAt: day);

void main() {
  test('month boundaries clamp to the last valid calendar day', () {
    expect(
      weightChartStart(WeightChartRange.month, DateTime(2024, 3, 31)),
      DateTime.utc(2024, 2, 29),
    );
    expect(
      weightChartStart(WeightChartRange.month, DateTime(2025, 3, 31)),
      DateTime.utc(2025, 2, 28),
    );
    expect(
      weightChartStart(WeightChartRange.threeMonths, DateTime(2026, 1, 31)),
      DateTime.utc(2025, 10, 31),
    );
    expect(
      weightChartStart(WeightChartRange.sixMonths, DateTime(2026, 11, 1)),
      DateTime.utc(2026, 5, 1),
    );
    expect(weightChartStart(WeightChartRange.all, DateTime(2026)), isNull);
  });

  test(
    'plot preserves newest-first ties and returns one point per local day',
    () {
      final newest = entry('latest-tie', DateTime(2026, 10, 31, 14), 5.2);
      final entries = [
        newest,
        entry('earlier-tie', newest.measuredAt, 4.9),
        entry('morning', DateTime(2026, 10, 31, 8), 5.1),
        entry('previous-day', DateTime(2026, 10, 30, 22), 5),
        entry('boundary', DateTime(2026, 8, 1), 4.8),
        entry('outside', DateTime(2026, 7, 31), 4.7),
      ];
      final original = List.of(entries);
      final points = weightChartEntries(
        entries,
        WeightChartRange.threeMonths,
        DateTime(2026, 11, 1),
      );
      expect(points.map((value) => value.id), [
        'boundary',
        'previous-day',
        'latest-tie',
      ]);
      expect(points.last, same(newest));
      expect(entries, original);
    },
  );

  test(
    'calendar coordinates ignore time and keep actual gaps between days',
    () {
      final date = DateTime(2026, 10, 25, 23, 50);
      expect(weightChartDay(date), DateTime.utc(2026, 10, 25));
      expect(weightChartDay(date.toUtc()), weightChartDay(date));
      expect(
        weightChartDay(
          DateTime(2026, 11, 1),
        ).difference(weightChartDay(date)).inDays,
        7,
      );
    },
  );

  test('empty periods and all-history retain their distinct meaning', () {
    final old = entry('old', DateTime(2025));
    expect(
      weightChartEntries([old], WeightChartRange.month, DateTime(2026)),
      isEmpty,
    );
    expect(weightChartEntries([old], WeightChartRange.all, DateTime(2026)), [
      old,
    ]);
    expect(
      weightChartEntries([], WeightChartRange.all, DateTime(2026)),
      isEmpty,
    );
  });

  for (final weights in [
    [0.001],
    [4.5, 4.5],
    [4.501, 4.503],
    [0.001, 2000.0],
  ]) {
    test('axis bounds are non-degenerate and include $weights', () {
      final values = [
        for (var i = 0; i < weights.length; i++)
          entry('$i', DateTime(2026, 1, i + 1), weights[i]),
      ];
      final bounds = weightChartBounds(values);
      expect(bounds.min, greaterThanOrEqualTo(0));
      expect(bounds.max, greaterThan(bounds.min));
      expect(bounds.interval, greaterThanOrEqualTo(0.001));
      for (final weight in weights) {
        expect(weight, inInclusiveRange(bounds.min, bounds.max));
      }
    });
  }
}
