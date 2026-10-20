import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';

void main() {
  const calculate = CalculateMedicationDoses();
  DateTime day(int day) => DateTime(2026, 10, day);
  MedicationPeriod period({
    String id = 'period',
    String medicationId = 'medicine',
    DateTime? start,
    DateTime? end,
    int interval = 1,
    List<int> times = const [480, 1200],
  }) => MedicationPeriod(
    id: id,
    medicationId: medicationId,
    startDate: start ?? day(20),
    endDate: end,
    intervalDays: interval,
    doseTimes: times,
  );
  Medication medicine({
    String id = 'medicine',
    String name = 'Medicine',
    List<MedicationPeriod>? periods,
  }) => Medication(
    id: id,
    petId: 'pet',
    name: name,
    periods: periods ?? [period(medicationId: id)],
  );

  test(
    'daily doses have inclusive calendar bounds and chronological order',
    () {
      final doses = calculate(
        medications: [medicine()],
        logs: [],
        fromDate: DateTime.utc(2026, 10, 20, 23),
        toDate: day(22),
      );
      expect(doses.map((dose) => (dose.scheduledDate, dose.scheduledMinute)), [
        for (final date in [day(20), day(21), day(22)])
          for (final minute in [480, 1200]) (date, minute),
      ]);
      expect(doses.every((dose) => dose.log == null), isTrue);
      expect(() => doses.clear(), throwsUnsupportedError);
    },
  );

  test('an open-ended old plan expands only the requested range', () {
    final doses = calculate(
      medications: [
        medicine(periods: [period(start: DateTime(1900))]),
      ],
      logs: [],
      fromDate: day(20),
      toDate: day(21),
    );
    expect(doses.length, 4);
    expect(doses.first.scheduledDate, day(20));
    expect(doses.last.scheduledDate, day(21));
  });

  test(
    'a successor replaces the earlier plan and anchors its own interval',
    () {
      final doses = calculate(
        medications: [
          medicine(
            periods: [
              period(
                id: 'next',
                start: day(22),
                interval: 2,
                end: day(24),
                times: [600],
              ),
              period(end: day(30)),
            ],
          ),
        ],
        logs: [],
        fromDate: day(21),
        toDate: day(26),
      );
      expect(
        doses.map(
          (dose) => (dose.period.id, dose.scheduledDate, dose.scheduledMinute),
        ),
        [
          ('period', day(21), 480),
          ('period', day(21), 1200),
          ('next', day(22), 600),
          ('next', day(24), 600),
        ],
      );
    },
  );

  test('single-day use and gaps do not produce extra occurrences', () {
    final doses = calculate(
      medications: [
        medicine(
          periods: [
            period(start: day(20), end: day(20), times: [480]),
            period(id: 'next', start: day(23), end: day(23), times: [600]),
          ],
        ),
      ],
      logs: [],
      fromDate: day(19),
      toDate: day(24),
    );
    expect(doses.map((dose) => dose.scheduledDate), [day(20), day(23)]);
  });

  test(
    'results match period, calendar day and minute rather than actual time',
    () {
      final given = MedicationDoseLog(
        periodId: 'period',
        scheduledDate: DateTime.utc(2026, 10, 20, 23),
        scheduledMinute: 480,
        status: MedicationDoseStatus.given,
        givenAt: day(21),
      );
      final skipped = MedicationDoseLog(
        periodId: 'period',
        scheduledDate: day(20),
        scheduledMinute: 1200,
        status: MedicationDoseStatus.skipped,
      );
      final unrelated = MedicationDoseLog(
        periodId: 'other',
        scheduledDate: day(21),
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      );
      final doses = calculate(
        medications: [medicine()],
        logs: [given, skipped, unrelated],
        fromDate: day(20),
        toDate: day(21),
      );
      expect(doses.map((dose) => dose.log), [given, skipped, null, null]);
    },
  );

  test('a correction changes the result without moving the scheduled dose', () {
    final medication = medicine();
    List<MedicationDoseLog> logAt(int hour) => [
      MedicationDoseLog(
        periodId: 'period',
        scheduledDate: day(20),
        scheduledMinute: 480,
        status: MedicationDoseStatus.given,
        givenAt: DateTime(2026, 10, 20, hour),
      ),
    ];
    final original = calculate(
      medications: [medication],
      logs: logAt(8),
      fromDate: day(20),
      toDate: day(20),
    );
    final corrected = calculate(
      medications: [medication],
      logs: logAt(16),
      fromDate: day(20),
      toDate: day(20),
    );
    expect(original.first, isNot(corrected.first));
    expect(
      original.map((dose) => dose.scheduledMinute),
      corrected.map((dose) => dose.scheduledMinute),
    );
    expect(corrected.last.log, isNull);
  });

  test('same-time doses sort by medication name and stable identity', () {
    final doses = calculate(
      medications: [
        medicine(
          id: 'z',
          name: 'Zulu',
          periods: [
            period(id: 'p-z', medicationId: 'z', times: [480]),
          ],
        ),
        medicine(
          id: 'b',
          name: 'alpha',
          periods: [
            period(id: 'p-b', medicationId: 'b', times: [480]),
          ],
        ),
        medicine(
          id: 'a',
          name: 'Alpha',
          periods: [
            period(id: 'p-a', medicationId: 'a', times: [480]),
          ],
        ),
      ],
      logs: [],
      fromDate: day(20),
      toDate: day(20),
    );
    expect(doses.map((dose) => dose.medication.id), ['a', 'b', 'z']);
  });

  test('leap days and year boundaries retain interval alignment', () {
    final leap = calculate(
      medications: [
        medicine(
          periods: [
            period(start: DateTime(2024, 2, 28), interval: 2, times: [480]),
          ],
        ),
      ],
      logs: [],
      fromDate: DateTime(2024, 2, 28),
      toDate: DateTime(2024, 3, 2),
    );
    expect(leap.map((dose) => dose.scheduledDate), [
      DateTime(2024, 2, 28),
      DateTime(2024, 3, 1),
    ]);
    final year = calculate(
      medications: [
        medicine(
          periods: [
            period(start: DateTime(2025, 12, 31), interval: 2, times: [480]),
          ],
        ),
      ],
      logs: [],
      fromDate: DateTime(2025, 12, 31),
      toDate: DateTime(2026, 1, 3),
    );
    expect(year.map((dose) => dose.scheduledDate), [
      DateTime(2025, 12, 31),
      DateTime(2026, 1, 2),
    ]);
  });

  test('empty or nonoverlapping ranges have no doses', () {
    expect(
      calculate(medications: [], logs: [], fromDate: day(20), toDate: day(21)),
      isEmpty,
    );
    expect(
      calculate(
        medications: [medicine()],
        logs: [],
        fromDate: day(18),
        toDate: day(19),
      ),
      isEmpty,
    );
    expect(
      calculate(
        medications: [medicine()],
        logs: [],
        fromDate: day(21),
        toDate: day(20),
      ),
      isEmpty,
    );
  });
}
