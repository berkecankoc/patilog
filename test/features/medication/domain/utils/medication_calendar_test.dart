import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/medication/domain/utils/medication_calendar.dart';

void main() {
  test('time and UTC flags never change a chosen calendar day', () {
    expect(
      calendarDayNumber(DateTime.utc(2026, 10, 20, 23, 59)),
      calendarDayNumber(DateTime(2026, 10, 20)),
    );
  });

  for (final (first, next) in [
    (DateTime(2026, 3, 8), DateTime(2026, 3, 9)),
    (DateTime(2026, 11, 1), DateTime(2026, 11, 2)),
    (DateTime(2024, 2, 29), DateTime(2024, 3, 1)),
    (DateTime(2025, 12, 31), DateTime(2026, 1, 1)),
  ]) {
    test(
      '${next.difference(first).inHours} elapsed hours still represent one calendar day ($first)',
      () {
        expect(calendarDayNumber(next) - calendarDayNumber(first), 1);
      },
    );
  }
}
