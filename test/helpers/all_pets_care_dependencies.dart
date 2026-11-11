import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/di/injection.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:patilog/features/medication/domain/repositories/medication_repository.dart';
import 'package:patilog/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';
import 'package:patilog/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:patilog/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_cubit.dart';

class _Weights extends Mock implements WeightHistoryRepository {}

class _Ids extends Mock implements IdGenerator {}

class _Visits extends Mock implements VetVisitRepository {}

class _Vaccinations extends Mock implements VaccinationRepository {}

class _Medications extends Mock implements MedicationRepository {}

/// Pet-only routing tests need the global root without unrelated care fixtures.
void registerAllPetsCare(
  PetRepository pets, {
  VetVisitRepository? visits,
  VaccinationRepository? vaccinations,
  MedicationRepository? medications,
  WeightHistoryRepository? weights,
  DateTime Function()? now,
}) {
  final visitRepository = visits ?? _Visits();
  final vaccinationRepository = vaccinations ?? _Vaccinations();
  final medicationRepository = medications ?? _Medications();
  final weightRepository = weights ?? _Weights();
  if (weights == null) {
    when(weightRepository.getAllWeightEntries)
        .thenAnswer((_) async => const Success([]));
  }
  if (!getIt.isRegistered<WeightHistoryCubit>()) {
    getIt.registerFactory<WeightHistoryCubit>(
      () => WeightHistoryCubit(weightRepository, _Ids()),
    );
    addTearDown(() async {
      if (getIt.isRegistered<WeightHistoryCubit>()) {
        await getIt.unregister<WeightHistoryCubit>();
      }
    });
  }
  if (visits == null) {
    when(visitRepository.getAllVetVisits)
        .thenAnswer((_) async => const Success([]));
  }
  if (vaccinations == null) {
    when(vaccinationRepository.getAllVaccinations)
        .thenAnswer((_) async => const Success([]));
  }
  if (medications == null) {
    when(medicationRepository.getAllMedications)
        .thenAnswer((_) async => const Success([]));
  }
  if (!getIt.isRegistered<VetVisitCubit>()) {
    getIt.registerFactory<VetVisitCubit>(() => VetVisitCubit(visitRepository));
    addTearDown(() async {
      if (getIt.isRegistered<VetVisitCubit>()) {
        await getIt.unregister<VetVisitCubit>();
      }
    });
  }
  if (!getIt.isRegistered<VaccinationCubit>()) {
    getIt.registerFactory<VaccinationCubit>(
      () => VaccinationCubit(vaccinationRepository, now: now ?? DateTime.now),
    );
    addTearDown(() async {
      if (getIt.isRegistered<VaccinationCubit>()) {
        await getIt.unregister<VaccinationCubit>();
      }
    });
  }
  if (!getIt.isRegistered<MedicationCubit>()) {
    getIt.registerFactory<MedicationCubit>(
      () => MedicationCubit(
        medicationRepository,
        const CalculateMedicationDoses(),
        now: now ?? DateTime.now,
      ),
    );
    addTearDown(() async {
      if (getIt.isRegistered<MedicationCubit>()) {
        await getIt.unregister<MedicationCubit>();
      }
    });
  }
  getIt.registerFactory<AllPetsCareCubit>(() => AllPetsCareCubit(pets));
  addTearDown(() async {
    if (getIt.isRegistered<AllPetsCareCubit>()) {
      await getIt.unregister<AllPetsCareCubit>();
    }
  });
}
