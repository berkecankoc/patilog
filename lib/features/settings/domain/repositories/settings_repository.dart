import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';

abstract interface class SettingsRepository {
  /// Missing or unrecognized stored values return [ThemePreference.system].
  Future<Result<ThemePreference>> getThemePreference();

  Future<Result<void>> setThemePreference(ThemePreference preference);

  /// Missing or unrecognized stored values follow the system language.
  Future<Result<LanguagePreference>> getLanguagePreference();

  Future<Result<void>> setLanguagePreference(LanguagePreference preference);
}
