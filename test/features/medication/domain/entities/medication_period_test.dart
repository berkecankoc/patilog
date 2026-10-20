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
}
