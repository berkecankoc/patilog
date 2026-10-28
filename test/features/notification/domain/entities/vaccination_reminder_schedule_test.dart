import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';

void main() {
  test('defaults are 3/1/0 calendar days before at 09:00', () {
    final schedule = VaccinationReminderSchedule();
    expect(schedule.daysBefore, [3, 1, 0]);
    expect(schedule.minuteOfDay, 540);
  });

  test('input order and later mutations cannot change a captured schedule', () {
    final days = [0, 3, 1];
    final schedule = VaccinationReminderSchedule(daysBefore: days);
    expect(days, [0, 3, 1]);
    days[0] = 7;
    expect(schedule.daysBefore, [3, 1, 0]);
    expect(schedule, VaccinationReminderSchedule());
    expect(() => schedule.daysBefore.add(7), throwsUnsupportedError);
  });

  test('duplicates remain visible to write validation', () {
    expect(VaccinationReminderSchedule(daysBefore: [1, 1]).daysBefore, [1, 1]);
  });

  test('changing days or local time changes the schedule value', () {
    expect(
      VaccinationReminderSchedule(daysBefore: [7, 0]),
      isNot(VaccinationReminderSchedule()),
    );
    expect(
      VaccinationReminderSchedule(minuteOfDay: 600),
      isNot(VaccinationReminderSchedule()),
    );
  });
}
