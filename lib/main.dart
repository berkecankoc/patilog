import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_keyboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ImageStorage>.value(
      value: getIt<ImageStorage>(),
      child: MaterialApp.router(
        title: 'Petlytics',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        builder: (_, child) => AppKeyboard(child: child!),
      ),
    );
  }
}
