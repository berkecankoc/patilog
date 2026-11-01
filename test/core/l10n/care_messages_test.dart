import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

void main() {
  test(
    'English plurals interpolate numbers rather than displaying ICU markers',
    () async {
      final strings = await AppLocalizations.delegate.load(englishLocale);
      expect(strings.doseCount(0), '0 doses');
      expect(strings.doseCount(1), '1 dose');
      expect(strings.doseCount(2), '2 doses');
      expect(strings.doseCountRecorded(2, 1), '2 doses · 1 recorded');
      expect(strings.reminderDaysBefore(1), '1 day before');
      expect(strings.reminderDaysBefore(3), '3 days before');
      expect(strings.medicationEveryDays(1), 'Every 1 day');
      expect(strings.medicationEveryDays(2), 'Every 2 days');
      expect(strings.maxCharacters(200), 'Use 200 characters or fewer.');
      expect(
        strings.queuedReminderSummary(1, 'Apr 5, 2026'),
        '1 reminder queued through Apr 5, 2026.',
      );
      expect(
        strings.queuedReminderSummary(64, 'Apr 5, 2026'),
        '64 reminders queued through Apr 5, 2026.',
      );
    },
  );

  test(
    'Turkish counts and inserted names stay natural and preserve user text',
    () async {
      final strings = await AppLocalizations.delegate.load(turkishLocale);
      expect(strings.doseCount(0), '0 doz');
      expect(strings.doseCount(1), '1 doz');
      expect(strings.doseCount(2), '2 doz');
      expect(strings.doseCountRecorded(2, 1), '2 doz · 1 kayıtlı');
      expect(strings.reminderDaysBefore(3), '3 gün önce');
      expect(strings.medicationEveryDays(2), '2 günde bir');
      expect(
        strings.queuedReminderSummary(64, '5 Nis 2026'),
        '5 Nis 2026 tarihine kadar 64 hatırlatma hazır.',
      );
      expect(
        strings.deleteMedicationMessage('İnci {adı} 🐾'),
        'İnci {adı} 🐾 adlı ilaç, tüm kullanım planları ve doz kayıtları silinsin mi?',
      );
    },
  );
}
