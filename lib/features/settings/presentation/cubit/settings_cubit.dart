import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/settings/domain/repositories/settings_repository.dart';
import 'package:petlytics/features/settings/presentation/cubit/settings_state.dart';

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
      ),
    );
    final (theme, language) = await (
      repository.getThemePreference(),
      repository.getLanguagePreference(),
    ).wait;
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        themePreference: theme is Success<ThemePreference> ? theme.data : null,
        languagePreference: language is Success<LanguagePreference>
            ? language.data
            : null,
        hasLoadedTheme:
            state.hasLoadedTheme || theme is Success<ThemePreference>,
        hasLoadedLanguage:
            state.hasLoadedLanguage || language is Success<LanguagePreference>,
        loadError: theme is Error<ThemePreference>
            ? theme.failure.message
            : language is Error<LanguagePreference>
            ? language.failure.message
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
            clearLoadError: state.hasLoadedLanguage,
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
    if (preference != null) {
      await setThemePreference(preference);
    } else if (language != null) {
      await setLanguagePreference(language);
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
            clearLoadError: state.hasLoadedTheme,
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
