import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/settings/domain/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class SettingsRepositoryImpl implements SettingsRepository {
  final SharedPreferencesAsync preferences;
  static const _themePreferenceKey = 'settings.theme_preference';

  const SettingsRepositoryImpl(this.preferences);

  @override
  Future<Result<ThemePreference>> getThemePreference() async {
    try {
      final values = await preferences.getAll(allowList: {_themePreferenceKey});
      final preference = switch (values[_themePreferenceKey]) {
        'light' => ThemePreference.light,
        'dark' => ThemePreference.dark,
        _ => ThemePreference.system,
      };
      return Success(preference);
    } on Exception {
      return const Error(
        PreferencesStorageFailure('Failed to load theme preference'),
      );
    }
  }

  @override
  Future<Result<void>> setThemePreference(ThemePreference preference) async {
    try {
      await preferences.setString(_themePreferenceKey, preference.name);
      return const Success(null);
    } on Exception {
      return const Error(
        PreferencesStorageFailure('Failed to save theme preference'),
      );
    }
  }
}
