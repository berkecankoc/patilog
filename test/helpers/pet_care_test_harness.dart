import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/domain/repositories/weight_history_repository.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'dart:async';
import 'all_pets_care_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_router.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_keyboard.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_suggestions.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/medication/domain/use_cases/create_medication.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_visits_cubit.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/delete_pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';

class MockWeights extends Mock implements WeightHistoryRepository {}

class MockMedications extends Mock implements MedicationRepository {}

class MockVisits extends Mock implements VetVisitRepository {}

class MockPets extends Mock implements PetRepository {}

class MockVaccinations extends Mock implements VaccinationRepository {}

class MockIds extends Mock implements IdGenerator {}

class MockCreatePet extends Mock implements CreatePet {}

class MockUpdatePet extends Mock implements UpdatePet {}

class MockDeletePet extends Mock implements DeletePet {}

class PetCareTestHarness {
  final repository = MockMedications();
  final weights = MockWeights();
  List<WeightEntry> measurements = [];
  final visits = MockVisits();
  final pets = MockPets();
  final vaccinations = MockVaccinations();
  final ids = MockIds();
  final today = DateUtils.dateOnly(DateTime.now());
  late DateTime clock = DateTime(today.year, today.month, today.day, 12, 15);
  List<Medication> medications = [];
  final logs = <MedicationDoseLog>[];
  bool failCreate = false;
  bool failDose = false;
  bool failClear = false;
  bool failDelete = false;
  Completer<Result<void>>? pendingCreate;
  Completer<Result<void>>? pendingDose;

  Medication sample({List<MedicationPeriod>? periods}) => Medication(
    id: 'med',
    petId: 'pet',
    name: 'Medication A',
    periods:
        periods ??
        [
          MedicationPeriod(
            id: 'period',
            medicationId: 'med',
            startDate: DateTime(today.year, today.month, today.day - 2),
            intervalDays: 1,
            doseTimes: [480, 1200],
            clinicName: 'Clinic A',
          ),
        ],
  );

