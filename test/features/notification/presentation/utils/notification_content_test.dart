import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/notification/domain/use_cases/plan_notification_reminders.dart';
import 'package:petlytics/features/notification/presentation/utils/notification_content.dart';
import 'package:petlytics/l10n/generated/app_localizations_tr.dart';

import '../../../../helpers/notification_test_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  final english = englishNotificationContent;
  final turkish = NotificationContent(
    AppLocalizationsTr('tr_TR'),
    turkishLocale,
  );

  test(
    'feeding text localizes grams, keeps the 24-hour time and user food name',
    () {
      expect(
        english.feeding('İnci', 785, 12.5, null).body,
        'Offer 12.5 g at 13:05.',
      );
      expect(
        turkish.feeding('İnci', 785, 12.5, 'Mama {adı}').body,
        '13:05 saatinde 12,5 g Mama {adı} ver.',
      );
      expect(turkish.channels.feedingName, 'Beslenme hatırlatmaları');
    },
  );

  test(
    'localizes notification text and channels, keeping names and instructions verbatim',
    () {
      expect(turkish.medication('İnci 🐾', 'İlaç {adı}', 5, null), (
        title: 'İnci 🐾 · İlaç {adı}',
        body: 'Planlanan doz · 00:05',
      ));
      expect(english.medication('İnci 🐾', 'İlaç {adı}', 785, ''), (
        title: 'İnci 🐾 · İlaç {adı}',
        body: 'Scheduled dose · 13:05',
      ));
      for (final content in [english, turkish]) {
        expect(
          content.medication('İnci', 'İlaç', 785, 'Yarım tablet {½}').body,
          '13:05 · Yarım tablet {½}',
        );
      }
      expect(turkish.channels.medicationName, 'İlaç hatırlatmaları');
      expect(turkish.channels.vaccinationName, 'Aşı hatırlatmaları');
      expect(turkish.channels.medicationDescription, 'Planlanan ilaç dozları');
      expect(
        english.channels.vaccinationDescription,
        'Planned vaccination reminders',
      );
    },
  );

  test(
    'formats the due day using the regional locale, without UTC conversion',
    () {
      final due = DateTime.utc(2030, 4, 5, 23, 55);
      expect(
        english.vaccination('İnci', 'Kuduz', due).body,
        'Vaccination planned for Apr 5, 2030.',
      );
      expect(
        turkish.vaccination('İnci', 'Kuduz', due).body,
        'Aşı tarihi: 5 Nis 2030.',
      );
    },
  );

  test(
    'translated plans retain the same nearest 64 targets, dates, times and queue order',
    () async {
      final h = NotificationTestHarness();
      addTearDown(h.dispose);
      h.medicines.addAll([
        h.medication(times: [660, 780]),
        h.medication(
          id: 'med2',
          petId: 'pet2',
          times: [720],
          dosage: 'Yarım tablet',
        ),
      ]);
      h.vaccines.add(h.vaccination());
      final preferences = NotificationPreferences(
        medicationRemindersEnabled: true,
        vaccinationRemindersEnabled: true,
      );
      final plans = [
        for (final content in [english, turkish])
          const PlanNotificationReminders()(
            h.data,
            preferences,
            h.clock,
            medicationText: content.medication,
            vaccinationText: content.vaccination,
            feedingText: content.feeding,
          ),
      ];
      expect(plans.first.reminders, hasLength(64));
      expect(
        plans.last.reminders.map(
          (r) => (r.target.identityKey, r.scheduledDate, r.scheduledMinute),
        ),
        orderedEquals(
          plans.first.reminders.map(
            (r) => (r.target.identityKey, r.scheduledDate, r.scheduledMinute),
          ),
        ),
      );
      expect(plans.last.hasMore, plans.first.hasMore);
      expect(plans.last.scheduledThrough, plans.first.scheduledThrough);
      expect(
        plans.last.reminders.map((r) => r.title),
        orderedEquals(plans.first.reminders.map((r) => r.title)),
      );
      expect(
        plans.last.reminders
            .where((r) => r.target is VaccinationNotificationTarget)
            .every((r) => r.body.startsWith('Aşı tarihi:')),
        isTrue,
      );
      expect(
        plans.last.reminders
            .where((r) => r.body.startsWith('Planlanan doz'))
            .isNotEmpty,
        isTrue,
      );
    },
  );
}
