import 'dart:math' as math;

import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';

enum WeightChartRange { month, threeMonths, sixMonths, all }

DateTime weightChartDay(DateTime value) {
  final local = value.toLocal();
  // UTC is only a coordinate for calendar-day distances, never a stored value.
  return DateTime.utc(local.year, local.month, local.day);
}

DateTime? weightChartStart(WeightChartRange range, DateTime now) {
  final months = switch (range) {
    WeightChartRange.month => 1,
    WeightChartRange.threeMonths => 3,
    WeightChartRange.sixMonths => 6,
    WeightChartRange.all => null,
  };
  if (months == null) return null;
  final month = DateTime.utc(now.year, now.month - months);
  final lastDay = DateTime.utc(month.year, month.month + 1, 0).day;
  return DateTime.utc(month.year, month.month, math.min(now.day, lastDay));
}

/// The repository's newest-first order decides the last measurement of a day,
/// including insertion-order ties. The original entries remain unchanged.
List<WeightEntry> weightChartEntries(
  List<WeightEntry> entries,
  WeightChartRange range,
  DateTime now,
) {
  final start = weightChartStart(range, now);
  final byDay = <DateTime, WeightEntry>{};
  for (final entry in entries) {
    final day = weightChartDay(entry.measuredAt);
    if (start == null || !day.isBefore(start)) {
      byDay.putIfAbsent(day, () => entry);
    }
  }
  return byDay.values.toList().reversed.toList();
}

({double min, double max, double interval}) weightChartBounds(
  List<WeightEntry> entries,
) {
  final low = entries.map((entry) => entry.weight).reduce(math.min);
  final high = entries.map((entry) => entry.weight).reduce(math.max);
  final span = math.max(high - low, high * 0.1);
  final magnitude = math.pow(10, (math.log(span / 3) / math.ln10).floor());
  final fraction = span / 3 / magnitude;
  final step = fraction <= 1
      ? 1
      : (fraction <= 2 ? 2 : (fraction <= 5 ? 5 : 10));
  final interval = math.max(0.001, step * magnitude).toDouble();
  return (
    min: math.max(0, (low / interval).floor() * interval - interval).toDouble(),
    max: (high / interval).ceil() * interval + interval,
    interval: interval,
  );
}
