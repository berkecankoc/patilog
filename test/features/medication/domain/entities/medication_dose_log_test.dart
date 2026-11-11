import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';

void main() {
  final day = DateTime(2026, 10, 20);
  final actualTime = DateTime.utc(2026, 10, 20, 5, 15);

  MedicationDoseLog given({
    String periodId = 'period-1',
    DateTime? scheduledDate,
    int minute = 480,
    DateTime? givenAt,
  }) => MedicationDoseLog(
    periodId: periodId,
    scheduledDate: scheduledDate ?? day,
    scheduledMinute: minute,
    status: MedicationDoseStatus.given,
    givenAt: givenAt ?? actualTime,
  );

  test('a corrected result differs while retaining the scheduled dose key', () {
    final original = given();
    final corrected = given(
      givenAt: actualTime.add(const Duration(minutes: 5)),
    );
    final skipped = MedicationDoseLog(
      periodId: original.periodId,
      scheduledDate: original.scheduledDate,
      scheduledMinute: original.scheduledMinute,
      status: MedicationDoseStatus.skipped,
    );

    expect(original, given());
    expect(corrected, isNot(original));
    expect(skipped, isNot(original));
    expect(corrected.periodId, original.periodId);
    expect(corrected.scheduledDate, original.scheduledDate);
    expect(corrected.scheduledMinute, original.scheduledMinute);
    expect(skipped.givenAt, isNull);
  });

  test('different periods, days and time slots identify different doses', () {
    expect(given(periodId: 'period-2'), isNot(given()));
    expect(given(scheduledDate: DateTime(2026, 10, 19)), isNot(given()));
    expect(given(minute: 1200), isNot(given()));
  });
}
