import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/features/notification/domain/entities/notification_channel_labels.dart';
import 'package:petlytics/features/notification/domain/entities/notification_reminder.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:petlytics/l10n/generated/app_localizations_en.dart';

class NotificationContent {
  final AppLocalizations strings;
  final Locale locale;

  const NotificationContent(this.strings, this.locale);

  NotificationContent.english()
    : strings = AppLocalizationsEn('en_US'),
      locale = englishLocale;

  NotificationChannelLabels get channels => (
    medicationName: strings.medicationReminders,
    medicationDescription: strings.medicationChannelDescription,
    vaccinationName: strings.vaccinationReminders,
    vaccinationDescription: strings.vaccinationChannelDescription,
  );

  NotificationText medication(
    String petName,
    String name,
    int minute,
    String? instructions,
  ) {
    final time =
        '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
    return (
      title: strings.notificationTitle(petName, name),
      body: instructions == null || instructions.isEmpty
          ? strings.notificationDoseBody(time)
          : strings.notificationDoseInstructions(time, instructions),
    );
  }

  NotificationText vaccination(String petName, String name, DateTime date) => (
    title: strings.notificationTitle(petName, name),
    body: strings.notificationVaccinationBody(
      DateFormat.yMMMd(locale.toLanguageTag()).format(date),
    ),
  );
}
