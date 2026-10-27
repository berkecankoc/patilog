import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/notification/domain/entities/notification_data.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/notification/domain/use_cases/plan_notification_reminders.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';
import '../../../../helpers/notification_test_harness.dart';

void main() {
  const planner = PlanNotificationReminders();
  late NotificationTestHarness h;
  final both = NotificationPreferences(
    medicationRemindersEnabled: true,
    vaccinationRemindersEnabled: true,
  );
  setUpAll(() {
    registerFallbackValue(NotificationPreferences());
    registerFallbackValue(DateTime(2030));
  });
  setUp(() => h = NotificationTestHarness());
  tearDown(() => h.dispose());

  test('bounds the combined all-pet queue and exposes its coverage', () {
    h.medicines.addAll([
      h.medication(times: [660, 780]),
      h.medication(id: 'med2', petId: 'pet2', times: [720]),
    ]);
    h.vaccines.add(h.vaccination());
    final plan = planner(h.data, both, h.clock);
    expect(plan.reminders, hasLength(64));
    expect(plan.hasMore, isTrue);
    expect(plan.nextRefreshAt, DateTime(2030, 1, 1, 11));
    expect(plan.scheduledThrough, isNotNull);
    expect(plan.reminders.map((r) => r.target.petId).toSet(), {'pet1', 'pet2'});
    expect(
      plan.reminders.any((r) => r.target is VaccinationNotificationTarget),
      isTrue,
    );
    expect(() => plan.reminders.clear(), throwsUnsupportedError);
    final dates = plan.reminders
        .map(
          (r) => DateTime(
            r.scheduledDate.year,
            r.scheduledDate.month,
            r.scheduledDate.day,
            r.scheduledMinute ~/ 60,
            r.scheduledMinute % 60,
          ),
        )
        .toList();
    expect(dates, orderedEquals([...dates]..sort()));
  });

  test(
    'uses interval arithmetic beyond a fixed horizon and handles extreme intervals',
    () {
      h.medicines.add(h.medication(interval: 365, times: [540]));
      var plan = planner(h.data, both, h.clock);
      expect(plan.reminders.first.scheduledDate, DateTime(2031, 1, 1));
      expect(plan.hasMore, isTrue);
      h.medicines.clear();
      h.medicines.add(h.medication(interval: 9223372036854775807));
      plan = planner(h.data, both, h.clock);
      expect(plan.reminders, hasLength(1));
      expect(plan.hasMore, isFalse);
    },
  );

  test(
    'later periods supersede the old plan permanently, with inclusive ends',
    () {
      h.medicines.add(
        h.medication(
          periods: [
            MedicationPeriod(
              id: 'old',
              medicationId: 'med1',
              startDate: DateTime(2029, 12, 31),
              intervalDays: 1,
              doseTimes: [660],
            ),
            MedicationPeriod(
              id: 'new',
              medicationId: 'med1',
              startDate: DateTime(2030, 1, 3),
              endDate: DateTime(2030, 1, 3),
              intervalDays: 1,
              doseTimes: [720],
            ),
          ],
        ),
      );
      final plan = planner(h.data, both, h.clock);
      expect(plan.reminders.map((r) => r.scheduledDate), [
        DateTime(2030, 1, 1),
        DateTime(2030, 1, 2),
        DateTime(2030, 1, 3),
      ]);
      expect(
        (plan.reminders.last.target as MedicationDoseNotificationTarget)
            .periodId,
        'new',
      );
      expect(plan.hasMore, isFalse);
    },
  );

  test(
    'omits Given and Skipped, never catches up past or current-minute doses',
    () {
      h.medicines.add(
        h.medication(
          times: [540, 600, 660, 720, 780],
          end: DateTime(2030, 1, 1),
        ),
      );
      for (final (minute, status) in [
        (720, MedicationDoseStatus.given),
        (780, MedicationDoseStatus.skipped),
      ]) {
        h.logs.add(
          MedicationDoseLog(
            periodId: 'period-med1',
            scheduledDate: DateTime.utc(2030, 1, 1),
            scheduledMinute: minute,
            status: status,
            givenAt: status == MedicationDoseStatus.given ? h.clock : null,
          ),
        );
      }
      final plan = planner(h.data, both, h.clock);
      expect(plan.reminders.map((r) => r.scheduledMinute), [660]);
      expect(plan.reminders.single.title, 'Milo · Medicine med1');
    },
  );

  test('supports inherited, Custom and Off vaccination schedules', () {
    h.vaccines.addAll([
      h.vaccination(),
      h.vaccination(
        id: 'custom',
        settings: VaccinationReminderSettings.custom(
          VaccinationReminderSchedule(daysBefore: [2, 0], minuteOfDay: 720),
        ),
      ),
      h.vaccination(
        id: 'off',
        settings: const VaccinationReminderSettings.off(),
      ),
      h.vaccination(id: 'given', status: VaccinationStatus.administered),
      h.vaccination(id: 'overdue', date: DateTime(2029, 12, 31)),
    ]);
    final plan = planner(h.data, both, h.clock);
    expect(plan.reminders, hasLength(4));
    expect(
      plan.reminders
          .map((r) => (r.target as VaccinationNotificationTarget).vaccinationId)
          .toSet(),
      {'vax1', 'custom'},
    );
    expect(plan.reminders.first.scheduledDate, DateTime(2030, 1, 2));
    expect(plan.reminders.first.scheduledMinute, 720);
    expect(plan.reminders.last.body, 'Vaccination planned for 2030-01-04.');
  });

  test(
    'global Off overrides per-record Custom and preserves medication independence',
    () {
      h.medicines.add(h.medication());
      h.vaccines.add(
        h.vaccination(
          settings: VaccinationReminderSettings.custom(
            VaccinationReminderSchedule(),
          ),
        ),
      );
      expect(
        planner(h.data, NotificationPreferences(), h.clock).reminders,
        isEmpty,
      );
      final medOnly = planner(
        h.data,
        NotificationPreferences(medicationRemindersEnabled: true),
        h.clock,
      );
      expect(
        medOnly.reminders.every(
          (r) => r.target is MedicationDoseNotificationTarget,
        ),
        isTrue,
      );
    },
  );

  test(
    'uses calendar components across year boundaries without shifting UTC dates',
    () {
      h.clock = DateTime(2029, 12, 28);
      h.vaccines.add(
        h.vaccination(
          date: DateTime.utc(2030, 1, 1, 23),
          settings: VaccinationReminderSettings.custom(
            VaccinationReminderSchedule(daysBefore: [3], minuteOfDay: 540),
          ),
        ),
      );
      final plan = planner(h.data, both, h.clock);
      expect(plan.reminders.single.scheduledDate, DateTime(2029, 12, 29));
      expect(plan.reminders.single.scheduledMinute, 540);
    },
  );

  test('omits missing pet owners and does not invent fallback names', () {
    h.directory.removeLast();
    h.medicines.add(h.medication(petId: 'pet2'));
    h.vaccines.add(h.vaccination(petId: 'pet2'));
    expect(planner(h.data, both, h.clock).reminders, isEmpty);
  });

  test(
    'known deletion filters owner/record snapshots without mutating the source',
    () {
      h.medicines.addAll([
        h.medication(),
        h.medication(id: 'other', petId: 'pet2'),
      ]);
      h.vaccines.addAll([
        h.vaccination(),
        h.vaccination(id: 'other', petId: 'pet2'),
      ]);
      final original = h.data;
      final removed = original.without(petId: 'pet1', petDeleted: true);
      expect(removed.pets.map((p) => p.id), ['pet2']);
      expect(removed.medications.map((m) => m.petId), ['pet2']);
      expect(original.medications, hasLength(2));
      expect(
        original.without(petId: 'pet2', medicationId: 'med1').medications,
        hasLength(2),
      );
      expect(
        original
            .without(petId: 'pet1', vaccinationId: 'vax1')
            .vaccinations
            .map((v) => v.id),
        ['other'],
      );
      expect(() => original.pets.clear(), throwsUnsupportedError);
      final copied = NotificationData(pets: h.directory);
      h.directory.clear();
      expect(copied.pets, hasLength(2));
    },
  );
}
