import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';

abstract interface class SettingsRepository {
  /// Missing or unrecognized stored values return [ThemePreference.system].
  Future<Result<ThemePreference>> getThemePreference();

  Future<Result<void>> setThemePreference(ThemePreference preference);
}
