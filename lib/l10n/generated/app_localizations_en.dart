// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersDescription =>
      'Medication doses and planned vaccinations';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get followDeviceSettings => 'Follow device settings';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get followDeviceLanguage => 'Follow device language';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get loadingSettings => 'Loading settings';

  @override
  String get savingSettings => 'Saving settings';

  @override
  String get retry => 'Retry';

  @override
  String get themeLoadFailed => 'Failed to load theme preference';

  @override
  String get languageLoadFailed => 'Failed to load language preference';

  @override
  String get settingsLoadFailed => 'Failed to load settings';

  @override
  String get themeSaveFailed => 'Failed to save theme preference';

  @override
  String get languageSaveFailed => 'Failed to save language preference';
}
