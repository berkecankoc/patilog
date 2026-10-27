import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/settings/domain/repositories/settings_repository.dart';
import 'package:petlytics/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:petlytics/features/settings/presentation/cubit/settings_state.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository repository;
  const light = SettingsState(
    themePreference: ThemePreference.light,
    hasLoaded: true,
  );
  const readError = Error<ThemePreference>(
    PreferencesStorageFailure('Read failed'),
  );
  const writeError = Error<void>(PreferencesStorageFailure('Write failed'));

  setUpAll(() => registerFallbackValue(ThemePreference.system));
  setUp(() {
    repository = MockSettingsRepository();
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
    (readError, const SettingsState(loadError: 'Read failed')),
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
        hasLoaded: true,
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
    expect(cubit.state, const SettingsState(isLoading: true));
    pending.complete(const Success(ThemePreference.dark));
    await retry;
    expect(
      cubit.state,
      const SettingsState(
        themePreference: ThemePreference.dark,
        hasLoaded: true,
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
      expect(cubit.state, const SettingsState(hasLoaded: true));
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
          hasLoaded: true,
        ),
      );
      verify(
        () => repository.setThemePreference(ThemePreference.dark),
      ).called(2);
      verify(repository.getThemePreference).called(1);
      await cubit.retrySave();
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
    expect(cubit.state, const SettingsState(hasLoaded: true));
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
      expect(loading, const SettingsState(isLoading: true));
      expect(cubit.state, const SettingsState(loadError: 'Read failed'));
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
    await cubit.retrySave();
    verifyZeroInteractions(repository);
  });
}
