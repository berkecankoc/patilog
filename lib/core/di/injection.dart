import 'package:get_it/get_it.dart';
import 'package:petlytics/core/database/app_database.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/services/uuid_generator.dart';
import 'package:petlytics/features/pet/data/data_sources/pet_local_data_source.dart';
import 'package:petlytics/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:sqflite/sqflite.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  final db = await openAppDatabase();

  getIt.registerSingleton<Database>(db);

  getIt.registerLazySingleton<IdGenerator>(() => UuidGenerator());

  getIt.registerLazySingleton<PetLocalDataSource>(
    () => PetLocalDataSourceImpl(getIt<Database>()),
  );

  getIt.registerLazySingleton<PetRepository>(
    () => PetRepositoryImpl(getIt<PetLocalDataSource>()),
  );

  getIt.registerLazySingleton<CreatePet>(
    () => CreatePet(getIt<PetRepository>(), getIt<IdGenerator>()),
  );

  getIt.registerFactory<PetCubit>(
    () => PetCubit(getIt<PetRepository>(), getIt<CreatePet>()),
  );
}
