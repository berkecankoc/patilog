import 'package:get_it/get_it.dart';
import 'package:petlytics/features/feeding/data/data_sources/feeding_local_data_source.dart';
import 'package:petlytics/features/feeding/data/repositories/feeding_repository_impl.dart';
import 'package:petlytics/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:petlytics/features/feeding/domain/use_cases/calculate_feeding_meals.dart';
import 'package:petlytics/features/feeding/domain/use_cases/calculate_feeding_totals.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_form_cubit.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:petlytics/features/notification/domain/use_cases/load_notification_data.dart';
import 'package:petlytics/features/notification/domain/use_cases/resolve_notification_target.dart';
import 'package:petlytics/features/notification/domain/use_cases/plan_notification_reminders.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:petlytics/features/notification/data/data_sources/notification_local_data_source.dart';
import 'package:petlytics/features/notification/data/data_sources/notification_preferences_local_data_source.dart';
import 'package:petlytics/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:petlytics/features/notification/domain/repositories/notification_repository.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_visits_cubit.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/services/uuid_generator.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/core/storage/local_image_storage.dart';
import 'package:petlytics/features/medication/data/data_sources/medication_local_data_source.dart';
import 'package:petlytics/features/medication/data/repositories/medication_repository_impl.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/medication/domain/use_cases/create_medication.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:petlytics/features/pet/data/data_sources/pet_local_data_source.dart';
import 'package:petlytics/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:petlytics/features/settings/domain/repositories/settings_repository.dart';
import 'package:petlytics/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:petlytics/features/vaccination/data/data_sources/vaccination_local_data_source.dart';
import 'package:petlytics/features/vaccination/data/repositories/vaccination_repository_impl.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:petlytics/features/vet_visit/data/data_sources/vet_visit_local_data_source.dart';
import 'package:petlytics/features/vet_visit/data/repositories/vet_visit_repository_impl.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:petlytics/features/weight_history/data/data_sources/weight_history_local_data_source.dart';
import 'package:petlytics/features/weight_history/data/repositories/weight_history_repository_impl.dart';
import 'package:petlytics/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  final db = await openAppDatabase();

  getIt.registerSingleton<Database>(db);
  getIt.registerLazySingleton<CareRecordChanges>(
    CareRecordChanges.new,
    dispose: (changes) => changes.dispose(),
  );

  getIt.registerLazySingleton<SharedPreferencesAsync>(
    () => SharedPreferencesAsync(),
  );

  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(getIt<SharedPreferencesAsync>()),
  );

  getIt.registerLazySingleton<NotificationPreferencesLocalDataSource>(
    () => NotificationPreferencesLocalDataSourceImpl(
      getIt<SharedPreferencesAsync>(),
    ),
  );
  getIt.registerLazySingleton<NotificationLocalDataSource>(
    () => NotificationLocalDataSourceImpl(FlutterLocalNotificationsPlugin()),
    dispose: (source) => source.dispose(),
  );
  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(
      getIt<NotificationPreferencesLocalDataSource>(),
      getIt<NotificationLocalDataSource>(),
    ),
  );

  getIt.registerLazySingleton<IdGenerator>(() => UuidGenerator());

  getIt.registerLazySingleton<ImageStorage>(
    () => LocalImageStorage(getIt<IdGenerator>()),
  );

  getIt.registerLazySingleton<PetLocalDataSource>(
    () => PetLocalDataSourceImpl(getIt<Database>()),
  );

  getIt.registerLazySingleton<PetRepository>(
    () => PetRepositoryImpl(getIt<PetLocalDataSource>()),
  );

  getIt.registerLazySingleton<CreatePet>(
    () => CreatePet(
      getIt<PetRepository>(),
      getIt<IdGenerator>(),
      getIt<ImageStorage>(),
    ),
  );

  getIt.registerLazySingleton<UpdatePet>(
    () => UpdatePet(
      getIt<PetRepository>(),
      getIt<ImageStorage>(),
      getIt<IdGenerator>(),
    ),
  );

  getIt.registerLazySingleton<DeletePet>(
    () => DeletePet(getIt<PetRepository>(), getIt<ImageStorage>()),
  );

  getIt.registerLazySingleton<WeightHistoryLocalDataSource>(
    () => WeightHistoryLocalDataSourceImpl(getIt<Database>()),
  );

  getIt.registerLazySingleton<WeightHistoryRepository>(
    () => WeightHistoryRepositoryImpl(getIt<WeightHistoryLocalDataSource>()),
  );

  getIt.registerLazySingleton<VetVisitLocalDataSource>(
    () => VetVisitLocalDataSourceImpl(getIt<Database>()),
  );

  getIt.registerLazySingleton<VetVisitRepository>(
    () => VetVisitRepositoryImpl(getIt<VetVisitLocalDataSource>()),
  );

  getIt.registerLazySingleton<VaccinationLocalDataSource>(
    () => VaccinationLocalDataSourceImpl(getIt<Database>()),
  );

  getIt.registerLazySingleton<VaccinationRepository>(
    () => VaccinationRepositoryImpl(getIt<VaccinationLocalDataSource>()),
  );

  getIt.registerLazySingleton<SaveVaccination>(
    () => SaveVaccination(getIt<VaccinationRepository>(), getIt<IdGenerator>()),
  );

  getIt.registerLazySingleton<MedicationLocalDataSource>(
    () => MedicationLocalDataSourceImpl(getIt<Database>()),
  );

  getIt.registerLazySingleton<MedicationRepository>(
    () => MedicationRepositoryImpl(getIt<MedicationLocalDataSource>()),
  );

  getIt.registerLazySingleton<CreateMedication>(
    () => CreateMedication(getIt<MedicationRepository>(), getIt<IdGenerator>()),
  );

  getIt.registerLazySingleton<CalculateMedicationDoses>(
    () => const CalculateMedicationDoses(),
  );

  getIt.registerLazySingleton<FeedingLocalDataSource>(
    () => FeedingLocalDataSourceImpl(getIt<Database>()),
  );
  getIt.registerLazySingleton<FeedingRepository>(
    () => FeedingRepositoryImpl(getIt<FeedingLocalDataSource>()),
  );
  getIt.registerLazySingleton<CalculateFeedingMeals>(
    () => const CalculateFeedingMeals(),
  );
  getIt.registerLazySingleton<CalculateFeedingTotals>(
    () => const CalculateFeedingTotals(),
  );
  getIt.registerFactory<FeedingCubit>(
    () => FeedingCubit(
      getIt<FeedingRepository>(),
      getIt<IdGenerator>(),
      getIt<CalculateFeedingMeals>(),
      getIt<CalculateFeedingTotals>(),
    ),
  );
  getIt.registerFactory<FeedingFormCubit>(
    () => FeedingFormCubit(getIt<FeedingRepository>(), getIt<IdGenerator>()),
  );

  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(getIt<SettingsRepository>()),
  );
  getIt.registerLazySingleton<LoadNotificationData>(
    () => LoadNotificationData(
      getIt<PetRepository>(),
      getIt<MedicationRepository>(),
      getIt<VaccinationRepository>(),
      getIt<FeedingRepository>(),
    ),
  );
  getIt.registerLazySingleton<PlanNotificationReminders>(
    () => const PlanNotificationReminders(),
  );
  getIt.registerLazySingleton<ResolveNotificationTarget>(
    () => ResolveNotificationTarget(
      getIt<PetRepository>(),
      getIt<MedicationRepository>(),
      getIt<VaccinationRepository>(),
      getIt<FeedingRepository>(),
    ),
  );
  getIt.registerFactory<NotificationCubit>(
    () => NotificationCubit(
      getIt<NotificationRepository>(),
      getIt<LoadNotificationData>(),
      getIt<PlanNotificationReminders>(),
    ),
  );

  getIt.registerFactory<PetCubit>(
    () => PetCubit(
      getIt<PetRepository>(),
      getIt<CreatePet>(),
      getIt<UpdatePet>(),
      getIt<DeletePet>(),
    ),
  );

  getIt.registerFactory<AllPetsCareCubit>(
    () => AllPetsCareCubit(
      getIt<PetRepository>(),
      getIt<VetVisitRepository>(),
      getIt<VaccinationRepository>(),
      getIt<MedicationRepository>(),
      getIt<CalculateMedicationDoses>(),
      onMutation: (action) {
        final (tab, deletedId) = switch (action) {
          DeleteGlobalVetVisit(:final visitId) => (
            PetCareTab.vetVisits,
            visitId,
          ),
          DeleteGlobalVaccination(:final vaccinationId) => (
            PetCareTab.vaccinations,
            vaccinationId,
          ),
          GlobalDoseAction() => (PetCareTab.medications, null),
        };
        getIt<CareRecordChanges>().changed(
          action.petId,
          tab,
          deletedId: deletedId,
          globalListIsCurrent: true,
        );
      },
    ),
  );

  getIt.registerFactory<WeightHistoryCubit>(
    () => WeightHistoryCubit(
      getIt<WeightHistoryRepository>(),
      getIt<IdGenerator>(),
    ),
  );

  getIt.registerFactory<VetVisitCubit>(
    () => VetVisitCubit(getIt<VetVisitRepository>()),
  );

  getIt.registerFactory<VetVisitFormCubit>(
    () => VetVisitFormCubit(getIt<VetVisitRepository>(), getIt<IdGenerator>()),
  );

  getIt.registerFactory<VaccinationCubit>(
    () => VaccinationCubit(getIt<VaccinationRepository>()),
  );

  getIt.registerFactory<VaccinationFormCubit>(
    () => VaccinationFormCubit(
      getIt<VaccinationRepository>(),
      getIt<VetVisitRepository>(),
      getIt<SaveVaccination>(),
    ),
  );

  getIt.registerFactory<MedicationFormCubit>(
    () => MedicationFormCubit(
      getIt<MedicationRepository>(),
      getIt<VetVisitRepository>(),
      getIt<CreateMedication>(),
      getIt<IdGenerator>(),
    ),
  );

  getIt.registerFactory<MedicationCubit>(
    () => MedicationCubit(
      getIt<MedicationRepository>(),
      getIt<CalculateMedicationDoses>(),
    ),
  );
  getIt.registerFactory<MedicationVisitsCubit>(
    () => MedicationVisitsCubit(getIt<VetVisitRepository>()),
  );
}
