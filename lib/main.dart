import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:petlytics/features/notification/presentation/widgets/notification_runtime.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_keyboard.dart';
import 'package:petlytics/features/settings/domain/entities/theme_preference.dart';
import 'package:petlytics/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:petlytics/features/settings/presentation/cubit/settings_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupDependencies();

  final settings = getIt<SettingsCubit>();
  await settings.load();

  runApp(MyApp(settingsCubit: settings));
}

class MyApp extends StatelessWidget {
  final SettingsCubit settingsCubit;

  const MyApp({super.key, required this.settingsCubit});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => settingsCubit),
        BlocProvider<NotificationCubit>(
          create: (_) => getIt<NotificationCubit>(),
        ),
      ],
      child: RepositoryProvider<ImageStorage>.value(
        value: getIt<ImageStorage>(),
        child: CareRecordChangeScope(
          changes: getIt<CareRecordChanges>(),
          child: NotificationRuntime(
            child: BlocSelector<SettingsCubit, SettingsState, ThemePreference>(
              selector: (state) => state.themePreference,
              builder: (_, preference) => MaterialApp.router(
                title: 'Petlytics',
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: switch (preference) {
                  ThemePreference.system => ThemeMode.system,
                  ThemePreference.light => ThemeMode.light,
                  ThemePreference.dark => ThemeMode.dark,
                },
                routerConfig: appRouter,
                builder: (_, child) => AppKeyboard(child: child!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
