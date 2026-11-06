import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';

import '../../helpers/multi_step_form_helpers.dart';

void main() {
  setUpAll(loadFormTestFont);
  for (final locale in [englishLocale, turkishLocale]) {
    testWidgets(
      'date errors remain readable on narrow large-text screens in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late String message;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light,
            home: Builder(
              builder: (context) {
                final strings = AppLocalizations.of(context);
                message = strings.periodEndInvalid;
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppDateField(
                        labelText: strings.endDateOptional,
                        value: DateTime(2026, 11, 5),
                        firstDate: DateTime(2026, 11, 6),
                        lastDate: DateTime(2100),
                        errorText: message,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final text = find.text(message);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
        );
        expect(text.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'locale changes refresh an open date picker and field without changing the day',
    (tester) async {
      final locale = ValueNotifier(turkishLocale);
      final value = ValueNotifier<DateTime?>(DateTime(2026, 4, 5));
      addTearDown(locale.dispose);
      addTearDown(value.dispose);
      var changes = 0;
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, selectedLocale, _) => MaterialApp(
            locale: selectedLocale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ValueListenableBuilder<DateTime?>(
                valueListenable: value,
                builder: (context, date, _) => AppDateField(
                  labelText: AppLocalizations.of(context).birthDateOptional,
                  value: date,
                  clearable: true,
                  firstDate: DateTime(1980),
                  lastDate: DateTime(2030),
                  onChanged: (date) {
                    changes++;
                    value.value = date;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('5 Nis 2026'), findsOneWidget);
      expect(
        find.byTooltip('Doğum tarihi (isteğe bağlı): tarihi temizle'),
        findsOneWidget,
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Nisan 2026'), findsOneWidget);
      locale.value = englishLocale;
      await tester.pumpAndSettle();
      expect(find.text('April 2026'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Apr 5, 2026'), findsOneWidget);
      expect(value.value, DateTime(2026, 4, 5));
      expect(changes, 0);
      await tester.tap(find.byTooltip('Birth date (optional): clear date'));
      await tester.pumpAndSettle();
      expect(value.value, isNull);
      expect(changes, 1);
      expect(
        find.byTooltip('Birth date (optional): choose date'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'read-only date stays legible and cannot open or clear until unlocked',
    (tester) async {
      final locked = ValueNotifier(true);
      addTearDown(locked.dispose);
      DateTime? selected = DateTime(2020, 1, 2);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: locked,
              builder: (_, readOnly, _) => AppDateField(
                labelText: 'Date',
                value: selected,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                clearable: true,
                readOnly: readOnly,
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Jan 2, 2020'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(selected, DateTime(2020, 1, 2));
      locked.value = false;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Date: clear date'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    },
  );

  testWidgets(
    'an empty future-date field opens on today rather than the upper limit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AppDateField(
              labelText: 'Next dose',
              value: null,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Next dose: choose date'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        DateUtils.dateOnly(DateTime.now()),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed bounds clamp picker initial date without changing the stored value on cancel',
    (tester) async {
      DateTime? selected = DateTime(2030, 1, 2);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AppDateField(
              labelText: 'Date',
              value: selected,
              firstDate: DateTime(2000),
              lastDate: DateTime(2020),
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Date: choose date'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        DateTime(2020),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2030, 1, 2));
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> pumpField(
    WidgetTester tester,
    ValueNotifier<DateTime?> value,
  ) async {
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.light,
        home: Scaffold(
          body: ValueListenableBuilder<DateTime?>(
            valueListenable: value,
            builder: (context, date, _) => AppDateField(
              labelText: 'Birth date',
              value: date,
              clearable: true,
              firstDate: DateTime(1980),
              lastDate: DateTime(2026, 10, 13),
              onChanged: (selected) => value.value = selected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('displays a date and can clear the optional value', (
    tester,
  ) async {
    final value = ValueNotifier<DateTime?>(DateTime(2022, 7, 11));
    await pumpField(tester, value);
    expect(find.text('Jul 11, 2022'), findsOneWidget);
    await tester.tap(find.byTooltip('Birth date: clear date'));
    await tester.pumpAndSettle();
    expect(value.value, isNull);
    expect(find.text('Jul 11, 2022'), findsNothing);
    expect(find.byTooltip('Birth date: choose date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection updates the field and cancellation preserves it', (
    tester,
  ) async {
    final value = ValueNotifier<DateTime?>(null);
    await pumpField(tester, value);
    await tester.tap(find.byTooltip('Birth date: choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(value.value, DateTime(2026, 10, 12));
    expect(find.text('Oct 12, 2026'), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(value.value, DateTime(2026, 10, 12));
    expect(tester.takeException(), isNull);
  });
}
