import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';

void main() {
  MedicationPeriod period({
    List<int> times = const [480, 1200],
    String dosage = 'Half a tablet',
  }) => MedicationPeriod(
    id: 'period-1',
    medicationId: 'medication-1',
    startDate: DateTime(2026, 10, 20),
    intervalDays: 1,
    doseTimes: times,
    dosageInstructions: dosage,
  );

  test('choosing the same times in another order does not change the plan', () {
    expect(period(times: [1200, 480]), period());
  });

  test('sorting and later caller mutations cannot alter a captured plan', () {
    final times = [1200, 480];
    final captured = period(times: times);
    expect(times, [1200, 480]);

    times[0] = 600;

    expect(captured.doseTimes, [480, 1200]);
    expect(() => captured.doseTimes.add(600), throwsUnsupportedError);
  });

  test('duplicate times remain visible for write validation', () {
    expect(period(times: [480, 480]).doseTimes, [480, 480]);
  });

  test('a changed time or dosage is a different plan with the same ID', () {
    expect(period(times: [540, 1200]), isNot(period()));
    expect(period(dosage: 'One tablet'), isNot(period()));
  });

  test('a period is active between doses, with an inclusive end day', () {
    final treatment = MedicationPeriod(
      id: 'period',
      medicationId: 'medicine',
      startDate: DateTime(2026, 12, 30),
      endDate: DateTime(2027, 1, 3),
      intervalDays: 2,
      doseTimes: [480],
    );
    expect(treatment.isActiveOn(DateTime(2026, 12, 29)), isFalse);
    expect(treatment.isActiveOn(DateTime(2026, 12, 31)), isTrue);
    expect(treatment.isScheduledDose(DateTime(2026, 12, 31), 480), isFalse);
    expect(
      treatment.isScheduledDose(DateTime.utc(2027, 1, 1, 23), 480),
      isTrue,
    );
    expect(treatment.isScheduledDose(DateTime(2027, 1, 3), 480), isTrue);
    expect(treatment.isActiveOn(DateTime(2027, 1, 4)), isFalse);
    expect(treatment.isScheduledDose(DateTime(2027, 1, 1), 600), isFalse);
  });

  test(
    'a successor closes the earlier period even when its stored end is later',
    () {
      final treatment = period();
      final next = DateTime.utc(2026, 10, 22, 23);
      expect(
        treatment.isScheduledDose(
          DateTime(2026, 10, 21),
          480,
          nextPeriodStart: next,
        ),
        isTrue,
      );
      expect(
        treatment.isActiveOn(DateTime(2026, 10, 22), nextPeriodStart: next),
        isFalse,
      );
      expect(
        treatment.isScheduledDose(
          DateTime(2026, 10, 22),
          480,
          nextPeriodStart: next,
        ),
        isFalse,
      );
    },
  );
}
