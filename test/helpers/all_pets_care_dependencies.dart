import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';

class _Visits extends Mock implements VetVisitRepository {}

class _Vaccinations extends Mock implements VaccinationRepository {}

class _Medications extends Mock implements MedicationRepository {}

/// Pet-only routing tests need the global root without unrelated care fixtures.
void registerAllPetsCare(
  PetRepository pets, {
  VetVisitRepository? visits,
  VaccinationRepository? vaccinations,
  MedicationRepository? medications,
  DateTime Function()? now,
}) {
  final visitRepository = visits ?? _Visits();
  final vaccinationRepository = vaccinations ?? _Vaccinations();
  final medicationRepository = medications ?? _Medications();
  if (visits == null) {
    when(
      visitRepository.getAllVetVisits,
    ).thenAnswer((_) async => const Success([]));
  }
  if (vaccinations == null) {
    when(
      vaccinationRepository.getAllVaccinations,
    ).thenAnswer((_) async => const Success([]));
  }
  if (medications == null) {
    when(
      medicationRepository.getAllMedications,
    ).thenAnswer((_) async => const Success([]));
  }
  getIt.registerFactory<AllPetsCareCubit>(
    () => AllPetsCareCubit(
      pets,
      visitRepository,
      vaccinationRepository,
      medicationRepository,
      const CalculateMedicationDoses(),
      now: now,
    ),
  );
  addTearDown(() async {
    if (getIt.isRegistered<AllPetsCareCubit>()) {
      await getIt.unregister<AllPetsCareCubit>();
    }
  });
}
