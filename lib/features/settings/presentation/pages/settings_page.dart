import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
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
            title: const Text('Settings'),
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
                            ? 'Saving appearance'
                            : 'Loading appearance',
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
                  if (state.loadError case final message?)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.5,
                      ),
                      child: AppErrorFeedback(
                        message: message,
                        onRetry: cubit.load,
                      ),
                    ),
                  if (state.saveError case final message?)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.5,
                      ),
                      child: AppErrorFeedback(
                        message: message,
                        onRetry: cubit.retrySave,
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        const AppSectionHeading(
                          title: 'Appearance',
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
                                      ThemePreference.system => 'System',
                                      ThemePreference.light => 'Light',
                                      ThemePreference.dark => 'Dark',
                                    }),
                                    subtitle:
                                        preference == ThemePreference.system
                                        ? const Text('Follow device settings')
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
