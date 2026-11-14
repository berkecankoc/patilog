import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/utils/weight_utils.dart';
import 'package:patilog/features/settings/domain/entities/language_preference.dart';
import 'package:patilog/features/settings/domain/entities/theme_preference.dart';
import 'package:patilog/features/settings/domain/repositories/settings_repository.dart';
import 'package:patilog/features/settings/presentation/cubit/settings_state.dart';

final class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository repository;

  SettingsCubit(this.repository) : super(const SettingsState());

  Future<void> load() async {
    if (isClosed || state.isBusy || state.hasLoaded) return;
    emit(
      state.copyWith(
        isLoading: true,
        clearLoadError: true,
        clearSaveError: true,
        clearFailedThemePreference: true,
        clearFailedLanguagePreference: true,
        clearFailedWeightUnit: true,
      ),
    );
    final (theme, language, weightUnit) = await (
      repository.getThemePreference(),
      repository.getLanguagePreference(),
      repository.getWeightUnit(),
    ).wait;
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        themePreference: theme is Success<ThemePreference> ? theme.data : null,
        languagePreference: language is Success<LanguagePreference>
            ? language.data
            : null,
        weightUnit: weightUnit is Success<WeightUnit> ? weightUnit.data : null,
        hasLoadedTheme:
            state.hasLoadedTheme || theme is Success<ThemePreference>,
        hasLoadedLanguage:
            state.hasLoadedLanguage || language is Success<LanguagePreference>,
        hasLoadedWeightUnit:
            state.hasLoadedWeightUnit || weightUnit is Success<WeightUnit>,
        loadError: theme is Error<ThemePreference>
            ? theme.failure.message
            : language is Error<LanguagePreference>
            ? language.failure.message
            : weightUnit is Error<WeightUnit>
            ? weightUnit.failure.message
            : null,
      ),
    );
  }

  Future<void> setThemePreference(ThemePreference preference) async {
    if (isClosed || state.isBusy) return;
    // After a failed read, System is only a fallback, not a confirmed choice.
    if (state.hasLoadedTheme && preference == state.themePreference) return;
    emit(
      state.copyWith(
        isSaving: true,
        clearSaveError: true,
        clearFailedThemePreference: true,
        clearFailedLanguagePreference: true,
        clearFailedWeightUnit: true,
      ),
    );
    final result = await repository.setThemePreference(preference);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            themePreference: preference,
            hasLoadedTheme: true,
            isSaving: false,
            clearLoadError:
                state.hasLoadedLanguage && state.hasLoadedWeightUnit,
          ),
        );
      case Error<void>():
        emit(
          state.copyWith(
            isSaving: false,
            saveError: result.failure.message,
            failedThemePreference: preference,
          ),
        );
    }
  }

  Future<void> retrySave() async {
    final preference = state.failedThemePreference;
    final language = state.failedLanguagePreference;
    final weightUnit = state.failedWeightUnit;
    if (preference != null) {
      await setThemePreference(preference);
    } else if (language != null) {
      await setLanguagePreference(language);
    } else if (weightUnit != null) {
      await setWeightUnit(weightUnit);
    }
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    if (isClosed || state.isBusy) return;
    if (state.hasLoadedWeightUnit && unit == state.weightUnit) return;
    emit(
      state.copyWith(
        isSaving: true,
        clearSaveError: true,
        clearFailedThemePreference: true,
        clearFailedLanguagePreference: true,
        clearFailedWeightUnit: true,
      ),
    );
    final result = await repository.setWeightUnit(unit);
    if (isClosed) return;
    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            weightUnit: unit,
            hasLoadedWeightUnit: true,
            isSaving: false,
            clearLoadError: state.hasLoadedTheme && state.hasLoadedLanguage,
          ),
        );
      case Error<void>():
        emit(
          state.copyWith(
            isSaving: false,
            saveError: result.failure.message,
            failedWeightUnit: unit,
          ),
        );
    }
  }

  Future<void> setLanguagePreference(LanguagePreference preference) async {
    if (isClosed || state.isBusy) return;
    if (state.hasLoadedLanguage && preference == state.languagePreference) {
      return;
    }
    emit(
      state.copyWith(
        isSaving: true,
        clearSaveError: true,
        clearFailedThemePreference: true,
        clearFailedLanguagePreference: true,
        clearFailedWeightUnit: true,
      ),
    );
    final result = await repository.setLanguagePreference(preference);
    if (isClosed) return;
    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            languagePreference: preference,
            hasLoadedLanguage: true,
            isSaving: false,
            clearLoadError: state.hasLoadedTheme && state.hasLoadedWeightUnit,
          ),
        );
      case Error<void>():
        emit(
          state.copyWith(
            isSaving: false,
            saveError: result.failure.message,
            failedLanguagePreference: preference,
          ),
        );
    }
  }
}
