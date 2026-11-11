import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/settings/domain/entities/theme_preference.dart';
import 'package:patilog/features/settings/domain/entities/language_preference.dart';
import 'package:patilog/features/settings/domain/repositories/settings_repository.dart';
import 'package:patilog/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:patilog/features/settings/presentation/cubit/settings_state.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository repository;
  const light = SettingsState(
    themePreference: ThemePreference.light,
    hasLoadedTheme: true,
    hasLoadedLanguage: true,
  );
  const readError = Error<ThemePreference>(
    PreferencesStorageFailure('Read failed'),
  );
  const writeError = Error<void>(PreferencesStorageFailure('Write failed'));

  setUpAll(() {
    registerFallbackValue(ThemePreference.system);
    registerFallbackValue(LanguagePreference.system);
  });
  setUp(() {
    repository = MockSettingsRepository();
    when(
      repository.getLanguagePreference,
    ).thenAnswer((_) async => const Success(LanguagePreference.system));
    when(
      () => repository.setLanguagePreference(any()),
    ).thenAnswer((_) async => const Success<void>(null));
    when(
      repository.getThemePreference,
    ).thenAnswer((_) async => const Success(ThemePreference.light));
    when(
      () => repository.setThemePreference(any()),
    ).thenAnswer((_) async => const Success<void>(null));
  });

  SettingsCubit makeCubit() => SettingsCubit(repository);

  test('initial System is a fallback until a preference is loaded', () {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    expect(cubit.state, const SettingsState());
    expect(cubit.state.isBusy, isFalse);
    verifyZeroInteractions(repository);
  });

  for (final (result, expected) in [
    (const Success(ThemePreference.light), light),
    (
      readError,
      const SettingsState(hasLoadedLanguage: true, loadError: 'Read failed'),
    ),
  ]) {
    blocTest<SettingsCubit, SettingsState>(
      'load returns ${expected.loadError == null ? 'the stored preference' : 'System with a retryable error'}',
      build: () {
        when(repository.getThemePreference).thenAnswer((_) async => result);
        return makeCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [const SettingsState(isLoading: true), expected],
    );
  }

  for (final (result, expected) in [
    (
      const Success<void>(null),
      const SettingsState(
        themePreference: ThemePreference.dark,
        hasLoadedTheme: true,
        hasLoadedLanguage: true,
      ),
    ),
    (
      writeError,
      light.copyWith(
        saveError: 'Write failed',
        failedThemePreference: ThemePreference.dark,
      ),
    ),
  ]) {
    blocTest<SettingsCubit, SettingsState>(
      'save ${expected.saveError == null ? 'applies the persisted preference' : 'keeps the previous preference and failed target'}',
      build: () {
        when(
          () => repository.setThemePreference(ThemePreference.dark),
        ).thenAnswer((_) async => result);
        return makeCubit();
      },
      seed: () => light,
      act: (cubit) => cubit.setThemePreference(ThemePreference.dark),
      expect: () => [light.copyWith(isSaving: true), expected],
    );
  }

  test('retries a failed read and clears its error while waiting', () async {
    when(repository.getThemePreference).thenAnswer((_) async => readError);
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.load();
    final pending = Completer<Result<ThemePreference>>();
    when(repository.getThemePreference).thenAnswer((_) => pending.future);
    final retry = cubit.load();
    expect(
      cubit.state,
      const SettingsState(hasLoadedLanguage: true, isLoading: true),
    );
    pending.complete(const Success(ThemePreference.dark));
    await retry;
    expect(
      cubit.state,
      const SettingsState(
        themePreference: ThemePreference.dark,
        hasLoadedTheme: true,
        hasLoadedLanguage: true,
      ),
    );
    verify(repository.getThemePreference).called(2);
  });

  test('serializes loading and does not reread confirmed settings', () async {
    final pending = Completer<Result<ThemePreference>>();
    when(repository.getThemePreference).thenAnswer((_) => pending.future);
    final cubit = makeCubit();
    addTearDown(cubit.close);
    final load = cubit.load();
    expect(cubit.state.isBusy, isTrue);
    await cubit.load();
    await cubit.setThemePreference(ThemePreference.dark);
    pending.complete(const Success(ThemePreference.light));
    await load;
    await cubit.load();
    verify(repository.getThemePreference).called(1);
    verifyNever(() => repository.setThemePreference(any()));
  });

  test('does not persist a preference that is already confirmed', () async {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.setThemePreference(ThemePreference.light);
    expect(cubit.state, light);
    verifyNever(() => repository.setThemePreference(any()));
  });

  test(
    'System can be explicitly saved after an initial read failure',
    () async {
      when(repository.getThemePreference).thenAnswer((_) async => readError);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.setThemePreference(ThemePreference.system);
      expect(
        cubit.state,
        const SettingsState(hasLoadedTheme: true, hasLoadedLanguage: true),
      );
      verify(
        () => repository.setThemePreference(ThemePreference.system),
      ).called(1);
    },
  );

  test(
    'applies a new theme only after success and blocks other operations',
    () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      final pending = Completer<Result<void>>();
      when(
        () => repository.setThemePreference(ThemePreference.dark),
      ).thenAnswer((_) => pending.future);
      final save = cubit.setThemePreference(ThemePreference.dark);
      expect(cubit.state.themePreference, ThemePreference.light);
      expect(cubit.state.isBusy, isTrue);
      await cubit.setThemePreference(ThemePreference.system);
      await cubit.setThemePreference(ThemePreference.dark);
      await cubit.load();
      pending.complete(const Success<void>(null));
      await save;
      await cubit.setThemePreference(ThemePreference.dark);
      expect(cubit.state.themePreference, ThemePreference.dark);
      expect(cubit.state.isBusy, isFalse);
      verify(
        () => repository.setThemePreference(ThemePreference.dark),
      ).called(1);
      verifyNever(() => repository.setThemePreference(ThemePreference.system));
      verify(repository.getThemePreference).called(1);
    },
  );

  test(
    'save retry uses the failed target and clears its error while waiting',
    () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      when(
        () => repository.setThemePreference(ThemePreference.dark),
      ).thenAnswer((_) async => writeError);
      await cubit.setThemePreference(ThemePreference.dark);
      final pending = Completer<Result<void>>();
      when(
        () => repository.setThemePreference(ThemePreference.dark),
      ).thenAnswer((_) => pending.future);
      final retry = cubit.retrySave();
      expect(cubit.state, light.copyWith(isSaving: true));
      await cubit.retrySave();
      pending.complete(const Success<void>(null));
      await retry;
      expect(
        cubit.state,
        const SettingsState(
          themePreference: ThemePreference.dark,
          hasLoadedTheme: true,
          hasLoadedLanguage: true,
        ),
      );
      verify(
        () => repository.setThemePreference(ThemePreference.dark),
      ).called(2);
      verify(repository.getThemePreference).called(1);
      await cubit.retrySave();
      verify(repository.getLanguagePreference).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('a different choice replaces an earlier failed save target', () async {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.load();
    when(
      () => repository.setThemePreference(ThemePreference.dark),
    ).thenAnswer((_) async => writeError);
    await cubit.setThemePreference(ThemePreference.dark);
    await cubit.setThemePreference(ThemePreference.system);
    await cubit.retrySave();
    expect(
      cubit.state,
      const SettingsState(hasLoadedTheme: true, hasLoadedLanguage: true),
    );
    verify(() => repository.setThemePreference(ThemePreference.dark)).called(1);
    verify(
      () => repository.setThemePreference(ThemePreference.system),
    ).called(1);
  });

  test(
    'a new read clears an earlier failed save and its retry target',
    () async {
      when(repository.getThemePreference).thenAnswer((_) async => readError);
      when(
        () => repository.setThemePreference(ThemePreference.dark),
      ).thenAnswer((_) async => writeError);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.setThemePreference(ThemePreference.dark);
      final pending = Completer<Result<ThemePreference>>();
      when(repository.getThemePreference).thenAnswer((_) => pending.future);
      final retry = cubit.load();
      final loading = cubit.state;
      pending.complete(readError);
      await retry;
      await cubit.retrySave();
      expect(
        loading,
        const SettingsState(hasLoadedLanguage: true, isLoading: true),
      );
      expect(
        cubit.state,
        const SettingsState(hasLoadedLanguage: true, loadError: 'Read failed'),
      );
      verify(
        () => repository.setThemePreference(ThemePreference.dark),
      ).called(1);
    },
  );

  for (final result in [const Success(ThemePreference.dark), readError]) {
    test(
      'closing during a read ignores its late ${result.runtimeType}',
      () async {
        final pending = Completer<Result<ThemePreference>>();
        when(repository.getThemePreference).thenAnswer((_) => pending.future);
        final cubit = makeCubit();
        final load = cubit.load();
        await cubit.close();
        pending.complete(result);
        await expectLater(load, completes);
        verify(repository.getThemePreference).called(1);
      },
    );
  }

  for (final result in [const Success<void>(null), writeError]) {
    test(
      'closing during a write ignores its late ${result.runtimeType}',
      () async {
        final pending = Completer<Result<void>>();
        when(
          () => repository.setThemePreference(ThemePreference.dark),
        ).thenAnswer((_) => pending.future);
        final cubit = makeCubit();
        final save = cubit.setThemePreference(ThemePreference.dark);
        await cubit.close();
        pending.complete(result);
        await expectLater(save, completes);
        verify(
          () => repository.setThemePreference(ThemePreference.dark),
        ).called(1);
      },
    );
  }

  test('closed Cubits do not start repository operations', () async {
    final cubit = makeCubit();
    await cubit.close();
    await cubit.load();
    await cubit.setThemePreference(ThemePreference.dark);
    await cubit.setLanguagePreference(LanguagePreference.turkish);
    await cubit.retrySave();
    verifyZeroInteractions(repository);
  });

  test(
    'a failed language read preserves the loaded theme through saving and retry',
    () async {
      when(repository.getLanguagePreference).thenAnswer(
        (_) async => const Error<LanguagePreference>(
          PreferencesStorageFailure('Language unavailable'),
        ),
      );
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.themePreference, ThemePreference.light);
      expect(cubit.state.hasLoaded, isFalse);
      await cubit.setThemePreference(ThemePreference.dark);
      expect(cubit.state.loadError, 'Language unavailable');
      expect(cubit.state.hasLoadedLanguage, isFalse);
      when(
        repository.getThemePreference,
      ).thenAnswer((_) async => const Success(ThemePreference.dark));
      when(
        repository.getLanguagePreference,
      ).thenAnswer((_) async => const Success(LanguagePreference.turkish));
      await cubit.load();
      expect(cubit.state.hasLoaded, isTrue);
      expect(cubit.state.themePreference, ThemePreference.dark);
      expect(cubit.state.languagePreference, LanguagePreference.turkish);
      expect(cubit.state.loadError, isNull);
    },
  );

  test(
    'a failed theme read does not erase a stored language when a language is saved',
    () async {
      when(repository.getThemePreference).thenAnswer((_) async => readError);
      when(
        repository.getLanguagePreference,
      ).thenAnswer((_) async => const Success(LanguagePreference.turkish));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.languagePreference, LanguagePreference.turkish);
      await cubit.setLanguagePreference(LanguagePreference.english);
      expect(cubit.state.languagePreference, LanguagePreference.english);
      expect(cubit.state.loadError, 'Read failed');
      expect(cubit.state.hasLoadedTheme, isFalse);
    },
  );

  test(
    'language writes keep the last choice until success and serialize theme and language changes',
    () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      final pending = Completer<Result<void>>();
      when(
        () => repository.setLanguagePreference(LanguagePreference.turkish),
      ).thenAnswer((_) => pending.future);
      final save = cubit.setLanguagePreference(LanguagePreference.turkish);
      expect(cubit.state.languagePreference, LanguagePreference.system);
      await cubit.setLanguagePreference(LanguagePreference.english);
      await cubit.setThemePreference(ThemePreference.dark);
      await cubit.load();
      pending.complete(const Success<void>(null));
      await save;
      await cubit.setLanguagePreference(LanguagePreference.turkish);
      expect(cubit.state.languagePreference, LanguagePreference.turkish);
      expect(cubit.state.themePreference, ThemePreference.light);
      verify(
        () => repository.setLanguagePreference(LanguagePreference.turkish),
      ).called(1);
      verifyNever(
        () => repository.setLanguagePreference(LanguagePreference.english),
      );
      verifyNever(() => repository.setThemePreference(any()));
    },
  );

  test(
    'language retry keeps the exact target and a successful theme write preserves language',
    () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      when(
        () => repository.setLanguagePreference(LanguagePreference.turkish),
      ).thenAnswer((_) async => writeError);
      await cubit.setLanguagePreference(LanguagePreference.turkish);
      expect(cubit.state.languagePreference, LanguagePreference.system);
      expect(cubit.state.failedLanguagePreference, LanguagePreference.turkish);
      when(
        () => repository.setLanguagePreference(LanguagePreference.turkish),
      ).thenAnswer((_) async => const Success<void>(null));
      await cubit.retrySave();
      await cubit.setThemePreference(ThemePreference.dark);
      expect(cubit.state.languagePreference, LanguagePreference.turkish);
      expect(cubit.state.themePreference, ThemePreference.dark);
      expect(cubit.state.saveError, isNull);
      expect(cubit.state.failedLanguagePreference, isNull);
      verify(
        () => repository.setLanguagePreference(LanguagePreference.turkish),
      ).called(2);
    },
  );

  test(
    'confirming System after both reads fail resolves only the selected field',
    () async {
      when(repository.getThemePreference).thenAnswer((_) async => readError);
      when(repository.getLanguagePreference).thenAnswer(
        (_) async => const Error<LanguagePreference>(
          PreferencesStorageFailure('Language unavailable'),
        ),
      );
      final cubit = makeCubit();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.setLanguagePreference(LanguagePreference.system);
      expect(cubit.state.hasLoadedTheme, isFalse);
      expect(cubit.state.hasLoadedLanguage, isTrue);
      expect(cubit.state.loadError, isNotNull);
      await cubit.setThemePreference(ThemePreference.system);
      expect(cubit.state.hasLoaded, isTrue);
      expect(cubit.state.loadError, isNull);
    },
  );

  test('a new theme choice clears the failed language retry target', () async {
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.load();
    when(
      () => repository.setLanguagePreference(LanguagePreference.turkish),
    ).thenAnswer((_) async => writeError);
    await cubit.setLanguagePreference(LanguagePreference.turkish);
    await cubit.setThemePreference(ThemePreference.dark);
    await cubit.retrySave();
    expect(cubit.state.themePreference, ThemePreference.dark);
    expect(cubit.state.languagePreference, LanguagePreference.system);
    expect(cubit.state.saveError, isNull);
    expect(cubit.state.failedLanguagePreference, isNull);
    verify(
      () => repository.setLanguagePreference(LanguagePreference.turkish),
    ).called(1);
  });

  for (final result in [const Success<void>(null), writeError]) {
    test(
      'closing during a language write ignores its late ${result.runtimeType}',
      () async {
        final pending = Completer<Result<void>>();
        when(
          () => repository.setLanguagePreference(LanguagePreference.turkish),
        ).thenAnswer((_) => pending.future);
        final cubit = makeCubit();
        final saving = cubit.setLanguagePreference(LanguagePreference.turkish);
        await cubit.close();
        pending.complete(result);
        await expectLater(saving, completes);
      },
    );
  }
}
