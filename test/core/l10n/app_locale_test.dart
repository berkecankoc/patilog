import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:patilog/core/l10n/app_locale.dart';
import 'package:patilog/features/settings/domain/entities/language_preference.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

void main() {
  test(
    'System resolves the first supported language with an explicit US fallback',
    () {
      expect(resolveAppLocale(null, appSupportedLocales), englishLocale);
      expect(
        resolveAppLocale([const Locale('fr', 'FR')], appSupportedLocales),
        englishLocale,
      );
      expect(
        resolveAppLocale([
          const Locale('fr'),
          const Locale('tr', 'CY'),
          englishLocale,
        ], appSupportedLocales),
        turkishLocale,
      );
      expect(
        resolveAppLocale([
          const Locale('en', 'GB'),
          turkishLocale,
        ], appSupportedLocales),
        englishLocale,
      );
      expect(LanguagePreference.system.locale, isNull);
      expect(LanguagePreference.turkish.locale, turkishLocale);
      expect(LanguagePreference.english.locale, englishLocale);
    },
  );

  for (final locale in appSupportedLocales) {
    testWidgets(
      '${locale.toLanguageTag()} loads app, Material and Cupertino delegates with regional dates and numbers',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dates = MaterialLocalizations.of(context);
        final turkish = locale == turkishLocale;
        expect(Localizations.localeOf(context), locale);
        expect(
          AppLocalizations.of(context).settingsTitle,
          turkish ? 'Ayarlar' : 'Settings',
        );
        expect(dates.firstDayOfWeekIndex, turkish ? 1 : 0);
        expect(
          dates.formatFullDate(DateTime(2026, 10, 29)),
          contains(turkish ? 'Ekim' : 'October'),
        );
        expect(
          dates.formatCompactDate(DateTime(2026, 4, 5)),
          turkish ? '05.04.2026' : '4/5/2026',
        );
        expect(
          NumberFormat.decimalPattern(locale.toString()).format(1234.56),
          turkish ? '1.234,56' : '1,234.56',
        );
        expect(dates.backButtonTooltip, turkish ? 'Geri' : 'Back');
        expect(
          CupertinoLocalizations.of(context).todayLabel,
          turkish ? 'Bugün' : 'Today',
        );
        expect(
          dates.formatTimeOfDay(
            const TimeOfDay(hour: 13, minute: 5),
            alwaysUse24HourFormat: true,
          ),
          '13:05',
        );
      },
    );
  }
}
