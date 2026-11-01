import 'package:equatable/equatable.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';

final class SettingsState extends Equatable {
  final ThemePreference themePreference;
  final LanguagePreference languagePreference;

  /// Each preference is confirmed independently after its read or write succeeds.
  final bool hasLoadedTheme;
  final bool hasLoadedLanguage;
  final bool isLoading;
  final bool isSaving;
  final String? loadError;
  final String? saveError;
  final ThemePreference? failedThemePreference;
  final LanguagePreference? failedLanguagePreference;

  const SettingsState({
    this.themePreference = ThemePreference.system,
    this.languagePreference = LanguagePreference.system,
    this.hasLoadedTheme = false,
    this.hasLoadedLanguage = false,
    this.isLoading = false,
    this.isSaving = false,
    this.loadError,
    this.saveError,
    this.failedThemePreference,
    this.failedLanguagePreference,
  });

  bool get isBusy => isLoading || isSaving;
  bool get hasLoaded => hasLoadedTheme && hasLoadedLanguage;

  SettingsState copyWith({
    ThemePreference? themePreference,
    LanguagePreference? languagePreference,
    bool? hasLoadedTheme,
    bool? hasLoadedLanguage,
    bool? isLoading,
    bool? isSaving,
    String? loadError,
    bool clearLoadError = false,
    String? saveError,
    bool clearSaveError = false,
    ThemePreference? failedThemePreference,
    bool clearFailedThemePreference = false,
    LanguagePreference? failedLanguagePreference,
    bool clearFailedLanguagePreference = false,
  }) => SettingsState(
    themePreference: themePreference ?? this.themePreference,
    languagePreference: languagePreference ?? this.languagePreference,
    hasLoadedTheme: hasLoadedTheme ?? this.hasLoadedTheme,
    hasLoadedLanguage: hasLoadedLanguage ?? this.hasLoadedLanguage,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    loadError: clearLoadError ? null : loadError ?? this.loadError,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    failedThemePreference: clearFailedThemePreference
        ? null
        : failedThemePreference ?? this.failedThemePreference,
    failedLanguagePreference: clearFailedLanguagePreference
        ? null
        : failedLanguagePreference ?? this.failedLanguagePreference,
  );

  @override
  List<Object?> get props => [
    themePreference,
    languagePreference,
    hasLoadedTheme,
    hasLoadedLanguage,
    isLoading,
    isSaving,
    loadError,
    saveError,
    failedThemePreference,
    failedLanguagePreference,
  ];
}
