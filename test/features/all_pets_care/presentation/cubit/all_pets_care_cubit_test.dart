import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/calculate_medication_doses.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';

class MockPets extends Mock implements PetRepository {}

class MockVisits extends Mock implements VetVisitRepository {}

class MockVaccinations extends Mock implements VaccinationRepository {}

class MockMedications extends Mock implements MedicationRepository {}

void main() {
  const petsSection = AllPetsCareSection.pets;
  const visitsSection = AllPetsCareSection.vetVisits;
  const vaccinesSection = AllPetsCareSection.vaccinations;
  const medsSection = AllPetsCareSection.medications;
  const failure = LocalDatabaseFailure('Try again');
  final today = DateTime(2026, 10, 20);
  final yesterday = DateTime(2026, 10, 19);
  final tomorrow = DateTime(2026, 10, 21);
  const petA = Pet(
    id: 'a',
    name: 'Toby',
    species: PetSpecies.cat,
    sex: PetSex.male,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  const petB = Pet(
    id: 'b',
    name: 'Toby',
    species: PetSpecies.dog,
    sex: PetSex.female,
    reproductiveStatus: ReproductiveStatus.intact,
  );
  final visitA = VetVisit(
    id: 'visit-a',
    petId: 'a',
    visitedOn: today,
    reason: 'Checkup',
  );
  final visitB = VetVisit(
    id: 'visit-b',
    petId: 'b',
    visitedOn: yesterday,
    reason: 'Checkup',
  );
  Medication medication(String owner, {List<int> times = const [480]}) =>
      Medication(
        id: 'med-$owner',
        petId: owner,
        name: 'Medicine',
        periods: [
          MedicationPeriod(
            id: 'period-$owner',
            medicationId: 'med-$owner',
            startDate: yesterday,
            intervalDays: 1,
            doseTimes: times,
          ),
        ],
      );
  final medA = medication('a');
  final medB = medication('b');
  final vaccineA = Vaccination(
    id: 'vaccine-a',
    petId: 'a',
    vaccineName: 'Rabies',
    status: VaccinationStatus.planned,
    date: today,
  );
  final vaccineB = Vaccination(
    id: 'vaccine-b',
    petId: 'b',
    vaccineName: 'Rabies',
    status: VaccinationStatus.planned,
    date: tomorrow,
  );
  MedicationDoseLog log(
    String owner, {
    DateTime? date,
    MedicationDoseStatus status = MedicationDoseStatus.skipped,
    DateTime? givenAt,
    int minute = 480,
  }) => MedicationDoseLog(
    periodId: 'period-$owner',
    scheduledDate: date ?? today,
    scheduledMinute: minute,
    status: status,
    givenAt: givenAt,
  );
  late MockPets pets;
  late MockVisits visits;
  late MockVaccinations vaccinations;
  late MockMedications medications;
  late AllPetsCareCubit cubit;
  late DateTime clock;

  setUpAll(() {
    registerFallbackValue(today);
    registerFallbackValue(log('a'));
  });
  setUp(() {
    pets = MockPets();
    visits = MockVisits();
    vaccinations = MockVaccinations();
    medications = MockMedications();
    clock = DateTime(2026, 10, 20, 10, 15);
    cubit = AllPetsCareCubit(
      pets,
      visits,
      vaccinations,
      medications,
      const CalculateMedicationDoses(),
      now: () => clock,
    );
    when(
      () => pets.getPets(),
    ).thenAnswer((_) async => const Success([petA, petB]));
    when(
      () => visits.getAllVetVisits(),
    ).thenAnswer((_) async => Success([visitA, visitB]));
    when(
      () => vaccinations.getAllVaccinations(),
    ).thenAnswer((_) async => Success([vaccineA, vaccineB]));
    when(
      () => medications.getAllMedications(),
    ).thenAnswer((_) async => Success([medA, medB]));
    when(
      () => medications.getAllDoseLogs(
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer((_) async => const Success([]));
    when(
      () => visits.deleteVetVisit(any(), any()),
    ).thenAnswer((_) async => const Success<void>(null));
    when(
      () => vaccinations.deleteVaccination(any(), any()),
    ).thenAnswer((_) async => const Success<void>(null));
    when(
      () => medications.saveDoseLog(any(), any(), any()),
    ).thenAnswer((_) async => const Success<void>(null));
    when(
      () => medications.clearDoseLog(
        any(),
        any(),
        periodId: any(named: 'periodId'),
        scheduledDate: any(named: 'scheduledDate'),
        scheduledMinute: any(named: 'scheduledMinute'),
      ),
    ).thenAnswer((_) async => const Success<void>(null));
  });
  tearDown(() => cubit.close());

  blocTest<AllPetsCareCubit, AllPetsCareState>(
    'loads a shared pet directory',
    build: () => cubit,
    act: (c) => c.loadPets(),
    expect: () => [
      isA<AllPetsCareState>().having((s) => s.pets.isLoading, 'loading', true),
      isA<AllPetsCareState>()
          .having((s) => s.pets.records, 'pets', [petA, petB])
          .having((s) => s.pets.hasLoaded, 'loaded', true),
    ],
  );
  blocTest<AllPetsCareCubit, AllPetsCareState>(
    'initial read failure stays distinct from loaded empty',
    build: () => cubit,
    setUp: () => when(
      () => pets.getPets(),
    ).thenAnswer((_) async => const Error(failure)),
    act: (c) => c.loadPets(),
    expect: () => [
      isA<AllPetsCareState>().having((s) => s.pets.isLoading, 'loading', true),
      isA<AllPetsCareState>()
          .having((s) => s.pets.hasLoaded, 'loaded', false)
          .having((s) => s.pets.error, 'error', 'Try again'),
    ],
  );

  test(
    'sections load lazily and reuse one directory across repeated navigation',
    () async {
      await cubit.activate(petsSection);
      verifyNever(() => visits.getAllVetVisits());
      await cubit.activate(visitsSection);
      await cubit.activate(vaccinesSection);
      await cubit.activate(medsSection);
      await cubit.activate(visitsSection);
      await cubit.activate(medsSection);
      verify(() => pets.getPets()).called(1);
      verify(() => visits.getAllVetVisits()).called(1);
      verify(() => vaccinations.getAllVaccinations()).called(1);
      verify(() => medications.getAllMedications()).called(1);
      verify(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).called(1);
      verifyNever(() => visits.getVetVisits(any()));
      verifyNever(() => vaccinations.getVaccinations(any()));
      verifyNever(() => medications.getMedications(any()));
    },
  );
  test(
    'loaded empty is successful and is not fetched on each activation',
    () async {
      when(
        () => visits.getAllVetVisits(),
      ).thenAnswer((_) async => const Success([]));
      await cubit.activate(visitsSection);
      await cubit.activate(visitsSection);
      expect(cubit.state.visits.hasLoaded, isTrue);
      expect(cubit.state.visits.records, isEmpty);
      expect(cubit.state.visits.error, isNull);
      verify(() => visits.getAllVetVisits()).called(1);
    },
  );
  test(
    'filters are independent, use IDs despite equal names and perform no reads',
    () async {
      await cubit.activate(visitsSection);
      cubit.selectPet(visitsSection, 'a');
      expect(cubit.state.visibleVisits, [visitA]);
      await cubit.activate(vaccinesSection);
      expect(cubit.state.visibleVaccinations, [vaccineA, vaccineB]);
      cubit.selectPet(vaccinesSection, 'b');
      expect(cubit.state.visibleVaccinations, [vaccineB]);
      await cubit.activate(visitsSection);
      expect(cubit.state.visibleVisits, [visitA]);
      cubit.selectPet(visitsSection, 'unknown');
      expect(cubit.state.visibleVisits, [visitA]);
      cubit.selectPet(visitsSection, null);
      expect(cubit.state.visibleVisits, [visitA, visitB]);
      verify(() => pets.getPets()).called(1);
      verify(() => visits.getAllVetVisits()).called(1);
      verify(() => vaccinations.getAllVaccinations()).called(1);
    },
  );
  test(
    'refresh errors retain records and filters without clearing other sections',
    () async {
      await cubit.activate(vaccinesSection);
      await cubit.activate(visitsSection);
      cubit.selectPet(visitsSection, 'b');
      when(
        () => visits.getAllVetVisits(),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.refreshActive();
      expect(cubit.state.visibleVisits, [visitB]);
      expect(cubit.state.visits.hasLoaded, isTrue);
      expect(cubit.state.visits.error, 'Try again');
      expect(cubit.state.vaccinations.records, [vaccineA, vaccineB]);
    },
  );
  test(
    'failed initial load requires explicit retry rather than a navigation loop',
    () async {
      when(
        () => visits.getAllVetVisits(),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.activate(visitsSection);
      await cubit.activate(visitsSection);
      verify(() => visits.getAllVetVisits()).called(1);
      when(
        () => visits.getAllVetVisits(),
      ).thenAnswer((_) async => Success([visitA]));
      await cubit.refreshActive();
      expect(cubit.state.visits.records, [visitA]);
      expect(cubit.state.visits.error, isNull);
    },
  );
  test(
    'directory failure does not discard a successful care read and can retry separately',
    () async {
      when(() => pets.getPets()).thenAnswer((_) async => const Error(failure));
      await cubit.activate(visitsSection);
      expect(cubit.state.visits.records, [visitA, visitB]);
      expect(cubit.state.pets.error, 'Try again');
      when(
        () => pets.getPets(),
      ).thenAnswer((_) async => const Success([petA, petB]));
      await cubit.loadPets();
      expect(cubit.state.petsById['b'], petB);
      verify(() => visits.getAllVetVisits()).called(1);
    },
  );
  test('older reads cannot overwrite the latest successful refresh', () async {
    final first = Completer<Result<List<VetVisit>>>();
    final second = Completer<Result<List<VetVisit>>>();
    var calls = 0;
    when(
      () => visits.getAllVetVisits(),
    ).thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final old = cubit.loadVisits();
    final current = cubit.loadVisits();
    second.complete(Success([visitB]));
    await current;
    first.complete(Success([visitA]));
    await old;
    expect(cubit.state.visits.records, [visitB]);
  });
  test(
    'parallel section completions preserve the active section and its filter',
    () async {
      await cubit.loadPets();
      final pending = Completer<Result<List<VetVisit>>>();
      when(() => visits.getAllVetVisits()).thenAnswer((_) => pending.future);
      final openingVisits = cubit.activate(visitsSection);
      await cubit.activate(vaccinesSection);
      cubit.selectPet(vaccinesSection, 'b');
      pending.complete(Success([visitA, visitB]));
      await openingVisits;
      expect(cubit.state.activeSection, vaccinesSection);
      expect(cubit.state.visibleVaccinations, [vaccineB]);
      expect(cubit.state.visits.records, [visitA, visitB]);
    },
  );
  test(
    'known visit deletion reconciles an initial in-flight read without losing other rows',
    () async {
      final pending = Completer<Result<List<VetVisit>>>();
      when(() => visits.getAllVetVisits()).thenAnswer((_) => pending.future);
      final loading = cubit.activate(visitsSection);
      cubit.removeDeletedVisit('a', visitA.id);
      pending.complete(Success([visitA, visitB]));
      await loading;
      expect(cubit.state.visits.records, [visitB]);
      expect(cubit.state.visits.hasLoaded, isTrue);
      verify(() => visits.getAllVetVisits()).called(1);
    },
  );
  test(
    'known vaccination deletion stays removed after a stale refresh',
    () async {
      await cubit.activate(vaccinesSection);
      final pending = Completer<Result<List<Vaccination>>>();
      when(
        () => vaccinations.getAllVaccinations(),
      ).thenAnswer((_) => pending.future);
      final refresh = cubit.loadVaccinations();
      cubit.removeDeletedVaccination('a', vaccineA.id);
      pending.complete(Success([vaccineA, vaccineB]));
      await refresh;
      expect(cubit.state.vaccinations.records, [vaccineB]);
      verify(() => vaccinations.getAllVaccinations()).called(2);
    },
  );
  test(
    'known medication deletion removes its doses without a source reread',
    () async {
      await cubit.activate(medsSection);
      cubit.removeDeletedMedication('b', medB.id);
      expect(cubit.state.medications.records, [medA]);
      expect(
        cubit.state.doses.records.every((d) => d.medication.petId == 'a'),
        isTrue,
      );
      verify(() => medications.getAllMedications()).called(1);
      verify(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).called(1);
    },
  );
  test(
    'pet deletion prunes all cached records and filters without reads',
    () async {
      await cubit.activate(visitsSection);
      cubit.selectPet(visitsSection, 'b');
      await cubit.activate(vaccinesSection);
      cubit.selectPet(vaccinesSection, 'b');
      await cubit.activate(medsSection);
      cubit.selectPet(medsSection, 'b');
      cubit.removeDeletedPet('b');
      expect(cubit.state.pets.records, [petA]);
      expect(cubit.state.petFilters, isEmpty);
      expect(cubit.state.visits.records, [visitA]);
      expect(cubit.state.vaccinations.records, [vaccineA]);
      expect(cubit.state.medications.records, [medA]);
      expect(cubit.state.doses.records.single.medication, medA);
      verify(() => pets.getPets()).called(1);
      verify(() => medications.getAllMedications()).called(1);
    },
  );
  test(
    'directory refresh removes disappeared pets from cached care and filters',
    () async {
      await cubit.activate(visitsSection);
      cubit.selectPet(visitsSection, 'b');
      when(() => pets.getPets()).thenAnswer((_) async => const Success([petA]));
      await cubit.loadPets();
      expect(cubit.state.petFilters, isEmpty);
      expect(cubit.state.visits.records, [visitA]);
      verify(() => visits.getAllVetVisits()).called(1);
    },
  );
  test(
    'visit deletion uses its owner, removes locally and defers dependent refreshes',
    () async {
      await cubit.activate(vaccinesSection);
      await cubit.activate(medsSection);
      await cubit.activate(visitsSection);
      await cubit.performAction(DeleteGlobalVetVisit('b', visitB.id));
      expect(cubit.state.visits.records, [visitA]);
      expect(cubit.state.mutationRevision, 1);
      verify(() => visits.deleteVetVisit('b', visitB.id)).called(1);
      verify(() => visits.getAllVetVisits()).called(1);
      verify(() => vaccinations.getAllVaccinations()).called(1);
      await cubit.activate(vaccinesSection);
      verify(() => vaccinations.getAllVaccinations()).called(1);
      await cubit.activate(medsSection);
      verify(() => medications.getAllMedications()).called(2);
    },
  );
  test(
    'wrong owner, hidden filter row and missing visit never trigger deletes',
    () async {
      await cubit.activate(visitsSection);
      await cubit.performAction(DeleteGlobalVetVisit('a', visitB.id));
      await cubit.performAction(const DeleteGlobalVetVisit('a', 'missing'));
      cubit.selectPet(visitsSection, 'a');
      await cubit.performAction(DeleteGlobalVetVisit('b', visitB.id));
      verifyNever(() => visits.deleteVetVisit(any(), any()));
    },
  );
  test(
    'failed delete retains exact intent and data; retry success removes without reloading',
    () async {
      await cubit.activate(vaccinesSection);
      final action = DeleteGlobalVaccination('b', vaccineB.id);
      when(
        () => vaccinations.deleteVaccination('b', vaccineB.id),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.performAction(action);
      expect(cubit.state.vaccinations.records, [vaccineA, vaccineB]);
      expect(cubit.state.failedAction, action);
      expect(cubit.state.actionError, 'Try again');
      expect(cubit.state.mutationRevision, 0);
      when(
        () => vaccinations.deleteVaccination('b', vaccineB.id),
      ).thenAnswer((_) async => const Success<void>(null));
      await cubit.performAction(cubit.state.failedAction!);
      expect(cubit.state.vaccinations.records, [vaccineA]);
      expect(cubit.state.failedAction, isNull);
      expect(cubit.state.lastMutation, action);
      expect(cubit.state.mutationRevision, 1);
      verify(() => vaccinations.getAllVaccinations()).called(1);
    },
  );
  test(
    'pending write blocks duplicate writes, filters, date changes and section changes',
    () async {
      await cubit.activate(medsSection);
      final pending = Completer<Result<void>>();
      when(
        () => medications.saveDoseLog(any(), any(), any()),
      ).thenAnswer((_) => pending.future);
      final saving = cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.given,
      );
      await cubit.saveDose(
        cubit.state.doses.records.last,
        MedicationDoseStatus.skipped,
      );
      cubit.selectPet(medsSection, 'b');
      await cubit.activate(visitsSection);
      await cubit.loadDoses(yesterday);
      expect(cubit.state.activeSection, medsSection);
      expect(cubit.state.petFilters, isEmpty);
      expect(cubit.state.doseDate, today);
      expect(cubit.state.isBusy, isTrue);
      pending.complete(const Success<void>(null));
      await saving;
      verify(() => medications.saveDoseLog(any(), any(), any())).called(1);
      expect(cubit.state.isBusy, isFalse);
    },
  );
  test(
    'today Given uses current instant and canonical owner despite identical medication names',
    () async {
      await cubit.activate(medsSection);
      final dose = cubit.state.doses.records.last;
      await cubit.saveDose(dose, MedicationDoseStatus.given);
      final captured =
          verify(
                () => medications.saveDoseLog('b', medB.id, captureAny()),
              ).captured.single
              as MedicationDoseLog;
      expect(captured.givenAt, clock);
      expect(captured.scheduledDate, today);
      expect(captured.periodId, 'period-b');
      expect(cubit.state.doses.records.first.log, isNull);
      expect(cubit.state.doses.records.last.log, captured);
      verify(() => medications.getAllMedications()).called(1);
      verify(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).called(1);
    },
  );
  test(
    'save, correct and clear a dose update only that result without reloading',
    () async {
      await cubit.activate(medsSection);
      await cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.given,
      );
      await cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.skipped,
      );
      final skipped = cubit.state.doses.records.first.log!;
      expect(skipped.givenAt, isNull);
      await cubit.performAction(ClearGlobalDose('a', medA.id, skipped));
      expect(cubit.state.doses.records.first.log, isNull);
      expect(cubit.state.mutationRevision, 3);
      verify(
        () => medications.clearDoseLog(
          'a',
          medA.id,
          periodId: 'period-a',
          scheduledDate: today,
          scheduledMinute: 480,
        ),
      ).called(1);
      verify(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).called(1);
    },
  );
  test('dose failure retains exact timestamp for an explicit retry', () async {
    await cubit.activate(medsSection);
    final recordedAt = clock;
    when(
      () => medications.saveDoseLog(any(), any(), any()),
    ).thenAnswer((_) async => const Error(failure));
    await cubit.saveDose(
      cubit.state.doses.records.first,
      MedicationDoseStatus.given,
    );
    final retry = cubit.state.failedAction! as SaveGlobalDose;
    expect(retry.log.givenAt, recordedAt);
    expect(cubit.state.doses.records.first.log, isNull);
    clock = clock.add(const Duration(minutes: 1));
    when(
      () => medications.saveDoseLog(any(), any(), any()),
    ).thenAnswer((_) async => const Success<void>(null));
    await cubit.performAction(retry);
    expect(cubit.state.doses.records.first.log!.givenAt, recordedAt);
    expect(cubit.state.mutationRevision, 1);
  });
  test(
    'unknown dose results stay distinct from No record and block writes until retry',
    () async {
      when(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.activate(medsSection);
      expect(cubit.state.doseResultsKnown, isFalse);
      expect(cubit.state.doses.error, 'Try again');
      await cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.skipped,
      );
      verifyNever(() => medications.saveDoseLog(any(), any(), any()));
      when(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).thenAnswer((_) async => const Success([]));
      await cubit.loadDoses(today);
      expect(cubit.state.doseResultsKnown, isTrue);
      expect(cubit.state.doses.records.first.log, isNull);
    },
  );
  test(
    'dose refresh failure keeps recorded outcomes while marking them unavailable for writes',
    () async {
      await cubit.activate(medsSection);
      await cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.skipped,
      );
      when(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.loadDoses(today);
      expect(
        cubit.state.doses.records.first.log!.status,
        MedicationDoseStatus.skipped,
      );
      expect(cubit.state.doseResultsKnown, isFalse);
    },
  );
  test('future days are readable but cannot be recorded', () async {
    await cubit.activate(medsSection);
    await cubit.loadDoses(tomorrow);
    expect(cubit.state.doses.records, hasLength(2));
    await cubit.saveDose(
      cubit.state.doses.records.first,
      MedicationDoseStatus.given,
    );
    await cubit.saveDose(
      cubit.state.doses.records.first,
      MedicationDoseStatus.skipped,
    );
    verifyNever(() => medications.saveDoseLog(any(), any(), any()));
  });
  test(
    'wrong pet, unscheduled time, future Given and clearing an absent log are rejected',
    () async {
      await cubit.activate(medsSection);
      await cubit.performAction(SaveGlobalDose('a', medB.id, log('b')));
      await cubit.performAction(
        SaveGlobalDose('a', medA.id, log('a', minute: 100)),
      );
      await cubit.performAction(
        SaveGlobalDose(
          'a',
          medA.id,
          log(
            'a',
            status: MedicationDoseStatus.given,
            givenAt: clock.add(const Duration(seconds: 1)),
          ),
        ),
      );
      await cubit.performAction(ClearGlobalDose('a', medA.id, log('a')));
      verifyNever(() => medications.saveDoseLog(any(), any(), any()));
      verifyNever(
        () => medications.clearDoseLog(
          any(),
          any(),
          periodId: any(named: 'periodId'),
          scheduledDate: any(named: 'scheduledDate'),
          scheduledMinute: any(named: 'scheduledMinute'),
        ),
      );
    },
  );
  test(
    'minute changes are local, midnight follows today, selected history stays fixed',
    () async {
      await cubit.activate(medsSection);
      clock = clock.add(const Duration(minutes: 1));
      await cubit.refreshForClockChange();
      verify(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).called(1);
      clock = DateTime(2026, 10, 21, 0, 1);
      await cubit.refreshForClockChange();
      expect(cubit.state.doseDate, tomorrow);
      verify(
        () => medications.getAllDoseLogs(fromDate: tomorrow, toDate: tomorrow),
      ).called(1);
      await cubit.loadDoses(yesterday);
      clock = DateTime(2026, 10, 22, 0, 1);
      await cubit.refreshForClockChange();
      expect(cubit.state.doseDate, yesterday);
      expect(cubit.state.followsToday, isFalse);
      verify(
        () =>
            medications.getAllDoseLogs(fromDate: yesterday, toDate: yesterday),
      ).called(1);
    },
  );
  test(
    'failed dose retains its selected day at midnight until explicit navigation',
    () async {
      await cubit.activate(medsSection);
      when(
        () => medications.saveDoseLog(any(), any(), any()),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.given,
      );
      clock = DateTime(2026, 10, 21, 0, 1);
      await cubit.refreshForClockChange();
      expect(cubit.state.doseDate, today);
      expect(cubit.state.failedAction, isA<SaveGlobalDose>());
      verifyNever(
        () => medications.getAllDoseLogs(fromDate: tomorrow, toDate: tomorrow),
      );
      await cubit.loadDoses(tomorrow);
      expect(cubit.state.failedAction, isNull);
      expect(cubit.state.doseDate, tomorrow);
    },
  );
  test('inactive medication section does no clock-driven log reads', () async {
    await cubit.activate(medsSection);
    await cubit.activate(visitsSection);
    clock = DateTime(2026, 10, 21, 0, 1);
    await cubit.refreshForClockChange();
    verifyNever(
      () => medications.getAllDoseLogs(fromDate: tomorrow, toDate: tomorrow),
    );
    await cubit.activate(medsSection);
    expect(cubit.state.doseDate, tomorrow);
    verify(
      () => medications.getAllDoseLogs(fromDate: tomorrow, toDate: tomorrow),
    ).called(1);
  });
  test(
    'a medication refresh completing while hidden reloads its doses on next entry',
    () async {
      await cubit.activate(medsSection);
      final pending = Completer<Result<List<Medication>>>();
      when(
        () => medications.getAllMedications(),
      ).thenAnswer((_) => pending.future);
      final refreshing = cubit.loadMedications();
      await cubit.activate(visitsSection);
      final changed = medication('a', times: [600, 720]);
      pending.complete(Success([changed]));
      await refreshing;
      expect(cubit.state.doses.hasLoaded, isFalse);
      await cubit.activate(medsSection);
      expect(cubit.state.doses.records.map((d) => d.scheduledMinute), [
        600,
        720,
      ]);
      verify(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).called(2);
    },
  );
  test('stale day result cannot replace a newer selected day', () async {
    await cubit.activate(medsSection);
    final pending = Completer<Result<List<MedicationDoseLog>>>();
    when(
      () => medications.getAllDoseLogs(fromDate: yesterday, toDate: yesterday),
    ).thenAnswer((_) => pending.future);
    final old = cubit.loadDoses(yesterday);
    await cubit.loadDoses(today);
    pending.complete(Success([log('a', date: yesterday)]));
    await old;
    expect(cubit.state.doseDate, today);
    expect(
      cubit.state.doses.records.every(
        (d) => d.scheduledDate == today && d.log == null,
      ),
      isTrue,
    );
  });
  test(
    'dirty medication data cannot accept writes or fetch logs before canonical refresh',
    () async {
      await cubit.activate(medsSection);
      cubit.invalidate(medsSection);
      expect(cubit.state.doseResultsKnown, isFalse);
      await cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.skipped,
      );
      await cubit.loadDoses(today);
      verifyNever(() => medications.saveDoseLog(any(), any(), any()));
      verify(
        () => medications.getAllDoseLogs(fromDate: today, toDate: today),
      ).called(1);
      await cubit.activate(medsSection);
      expect(cubit.state.doseResultsKnown, isTrue);
      verify(() => medications.getAllMedications()).called(2);
    },
  );
  test(
    'an externally deleted failed target cannot leave a stale Retry action',
    () async {
      await cubit.activate(vaccinesSection);
      when(
        () => vaccinations.deleteVaccination('b', vaccineB.id),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.performAction(DeleteGlobalVaccination('b', vaccineB.id));
      cubit.removeDeletedVaccination('b', vaccineB.id);
      expect(cubit.state.failedAction, isNull);
      expect(cubit.state.actionError, isNull);
      expect(cubit.state.mutationRevision, 0);
      expect(cubit.state.vaccinations.records, [vaccineA]);
    },
  );
  test(
    'successful external medication changes clear the now-stale dose retry',
    () async {
      await cubit.activate(medsSection);
      when(
        () => medications.saveDoseLog(any(), any(), any()),
      ).thenAnswer((_) async => const Error(failure));
      await cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.given,
      );
      cubit.invalidate(medsSection);
      expect(cubit.state.failedAction, isNull);
      expect(cubit.state.actionError, isNull);
      expect(cubit.state.doseResultsKnown, isFalse);
    },
  );
  test(
    'a known pet deletion reconciles later directory and visit completions',
    () async {
      final petsRead = Completer<Result<List<Pet>>>();
      final visitsRead = Completer<Result<List<VetVisit>>>();
      when(() => pets.getPets()).thenAnswer((_) => petsRead.future);
      when(() => visits.getAllVetVisits()).thenAnswer((_) => visitsRead.future);
      final loading = cubit.activate(visitsSection);
      cubit.removeDeletedPet('b');
      petsRead.complete(const Success([petA, petB]));
      visitsRead.complete(Success([visitA, visitB]));
      await loading;
      expect(cubit.state.pets.records, [petA]);
      expect(cubit.state.visits.records, [visitA]);
      verify(() => pets.getPets()).called(1);
      verify(() => visits.getAllVetVisits()).called(1);
    },
  );
  test(
    'known medication deletion survives a pending canonical medication read',
    () async {
      await cubit.activate(medsSection);
      final pending = Completer<Result<List<Medication>>>();
      when(
        () => medications.getAllMedications(),
      ).thenAnswer((_) => pending.future);
      final refreshing = cubit.loadMedications();
      cubit.removeDeletedMedication('b', medB.id);
      pending.complete(Success([medA, medB]));
      await refreshing;
      expect(cubit.state.medications.records, [medA]);
      expect(cubit.state.doses.records.single.medication, medA);
      verify(() => medications.getAllMedications()).called(2);
    },
  );
  test(
    'successful mutation notifications include the updated result atomically',
    () async {
      await cubit.activate(medsSection);
      final states = <AllPetsCareState>[];
      final subscription = cubit.stream.listen(states.add);
      await cubit.saveDose(
        cubit.state.doses.records.first,
        MedicationDoseStatus.given,
      );
      await Future<void>.delayed(Duration.zero);
      final notification = states.firstWhere((s) => s.mutationRevision == 1);
      expect(
        notification.doses.records.first.log!.status,
        MedicationDoseStatus.given,
      );
      expect(notification.isBusy, isFalse);
      await subscription.cancel();
    },
  );
  test('closing before an awaited read completes does not emit', () async {
    final pending = Completer<Result<List<VetVisit>>>();
    when(() => visits.getAllVetVisits()).thenAnswer((_) => pending.future);
    final loading = cubit.loadVisits();
    await cubit.close();
    final closedState = cubit.state;
    pending.complete(Success([visitA]));
    await loading;
    expect(cubit.state, same(closedState));
  });
  test(
    'closing during a write permits completion without emitting or repeating it',
    () async {
      await cubit.activate(visitsSection);
      final pending = Completer<Result<void>>();
      when(
        () => visits.deleteVetVisit('a', visitA.id),
      ).thenAnswer((_) => pending.future);
      final writing = cubit.performAction(DeleteGlobalVetVisit('a', visitA.id));
      await cubit.close();
      final closedState = cubit.state;
      pending.complete(const Success<void>(null));
      await writing;
      expect(cubit.state, same(closedState));
      verify(() => visits.deleteVetVisit('a', visitA.id)).called(1);
    },
  );
}
