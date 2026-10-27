import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
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
      ),
    );
    final result = await repository.getThemePreference();
    if (isClosed) return;

    switch (result) {
      case Success<ThemePreference>():
        emit(SettingsState(themePreference: result.data, hasLoaded: true));
      case Error<ThemePreference>():
        emit(
          state.copyWith(isLoading: false, loadError: result.failure.message),
        );
    }
  }

  Future<void> setThemePreference(ThemePreference preference) async {
    if (isClosed || state.isBusy) return;
    // After a failed read, System is only a fallback, not a confirmed choice.
    if (state.hasLoaded && preference == state.themePreference) return;
    emit(
      state.copyWith(
        isSaving: true,
        clearLoadError: true,
        clearSaveError: true,
        clearFailedThemePreference: true,
      ),
    );
    final result = await repository.setThemePreference(preference);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(SettingsState(themePreference: preference, hasLoaded: true));
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
    if (preference != null) await setThemePreference(preference);
  }
}