  void register() {
    when(() => weights.getWeightEntries(any())).thenAnswer(
      (call) async => Success(
        measurements
            .where((e) => e.petId == call.positionalArguments[0])
            .toList(),
      ),
    );
    getIt.registerFactory<WeightHistoryCubit>(
      () => WeightHistoryCubit(weights, ids),
    );
    var nextId = 0;
    when(ids.generate).thenAnswer((_) => 'new-${nextId++}');
    when(
      () => repository.getMedications(
        any(),
        vetVisitId: any(named: 'vetVisitId'),
      ),
    ).thenAnswer(
      (call) async => Success(
        medications
            .where(
              (medication) =>
                  medication.petId == call.positionalArguments[0] &&
                  (call.namedArguments[#vetVisitId] == null ||
                      medication.periods.any(
                        (period) =>
                            period.vetVisitId ==
                            call.namedArguments[#vetVisitId],
                      )),
            )
            .toList(),
      ),
    );
    when(() => repository.getMedicationById(any(), any())).thenAnswer((
      call,
    ) async {
      final found = medications
          .where(
            (medication) =>
                medication.petId == call.positionalArguments[0] &&
                medication.id == call.positionalArguments[1],
          )
          .firstOrNull;
      return found == null
          ? const Error(NotFoundFailure('Medication record not found'))
          : Success(found);
    });
    when(
      () => repository.getSuggestions(clinicName: any(named: 'clinicName')),
    ).thenAnswer(
      (_) async => const Success(
        MedicationSuggestions(
          medicationNames: [],
          clinicNames: ['Clinic A'],
          veterinarianNames: ['Vet A'],
        ),
      ),
    );
    when(() => repository.hasDoseLogs(any(), any(), any())).thenAnswer(
      (call) async => Success(
        logs.any((log) => log.periodId == call.positionalArguments[2]),
      ),
    );
    when(
      () => repository.getDoseLogs(
        any(),
        medicationId: any(named: 'medicationId'),
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer(
      (call) async => Success(
        logs
            .where(
              (log) =>
                  !DateUtils.dateOnly(
                    log.scheduledDate,
                  ).isBefore(call.namedArguments[#fromDate] as DateTime) &&
                  !DateUtils.dateOnly(
                    log.scheduledDate,
                  ).isAfter(call.namedArguments[#toDate] as DateTime),
            )
            .toList(),
      ),
    );
    when(() => repository.createMedication(any())).thenAnswer((call) async {
      final result = pendingCreate != null
          ? await pendingCreate!.future
          : failCreate
          ? const Error<void>(LocalDatabaseFailure('Save failed'))
          : const Success<void>(null);
      if (result is Success<void>) {
        medications.add(call.positionalArguments[0] as Medication);
      }
      return result;
    });
    Future<Result<void>> savePeriod(Invocation call, bool create) async {
      final period = call.positionalArguments[1] as MedicationPeriod;
      medications = medications
          .map(
            (medication) => medication.id != period.medicationId
                ? medication
                : Medication(
                    id: medication.id,
                    petId: medication.petId,
                    name:
                        call.namedArguments[#medicationName] as String? ??
                        medication.name,
                    periods: create
                        ? [...medication.periods, period]
                        : medication.periods
                              .map((old) => old.id == period.id ? period : old)
                              .toList(),
                  ),
          )
          .toList();
      return const Success(null);
    }

    when(
      () => repository.createPeriod(
        any(),
        any(),
        medicationName: any(named: 'medicationName'),
      ),
    ).thenAnswer((call) => savePeriod(call, true));
    when(
      () => repository.updatePeriod(
        any(),
        any(),
        medicationName: any(named: 'medicationName'),
      ),
    ).thenAnswer((call) => savePeriod(call, false));
    when(() => repository.saveDoseLog(any(), any(), any())).thenAnswer((
      call,
    ) async {
      final result = pendingDose != null
          ? await pendingDose!.future
          : failDose
          ? const Error<void>(LocalDatabaseFailure('Dose save failed'))
          : const Success<void>(null);
      if (result is Success<void>) {
        final log = call.positionalArguments[2] as MedicationDoseLog;
        logs.removeWhere(
          (old) =>
              old.periodId == log.periodId &&
              old.scheduledDate == log.scheduledDate &&
              old.scheduledMinute == log.scheduledMinute,
        );
        logs.add(log);
      }
      return result;
    });
    when(
      () => repository.clearDoseLog(
        any(),
        any(),
        periodId: any(named: 'periodId'),
        scheduledDate: any(named: 'scheduledDate'),
        scheduledMinute: any(named: 'scheduledMinute'),
      ),
    ).thenAnswer((call) async {
      if (failClear) return const Error(LocalDatabaseFailure('Clear failed'));
      logs.removeWhere(
        (log) =>
            log.periodId == call.namedArguments[#periodId] &&
            log.scheduledDate == call.namedArguments[#scheduledDate] &&
            log.scheduledMinute == call.namedArguments[#scheduledMinute],
      );
      return const Success(null);
    });
    when(() => repository.deleteMedication(any(), any())).thenAnswer((
      call,
    ) async {
      if (failDelete) return const Error(LocalDatabaseFailure('Delete failed'));
      medications.removeWhere(
        (medication) => medication.id == call.positionalArguments[1],
      );
      return const Success(null);
    });
    when(() => repository.deletePeriod(any(), any(), any())).thenAnswer((
      call,
    ) async {
      medications = medications
          .map(
            (medication) => Medication(
              id: medication.id,
              petId: medication.petId,
              name: medication.name,
              periods: medication.periods
                  .where((period) => period.id != call.positionalArguments[2])
                  .toList(),
            ),
          )
          .toList();
      return const Success(null);
    });
    final visit = VetVisit(
      id: 'visit',
      petId: 'pet',
      visitedOn: today,
      reason: 'Check-up',
      clinicName: 'Clinic A',
    );
    when(
      () => visits.getVetVisits(any()),
    ).thenAnswer((_) async => Success([visit]));
    when(
      () => visits.getVetVisitById(any(), any()),
    ).thenAnswer((_) async => Success(visit));
    when(
      () => visits.getSuggestions(clinicName: any(named: 'clinicName')),
    ).thenAnswer(
      (_) async => const Success(
        VetVisitSuggestions(clinicNames: [], veterinarianNames: []),
      ),
    );
    const pet = Pet(
      id: 'pet',
      name: 'Simba',
      species: PetSpecies.cat,
      sex: PetSex.male,
      reproductiveStatus: ReproductiveStatus.intact,
    );
    when(pets.getPets).thenAnswer((_) async => const Success([pet]));
    when(
      () => pets.getPetById(any()),
    ).thenAnswer((_) async => const Success(pet));
    when(
      () => vaccinations.getVaccinations(
        any(),
        vetVisitId: any(named: 'vetVisitId'),
      ),
    ).thenAnswer((_) async => const Success([]));
    getIt.registerFactory<PetCubit>(
      () => PetCubit(pets, MockCreatePet(), MockUpdatePet(), MockDeletePet()),
    );
    getIt.registerFactory<MedicationCubit>(
      () => MedicationCubit(
        repository,
        const CalculateMedicationDoses(),
        now: () => clock,
      ),
    );
    getIt.registerFactory<MedicationFormCubit>(
      () => MedicationFormCubit(
        repository,
        visits,
        CreateMedication(repository, ids),
        ids,
      ),
    );
    getIt.registerFactory<MedicationVisitsCubit>(
      () => MedicationVisitsCubit(visits),
    );
    getIt.registerFactory<VetVisitCubit>(() => VetVisitCubit(visits));
    getIt.registerFactory<VaccinationCubit>(
      () => VaccinationCubit(vaccinations, now: () => clock),
    );
    when(visits.getAllVetVisits).thenAnswer((_) async => Success([visit]));
    when(
      vaccinations.getAllVaccinations,
    ).thenAnswer((_) async => const Success([]));
    when(
      repository.getAllMedications,
    ).thenAnswer((_) async => Success(medications));
    when(
      () => repository.getAllDoseLogs(
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer(
      (call) async => Success(
        logs
            .where(
              (log) =>
                  !DateUtils.dateOnly(
                    log.scheduledDate,
                  ).isBefore(call.namedArguments[#fromDate] as DateTime) &&
                  !DateUtils.dateOnly(
                    log.scheduledDate,
                  ).isAfter(call.namedArguments[#toDate] as DateTime),
            )
            .toList(),
      ),
    );
    registerAllPetsCare(
      pets,
      visits: visits,
      vaccinations: vaccinations,
      medications: repository,
      now: () => clock,
    );
  }

  Future<GoRouter> pump(
    WidgetTester tester, {
    String location = '/pets/pet/medications',
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    double keyboard = 0,
    double bottomInset = 0,
    GlobalKey? captureKey,
    Locale locale = englishLocale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: location,
      routes: appRouter.configuration.routes,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await getIt.reset();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          locale: locale,
          supportedLocales: appSupportedLocales,
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark : AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
              padding: EdgeInsets.only(bottom: bottomInset),
              viewPadding: EdgeInsets.only(bottom: bottomInset),
            ),
            child: AppKeyboard(child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }
}
