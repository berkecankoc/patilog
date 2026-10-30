import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPreferences extends Mock implements SharedPreferencesAsync {}

void main() {
  const key = 'settings.theme_preference';
  const languageKey = 'settings.language_preference';
  late MockPreferences preferences;
  late SettingsRepositoryImpl repository;
  late Map<String, Object?> values;

  setUp(() {
    preferences = MockPreferences();
    repository = SettingsRepositoryImpl(preferences);
    values = {'unrelated.setting': true};
    when(() => preferences.getAll(allowList: {languageKey})).thenAnswer(
      (_) async => {
        if (values.containsKey(languageKey)) languageKey: values[languageKey],
      },
    );
    when(() => preferences.setString(languageKey, any())).thenAnswer((
      call,
    ) async {
      values[languageKey] = call.positionalArguments[1] as String;
    });
    when(
      () => preferences.getAll(allowList: {key}),
    ).thenAnswer((_) async => {if (values.containsKey(key)) key: values[key]});
    when(() => preferences.setString(key, any())).thenAnswer((call) async {
      values[key] = call.positionalArguments[1] as String;
    });
  });

  for (final (stored, expected) in [
    ('system', ThemePreference.system),
    ('light', ThemePreference.light),
    ('dark', ThemePreference.dark),
  ]) {
    test('reads the stored $stored preference without rewriting it', () async {
      values[key] = stored;
      expect(await repository.getThemePreference(), Success(expected));
      verify(() => preferences.getAll(allowList: {key})).called(1);
      verifyNoMoreInteractions(preferences);
    });

    test(
      'saves $stored and reads it through a new repository instance',
      () async {
        expect(
          await repository.setThemePreference(expected),
          const Success<void>(null),
        );
        verify(() => preferences.setString(key, stored)).called(1);
        expect(
          await SettingsRepositoryImpl(preferences).getThemePreference(),
          Success(expected),
        );
        expect(values, {'unrelated.setting': true, key: stored});
      },
    );
  }

  for (final stored in [null, '', 'unknown', 42]) {
    test(
      'missing/unrecognized value $stored uses System without writing',
      () async {
        if (stored != null) values[key] = stored;
        final original = Map<String, Object?>.of(values);
        expect(
          await repository.getThemePreference(),
          const Success(ThemePreference.system),
        );
        expect(values, original);
        verify(() => preferences.getAll(allowList: {key})).called(1);
        verifyNoMoreInteractions(preferences);
      },
    );
  }

  for (final preference in LanguagePreference.values) {
    test(
      'language ${preference.name} survives repository recreation and preserves other settings',
      () async {
        values[key] = 'dark';
        expect(
          await repository.setLanguagePreference(preference),
          const Success<void>(null),
        );
        expect(
          await SettingsRepositoryImpl(preferences).getLanguagePreference(),
          Success(preference),
        );
        expect(values, {
          'unrelated.setting': true,
          key: 'dark',
          languageKey: preference.name,
        });
        expect(
          await repository.getThemePreference(),
          const Success(ThemePreference.dark),
        );
        await repository.setThemePreference(ThemePreference.light);
        expect(await repository.getLanguagePreference(), Success(preference));
      },
    );
  }

  for (final stored in [null, '', 'tr-TR', 42]) {
    test(
      'invalid language $stored follows System without rewriting preferences',
      () async {
        if (stored != null) values[languageKey] = stored;
        final original = Map.of(values);
        expect(
          await repository.getLanguagePreference(),
          const Success(LanguagePreference.system),
        );
        expect(values, original);
        verifyNever(() => preferences.setString(languageKey, any()));
      },
    );
  }

  test(
    'language read and write failures retain the last persisted choice',
    () async {
      values[languageKey] = 'english';
      when(
        () => preferences.getAll(allowList: {languageKey}),
      ).thenThrow(PlatformException(code: 'read_failed'));
      expect(
        await repository.getLanguagePreference(),
        const Error<LanguagePreference>(
          PreferencesStorageFailure('Failed to load language preference'),
        ),
      );
      when(
        () => preferences.setString(languageKey, 'turkish'),
      ).thenThrow(PlatformException(code: 'write_failed'));
      expect(
        await repository.setLanguagePreference(LanguagePreference.turkish),
        const Error<void>(
          PreferencesStorageFailure('Failed to save language preference'),
        ),
      );
      expect(values[languageKey], 'english');
    },
  );

  test('each read uses the current stored value', () async {
    expect(
      await repository.getThemePreference(),
      const Success(ThemePreference.system),
    );
    values[key] = 'dark';
    expect(
      await repository.getThemePreference(),
      const Success(ThemePreference.dark),
    );
    verify(() => preferences.getAll(allowList: {key})).called(2);
  });

  test('a failed read returns a storage failure instead of System', () async {
    when(() => preferences.getAll(allowList: {key})).thenAnswer(
      (_) async => throw PlatformException(
        code: 'read_failed',
        message: 'Internal platform details',
      ),
    );
    expect(
      await repository.getThemePreference(),
      const Error<ThemePreference>(
        PreferencesStorageFailure('Failed to load theme preference'),
      ),
    );
    expect(values, {'unrelated.setting': true});
  });

  test('a failed write returns a storage failure', () async {
    values[key] = 'light';
    when(
      () => preferences.setString(key, 'dark'),
    ).thenAnswer((_) async => throw PlatformException(code: 'write_failed'));
    expect(
      await repository.setThemePreference(ThemePreference.dark),
      const Error<void>(
        PreferencesStorageFailure('Failed to save theme preference'),
      ),
    );
    expect(
      await repository.getThemePreference(),
      const Success(ThemePreference.light),
    );
  });

  test('does not report success before the write completes', () async {
    final write = Completer<void>();
    when(
      () => preferences.setString(key, 'dark'),
    ).thenAnswer((_) => write.future);
    var completed = false;
    final result = repository.setThemePreference(ThemePreference.dark).then((
      value,
    ) {
      completed = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    write.complete();
    expect(await result, const Success<void>(null));
  });
}
