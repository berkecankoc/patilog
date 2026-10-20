import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/medication/data/models/medication_dose_log_model.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';

void main() {
  test('scheduled day stays a calendar day while actual time is UTC', () {
    final time = DateTime.parse('2026-10-20T10:15:00+03:00');
    final log = MedicationDoseLog(
      periodId: 'period',
      scheduledDate: DateTime.utc(2026, 10, 20, 23),
      scheduledMinute: 480,
      status: MedicationDoseStatus.given,
      givenAt: time,
    );
    final json = MedicationDoseLogModel.fromEntity(log).toJson();
    expect(json['scheduled_date'], '2026-10-20');
    expect(json['given_at'], '2026-10-20T07:15:00.000Z');
    final loaded = MedicationDoseLogModel.fromJson(json).toEntity();
    expect(loaded.scheduledDate, DateTime(2026, 10, 20));
    expect(loaded.givenAt!.isAtSameMomentAs(time), isTrue);
    expect(loaded.givenAt!.isUtc, isTrue);
  });

  test('skipped dose retains its natural key without an actual time', () {
    final log = MedicationDoseLog(
      periodId: 'period',
      scheduledDate: DateTime(2026, 10, 20),
      scheduledMinute: 1200,
      status: MedicationDoseStatus.skipped,
    );
    expect(
      MedicationDoseLogModel.fromJson(
        MedicationDoseLogModel.fromEntity(log).toJson(),
      ).toEntity(),
      log,
    );
  });
}
