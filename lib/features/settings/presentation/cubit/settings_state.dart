import 'package:equatable/equatable.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';

final class SettingsState extends Equatable {
  final ThemePreference themePreference;

  /// The current preference was read or saved successfully.
  final bool hasLoaded;
  final bool isLoading;
  final bool isSaving;
  final String? loadError;
  final String? saveError;
  final ThemePreference? failedThemePreference;

  const SettingsState({
    this.themePreference = ThemePreference.system,
    this.hasLoaded = false,
    this.isLoading = false,
    this.isSaving = false,
    this.loadError,
    this.saveError,
    this.failedThemePreference,
  });

  bool get isBusy => isLoading || isSaving;

  SettingsState copyWith({
    ThemePreference? themePreference,
    bool? hasLoaded,
    bool? isLoading,
    bool? isSaving,
    String? loadError,
    bool clearLoadError = false,
    String? saveError,
    bool clearSaveError = false,
    ThemePreference? failedThemePreference,
    bool clearFailedThemePreference = false,
  }) => SettingsState(
    themePreference: themePreference ?? this.themePreference,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    loadError: clearLoadError ? null : loadError ?? this.loadError,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    failedThemePreference: clearFailedThemePreference
        ? null
        : failedThemePreference ?? this.failedThemePreference,
  );

  @override
  List<Object?> get props => [
    themePreference,
    hasLoaded,
    isLoading,
    isSaving,
    loadError,
    saveError,
    failedThemePreference,
  ];
}
