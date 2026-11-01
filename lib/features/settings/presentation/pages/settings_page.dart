import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/settings/domain/entities/language_preference.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:petlytics/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:petlytics/features/settings/presentation/cubit/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) {
      final cubit = context.read<SettingsCubit>();
      final strings = AppLocalizations.of(context);
      void back() {
        if (cubit.state.isBusy) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.pets);
        }
      }

      return PopScope(
        canPop: !state.isBusy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(strings.settingsTitle),
            leading: state.isBusy
                ? IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: null,
                    icon: const BackButtonIcon(),
                  )
                : BackButton(onPressed: back),
            actions: [
              if (state.isBusy)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: state.isSaving
                            ? strings.savingSettings
                            : strings.loadingSettings,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  if (state.loadError != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.5,
                      ),
                      child: AppErrorFeedback(
                        message:
                            !state.hasLoadedTheme && !state.hasLoadedLanguage
                            ? strings.settingsLoadFailed
                            : !state.hasLoadedTheme
                            ? strings.themeLoadFailed
                            : strings.languageLoadFailed,
                        retryLabel: strings.retry,
                        onRetry: cubit.load,
                      ),
                    ),
                  if (state.saveError != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.5,
                      ),
                      child: AppErrorFeedback(
                        message: state.failedLanguagePreference != null
                            ? strings.languageSaveFailed
                            : strings.themeSaveFailed,
                        retryLabel: strings.retry,
                        onRetry: cubit.retrySave,
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        AppSectionHeading(
                          title: strings.notificationsTitle,
                          icon: Icons.notifications_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(strings.remindersTitle),
                            subtitle: Text(strings.remindersDescription),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: state.isBusy
                                ? null
                                : () => context.push(
                                    AppRoutes.notificationSettings,
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppSectionHeading(
                          title: strings.appearanceTitle,
                          icon: Icons.palette_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: RadioGroup<ThemePreference>(
                            groupValue: state.themePreference,
                            onChanged: (value) {
                              if (value != null && !cubit.state.isBusy) {
                                cubit.setThemePreference(value);
                              }
                            },
                            child: Column(
                              children: [
                                for (final preference
                                    in ThemePreference.values) ...[
                                  if (preference != ThemePreference.system)
                                    const Divider(
                                      height: 1,
                                      indent: AppSpacing.md,
                                      endIndent: AppSpacing.md,
                                    ),
                                  RadioListTile<ThemePreference>(
                                    value: preference,
                                    enabled: !state.isBusy,
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                    titleAlignment:
                                        ListTileTitleAlignment.center,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    title: Text(switch (preference) {
                                      ThemePreference.system =>
                                        strings.themeSystem,
                                      ThemePreference.light =>
                                        strings.themeLight,
                                      ThemePreference.dark => strings.themeDark,
                                    }),
                                    subtitle:
                                        preference == ThemePreference.system
                                        ? Text(strings.followDeviceSettings)
                                        : null,
                                    secondary: Icon(switch (preference) {
                                      ThemePreference.system =>
                                        Icons.brightness_auto_outlined,
                                      ThemePreference.light =>
                                        Icons.light_mode_outlined,
                                      ThemePreference.dark =>
                                        Icons.dark_mode_outlined,
                                    }),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppSectionHeading(
                          title: strings.languageTitle,
                          icon: Icons.language_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: RadioGroup<LanguagePreference>(
                            groupValue: state.languagePreference,
                            onChanged: (value) {
                              if (value != null && !cubit.state.isBusy) {
                                cubit.setLanguagePreference(value);
                              }
                            },
                            child: Column(
                              children: [
                                for (final preference
                                    in LanguagePreference.values) ...[
                                  if (preference != LanguagePreference.system)
                                    const Divider(
                                      height: 1,
                                      indent: AppSpacing.md,
                                      endIndent: AppSpacing.md,
                                    ),
                                  RadioListTile<LanguagePreference>(
                                    value: preference,
                                    enabled: !state.isBusy,
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                    titleAlignment:
                                        ListTileTitleAlignment.center,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    title: Text(switch (preference) {
                                      LanguagePreference.system =>
                                        strings.languageSystem,
                                      LanguagePreference.turkish =>
                                        strings.languageTurkish,
                                      LanguagePreference.english =>
                                        strings.languageEnglish,
                                    }),
                                    subtitle:
                                        preference == LanguagePreference.system
                                        ? Text(strings.followDeviceLanguage)
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
