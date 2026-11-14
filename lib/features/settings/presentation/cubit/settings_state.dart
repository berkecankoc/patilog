import 'package:equatable/equatable.dart';
import 'package:patilog/core/utils/weight_utils.dart';
import 'package:patilog/features/settings/domain/entities/language_preference.dart';
import 'package:patilog/features/settings/domain/entities/theme_preference.dart';

final class SettingsState extends Equatable {
  final ThemePreference themePreference;
  final LanguagePreference languagePreference;
  final WeightUnit weightUnit;

  /// Each preference is confirmed independently after its read or write succeeds.
  final bool hasLoadedTheme;
  final bool hasLoadedLanguage;
  final bool hasLoadedWeightUnit;
  final bool isLoading;
  final bool isSaving;
  final String? loadError;
  final String? saveError;
  final ThemePreference? failedThemePreference;
  final LanguagePreference? failedLanguagePreference;
  final WeightUnit? failedWeightUnit;

  const SettingsState({
    this.themePreference = ThemePreference.system,
    this.languagePreference = LanguagePreference.system,
    this.weightUnit = WeightUnit.kilogram,
    this.hasLoadedTheme = false,
    this.hasLoadedLanguage = false,
    this.hasLoadedWeightUnit = false,
    this.isLoading = false,
    this.isSaving = false,
    this.loadError,
    this.saveError,
    this.failedThemePreference,
    this.failedLanguagePreference,
    this.failedWeightUnit,
  });

  bool get isBusy => isLoading || isSaving;
  bool get hasLoaded =>
      hasLoadedTheme && hasLoadedLanguage && hasLoadedWeightUnit;

  SettingsState copyWith({
    ThemePreference? themePreference,
    LanguagePreference? languagePreference,
    WeightUnit? weightUnit,
    bool? hasLoadedTheme,
    bool? hasLoadedLanguage,
    bool? hasLoadedWeightUnit,
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
    WeightUnit? failedWeightUnit,
    bool clearFailedWeightUnit = false,
  }) => SettingsState(
    themePreference: themePreference ?? this.themePreference,
    languagePreference: languagePreference ?? this.languagePreference,
    weightUnit: weightUnit ?? this.weightUnit,
    hasLoadedTheme: hasLoadedTheme ?? this.hasLoadedTheme,
    hasLoadedLanguage: hasLoadedLanguage ?? this.hasLoadedLanguage,
    hasLoadedWeightUnit: hasLoadedWeightUnit ?? this.hasLoadedWeightUnit,
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
    failedWeightUnit: clearFailedWeightUnit
        ? null
        : failedWeightUnit ?? this.failedWeightUnit,
  );

  @override
  List<Object?> get props => [
    themePreference,
    languagePreference,
    weightUnit,
    hasLoadedTheme,
    hasLoadedLanguage,
    hasLoadedWeightUnit,
    isLoading,
    isSaving,
    loadError,
    saveError,
    failedThemePreference,
    failedLanguagePreference,
    failedWeightUnit,
  ];
}
