import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/di/injection.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/router/care_record_changes.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:patilog/features/notification/domain/use_cases/resolve_notification_target.dart';
import 'package:patilog/core/router/app_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/storage/image_storage.dart';
import 'package:patilog/features/settings/domain/entities/theme_preference.dart';
import 'package:patilog/features/settings/domain/entities/language_preference.dart';
import 'package:patilog/features/settings/domain/repositories/settings_repository.dart';
import 'package:patilog/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:patilog/main.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';

import 'multi_step_form_helpers.dart';
import 'pet_care_test_harness.dart';
import 'notification_test_harness.dart' show NotificationTestHarness;

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

class SettingsTestHarness {
  final PetCareTestHarness care;
  SettingsTestHarness({PetCareTestHarness? care})
    : care = care ?? PetCareTestHarness();
  final notifications = NotificationTestHarness();
  final repository = MockSettingsRepository();
  ThemePreference stored = ThemePreference.system;
  LanguagePreference storedLanguage = LanguagePreference.system;
  bool failLanguageLoad = false;
  bool failLanguageSave = false;
  Completer<Result<LanguagePreference>>? pendingLanguageLoad;
  Completer<Result<void>>? pendingLanguageSave;
  bool failLoad = false;
  bool failSave = false;
  Completer<Result<ThemePreference>>? pendingLoad;
  Completer<Result<void>>? pendingSave;
  late SettingsCubit cubit;

  static Future<void> initialize() async {
    await loadFormTestFont();
    final sample = PetCareTestHarness().sample();
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(ThemePreference.system);
    registerFallbackValue(LanguagePreference.system);
    registerFallbackValue(sample);
    registerFallbackValue(sample.periods.single);
    registerFallbackValue(
      MedicationDoseLog(
        periodId: sample.periods.single.id,
        scheduledDate: DateTime(2026),
        scheduledMinute: 480,
        status: MedicationDoseStatus.skipped,
      ),
    );
  }

  void register() {
    care.register();
    getIt.registerLazySingleton<CareRecordChanges>(
      CareRecordChanges.new,
      dispose: (changes) => changes.dispose(),
    );
    getIt.registerFactory<NotificationCubit>(notifications.createCubit);
    getIt.registerLazySingleton<ResolveNotificationTarget>(
      () => ResolveNotificationTarget(
        care.pets,
        care.repository,
        care.vaccinations,
        notifications.feeding,
      ),
    );
    getIt.registerSingleton<ImageStorage>(MockImageStorage());
    when(repository.getThemePreference).thenAnswer((_) async {
      if (pendingLoad case final pending?) return pending.future;
      return failLoad
          ? const Error(
              PreferencesStorageFailure('Failed to load theme preference'),
            )
          : Success(stored);
    });
    when(repository.getLanguagePreference).thenAnswer((_) async {
      if (pendingLanguageLoad case final pending?) return pending.future;
      return failLanguageLoad
          ? const Error(
              PreferencesStorageFailure('Failed to load language preference'),
            )
          : Success(storedLanguage);
    });
    when(() => repository.setLanguagePreference(any())).thenAnswer((
      call,
    ) async {
      final result = pendingLanguageSave != null
          ? await pendingLanguageSave!.future
          : failLanguageSave
          ? const Error<void>(
              PreferencesStorageFailure('Failed to save language preference'),
            )
          : const Success<void>(null);
      if (result is Success<void>) {
        storedLanguage = call.positionalArguments.single as LanguagePreference;
      }
      return result;
    });
    when(() => repository.setThemePreference(any())).thenAnswer((call) async {
      final result = pendingSave != null
          ? await pendingSave!.future
          : failSave
          ? const Error<void>(
              PreferencesStorageFailure('Failed to save theme preference'),
            )
          : const Success<void>(null);
      if (result is Success<void>) {
        stored = call.positionalArguments.single as ThemePreference;
      }
      return result;
    });
    cubit = SettingsCubit(repository);
  }

  Future<void> pump(
    WidgetTester tester, {
    String location = AppRoutes.settings,
    Size size = const Size(390, 844),
    double scale = 1,
    bool settle = true,
    GlobalKey? captureKey,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await getIt.reset();
      await notifications.dispose();
    });
    await cubit.load();
    appRouter.go(location);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MyApp(settingsCubit: cubit),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}
