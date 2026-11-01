import 'package:flutter/widgets.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';

const englishLocale = Locale('en', 'US');
const turkishLocale = Locale('tr', 'TR');
const appSupportedLocales = [englishLocale, turkishLocale];

extension LanguagePreferenceLocale on LanguagePreference {
  Locale? get locale => switch (this) {
    LanguagePreference.system => null,
    LanguagePreference.turkish => turkishLocale,
    LanguagePreference.english => englishLocale,
  };
}

Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return englishLocale;
}
