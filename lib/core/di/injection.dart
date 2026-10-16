import 'package:get_it/get_it.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/services/uuid_generator.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/core/storage/local_image_storage.dart';
import 'package:petlytics/features/pet/data/data_sources/pet_local_data_source.dart';
import 'package:petlytics/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/vet_visit/data/data_sources/vet_visit_local_data_source.dart';
import 'package:petlytics/features/vet_visit/data/repositories/vet_visit_repository_impl.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/weight_history/data/data_sources/weight_history_local_data_source.dart';
import 'package:petlytics/features/weight_history/data/repositories/weight_history_repository_impl.dart';
import 'package:petlytics/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:sqflite/sqflite.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  final db = await openAppDatabase();

  getIt.registerSingleton<Database>(db);

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

  getIt.registerLazySingleton<VetVisitLocalDataSource>(
    () => VetVisitLocalDataSourceImpl(getIt<Database>()),
  );

  getIt.registerLazySingleton<VetVisitRepository>(
    () => VetVisitRepositoryImpl(getIt<VetVisitLocalDataSource>()),
  );

  getIt.registerLazySingleton<WeightHistoryLocalDataSource>(
    () => WeightHistoryLocalDataSourceImpl(getIt<Database>()),
  );

  getIt.registerLazySingleton<WeightHistoryRepository>(
    () => WeightHistoryRepositoryImpl(getIt<WeightHistoryLocalDataSource>()),
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

  getIt.registerFactory<PetCubit>(
    () => PetCubit(
      getIt<PetRepository>(),
      getIt<CreatePet>(),
      getIt<UpdatePet>(),
      getIt<DeletePet>(),
    ),
  );

  getIt.registerFactory<WeightHistoryCubit>(
    () => WeightHistoryCubit(
      getIt<WeightHistoryRepository>(),
      getIt<IdGenerator>(),
    ),
  );
}
