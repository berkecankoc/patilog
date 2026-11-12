import 'dart:io';
import 'package:patilog/features/feeding/data/data_sources/feeding_local_data_source.dart';
import 'package:patilog/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_form_cubit.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_form_state.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_state.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/database/database_tables.dart';
import 'package:patilog/core/di/injection.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/router/care_record_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:patilog/core/services/external_link_launcher.dart';
import 'package:patilog/core/services/url_external_link_launcher.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';
import '../../helpers/notification_test_harness.dart'
    show NotificationTestHarness;
import 'package:patilog/features/notification/data/data_sources/notification_local_data_source.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/repositories/notification_repository.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/medication/domain/repositories/medication_repository.dart';
import 'package:patilog/features/medication/domain/use_cases/create_medication.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_form_state.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';
import 'package:patilog/features/settings/domain/entities/theme_preference.dart';
import 'package:patilog/features/settings/domain/entities/language_preference.dart';
import 'package:patilog/features/settings/domain/repositories/settings_repository.dart';
import 'package:patilog/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:patilog/features/settings/presentation/cubit/settings_state.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';
import 'package:patilog/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:patilog/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_form_state.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:patilog/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_form_state.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPreferences extends Mock implements SharedPreferencesAsync {}

class MockNotifications extends Mock implements NotificationLocalDataSource {}

void main() {
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('injection-');
    await databaseFactory.setDatabasesPath(directory.path);
    await setupDependencies();
  });

  tearDown(() async {
    if (getIt.isRegistered<Database>()) await getIt<Database>().close();
    await getIt.reset();
    await directory.delete(recursive: true);
  });

  test(
    'feeding factories retain independent state backed by shared storage',
    () async {
      final source = getIt<FeedingLocalDataSource>();
      final repository = getIt<FeedingRepository>();
      expect(getIt<FeedingLocalDataSource>(), same(source));
      expect(getIt<FeedingRepository>(), same(repository));
      await getIt<Database>().insert(DatabaseTables.pets, {
        'id': 'feeding-pet',
        'name': 'Milo',
        'species': 'cat',
        'sex': 'male',
        'reproductive_status': 'intact',
      });
      final form = getIt<FeedingFormCubit>();
      final otherForm = getIt<FeedingFormCubit>();
      final list = getIt<FeedingCubit>();
      final global = getIt<FeedingCubit>();
      for (final cubit in [form, otherForm, list, global]) {
        addTearDown(cubit.close);
      }
      expect(form, isNot(same(otherForm)));
      expect(list, isNot(same(global)));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await form.savePlan(
        petId: 'feeding-pet',
        startDate: today,
        meals: const [
          FeedingMealDraft(
            scheduledMinute: 540,
            amountGrams: 30.5,
            foodName: ' Food ',
          ),
        ],
      );
      expect(form.state.isSaved, isTrue);
      expect(otherForm.state, const FeedingFormState());
      await list.load(petId: 'feeding-pet');
      final loaded = list.state as FeedingLoaded;
      expect(loaded.plans.single.id, isNotEmpty);
      expect(loaded.meals.single.meal.id, isNot(loaded.plans.single.id));
      expect(loaded.meals.single.entry, isNull);
      await list.recordMeal(loaded.meals.single);
      expect(
        (list.state as FeedingLoaded).meals.single.entry!.amountGrams,
        30.5,
      );
      expect(list.totalsFor('feeding-pet').last.amountGrams, 30.5);
      expect(global.state, const FeedingInitial());
      await global.load();
      expect(
        (global.state as FeedingLoaded).meals.single.entry!.foodName,
        'Food',
      );
      final saved = (list.state as FeedingLoaded).entries.single;
      await list.performAction(DeleteFeedingEntryAction(saved.petId, saved.id));
      expect((list.state as FeedingLoaded).entries, isEmpty);
      expect(
        (await getIt<Database>().query(DatabaseTables.feedingEntries)),
        isEmpty,
      );
      expect((global.state as FeedingLoaded).entries, hasLength(1));
    },
  );

  test(
    'notification repository reuses preferences without initializing the native adapter',
    () async {
      final preferences = MockPreferences();
      final native = MockNotifications();
      when(
        () => preferences.getAll(allowList: {'notification.preferences'}),
      ).thenAnswer((_) async => {});
      await getIt.unregister<SharedPreferencesAsync>();
      getIt.registerSingleton<SharedPreferencesAsync>(preferences);
      await getIt.unregister<NotificationLocalDataSource>();
      getIt.registerSingleton<NotificationLocalDataSource>(native);
      final repository = getIt<NotificationRepository>();
      expect(getIt<NotificationRepository>(), same(repository));
      expect(
        await repository.getPreferences(),
        Success(NotificationPreferences()),
      );
      verify(
        () => preferences.getAll(allowList: {'notification.preferences'}),
      ).called(1);
      verifyZeroInteractions(native);
    },
  );

  test(
    'native adapter is a singleton and closes its stream when unregistered',
    () async {
      final source = getIt<NotificationLocalDataSource>();
      expect(getIt<NotificationLocalDataSource>(), same(source));
      final closed = expectLater(source.openedNotifications, emitsDone);
      await getIt.unregister<NotificationLocalDataSource>();
      await closed;
    },
  );

  test(
    'registered medication writes remain successful when runtime reminder sync fails',
    () async {
      final fake = NotificationTestHarness();
      fake.preferences = NotificationPreferences(
        medicationRemindersEnabled: true,
      );
      await getIt.unregister<NotificationRepository>();
      getIt.registerSingleton<NotificationRepository>(fake.repository);
      const pet = Pet(
        id: 'pet-notification',
        name: 'Milo',
        species: PetSpecies.cat,
        sex: PetSex.male,
        reproductiveStatus: ReproductiveStatus.intact,
      );
      await getIt<PetRepository>().createPet(pet);
      final current = DateTime.now();
      final today = DateTime(current.year, current.month, current.day);
      await getIt<MedicationRepository>().createMedication(
        Medication(
          id: 'med-notification',
          petId: pet.id,
          name: 'Medicine',
          periods: [
            MedicationPeriod(
              id: 'period-notification',
              medicationId: 'med-notification',
              startDate: today,
              intervalDays: 1,
              doseTimes: [0],
            ),
          ],
        ),
      );
      final coordinator = getIt<NotificationCubit>();
      final global = getIt<MedicationCubit>()..setPetContext([pet.id]);
      final changes = getIt<CareRecordChanges>();
      Future<void>? syncing;
      var signals = 0;
      void changed() {
        signals++;
        syncing = coordinator.refresh();
      }

      changes.addListener(changed);
      addTearDown(() async {
        changes.removeListener(changed);
        await global.close();
        await coordinator.close();
        await fake.dispose();
      });
      await coordinator.initialize();
      await global.loadAllMedications();
      fake.failSync = true;
      await global.saveDose(
        (global.state as MedicationsLoaded).doses.doses.single,
        MedicationDoseStatus.given,
      );
      // The feature page publishes the committed result to the runtime.
      final loaded = global.state as MedicationsLoaded;
      changes.changed(
        loaded.lastMutation!.petId,
        PetCareTab.medications,
        globalListIsCurrent: true,
      );
      await syncing;
      expect(signals, 1);
      expect(changes.last!.globalListIsCurrent, isTrue);
      expect((global.state as MedicationsLoaded).actionError, isNull);
      expect((global.state as MedicationsLoaded).mutationRevision, 1);
      expect(
        await getIt<Database>().query(DatabaseTables.medicationDoseLogs),
        hasLength(1),
      );
      expect(coordinator.state.issue!.message, 'Sync failed');
    },
  );

  test('settings repository reuses the registered preferences store', () async {
    const key = 'settings.theme_preference';
    final preferences = MockPreferences();
    when(() => preferences.setString(key, 'dark')).thenAnswer((_) async {});
    when(
      () => preferences.getAll(allowList: {key}),
    ).thenAnswer((_) async => {key: 'dark'});
    await getIt.unregister<SharedPreferencesAsync>();
    getIt.registerSingleton<SharedPreferencesAsync>(preferences);

    final repository = getIt<SettingsRepository>();
    expect(getIt<SettingsRepository>(), same(repository));
    expect(
      await repository.setThemePreference(ThemePreference.dark),
      const Success<void>(null),
    );
    expect(
      await repository.getThemePreference(),
      const Success(ThemePreference.dark),
    );
    verify(() => preferences.setString(key, 'dark')).called(1);
    verify(() => preferences.getAll(allowList: {key})).called(1);
  });

  test(
    'settings factory creates independent state backed by the repository',
    () async {
      const key = 'settings.theme_preference';
      const languageKey = 'settings.language_preference';
      final preferences = MockPreferences();
      when(
        () => preferences.getAll(allowList: {key}),
      ).thenAnswer((_) async => {key: 'dark'});
      when(
        () => preferences.getAll(allowList: {languageKey}),
      ).thenAnswer((_) async => {languageKey: 'turkish'});
      when(() => preferences.setString(key, 'light')).thenAnswer((_) async {});
      await getIt.unregister<SharedPreferencesAsync>();
      getIt.registerSingleton<SharedPreferencesAsync>(preferences);

      final first = getIt<SettingsCubit>();
      final second = getIt<SettingsCubit>();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(first, isNot(same(second)));
      verifyZeroInteractions(preferences);
      await first.load();
      expect(first.state.themePreference, ThemePreference.dark);
      expect(first.state.languagePreference, LanguagePreference.turkish);
      await first.setThemePreference(ThemePreference.light);
      expect(first.state.themePreference, ThemePreference.light);
      expect(first.state.languagePreference, LanguagePreference.turkish);
      expect(second.state, const SettingsState());
      verify(() => preferences.getAll(allowList: {key})).called(1);
      verify(() => preferences.getAll(allowList: {languageKey})).called(1);
      verify(() => preferences.setString(key, 'light')).called(1);
    },
  );

  test(
    'global care factories keep independent state backed by shared repositories',
    () async {
      await getIt<Database>().insert(DatabaseTables.pets, {
        'id': 'pet-1',
        'name': 'Milo',
        'species': 'cat',
        'sex': 'male',
        'reproductive_status': 'intact',
      });
      final visit = VetVisit(
        id: 'visit-1',
        petId: 'pet-1',
        visitedOn: DateTime(2026, 10, 15),
        reason: 'Checkup',
      );
      await getIt<VetVisitRepository>().createVetVisit(visit);
      final first = getIt<AllPetsCareCubit>();
      final second = getIt<AllPetsCareCubit>();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(identical(first, second), isFalse);
      await first.activate(AllPetsCareSection.vetVisits);
      final clinical = getIt<VetVisitCubit>();
      addTearDown(clinical.close);
      await clinical.loadAllVetVisits();
      expect((clinical.state as VetVisitsLoaded).visits, [visit]);
      expect(first.state.petsById['pet-1']!.name, 'Milo');
      expect(second.state.pets.hasLoaded, isFalse);
      final untouched = getIt<VetVisitCubit>();
      addTearDown(untouched.close);
      expect(untouched.state, isA<VetVisitInitial>());
    },
  );

  test(
    'medication factories create independent route state backed by shared SQLite',
    () async {
      await getIt<Database>().insert(DatabaseTables.pets, {
        'id': 'pet-1',
        'name': 'Milo',
        'species': 'cat',
        'sex': 'male',
        'reproductive_status': 'intact',
      });
      final form = getIt<MedicationFormCubit>();
      final otherForm = getIt<MedicationFormCubit>();
      final list = getIt<MedicationCubit>();
      final detail = getIt<MedicationCubit>();
      for (final cubit in [form, otherForm, list, detail]) {
        addTearDown(cubit.close);
      }
      expect(identical(form, otherForm), false);
      expect(identical(list, detail), false);
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      await form.createMedication(
        CreateMedicationParams(
          petId: 'pet-1',
          name: 'Medicine',
          startDate: day,
          intervalDays: 1,
          doseTimes: [480],
          clinicName: 'Clinic',
          veterinarianName: 'Dr. Smith',
        ),
      );
      expect(form.state.isSaved, true);
      expect(otherForm.state, const MedicationFormState());
      await list.loadMedications('pet-1');
      final loaded = list.state as MedicationsLoaded;
      final medication = loaded.medications.single;
      expect(medication.id, isNotEmpty);
      expect(medication.periods.single.id, isNot(medication.id));
      expect(loaded.doses.doses.single.log, isNull);
      expect(detail.state, const MedicationInitial());
      await detail.loadMedication('pet-1', medication.id);
      await detail.saveDose(
        (detail.state as MedicationsLoaded).doses.doses.single,
        MedicationDoseStatus.given,
      );
      expect(
        (detail.state as MedicationsLoaded).doses.doses.single.log?.status,
        MedicationDoseStatus.given,
      );
      expect((list.state as MedicationsLoaded).doses.doses.single.log, isNull);
      await otherForm.checkPeriod(
        'pet-1',
        medication.id,
        medication.periods.single.id,
      );
      expect(otherForm.state.hasDoseLogs, true);
      await otherForm.loadSuggestions();
      expect(otherForm.state.suggestions.medicationNames, ['Medicine']);
      final sharedSuggestions = await getIt<VetVisitRepository>()
          .getSuggestions();
      expect(
        (sharedSuggestions as Success<VetVisitSuggestions>).data.clinicNames,
        ['Clinic'],
      );
      final result = await getIt<MedicationRepository>().getMedicationById(
        'other-pet',
        medication.id,
      );
      expect((result as Error).failure, isA<NotFoundFailure>());
    },
  );

  test(
    'vaccination factories use the shared persistence and independent state',
    () async {
      final db = getIt<Database>();
      await db.insert(DatabaseTables.pets, {
        'id': 'pet-1',
        'name': 'Milo',
        'species': 'cat',
        'sex': 'male',
        'reproductive_status': 'intact',
      });
      await getIt<VetVisitRepository>().createVetVisit(
        VetVisit(
          id: 'visit-1',
          petId: 'pet-1',
          visitedOn: DateTime(2020, 1, 2),
          reason: 'Checkup',
          clinicName: 'Clinic',
          veterinarianName: 'Dr. Smith',
        ),
      );
      final list = getIt<VaccinationCubit>();
      final otherList = getIt<VaccinationCubit>();
      final form = getIt<VaccinationFormCubit>();
      final otherForm = getIt<VaccinationFormCubit>();
      for (final cubit in [list, otherList, form, otherForm]) {
        addTearDown(cubit.close);
      }
      expect(identical(list, otherList), isFalse);
      expect(identical(form, otherForm), isFalse);
      await form.loadVisits('pet-1');
      await form.loadSuggestions();
      expect(form.state.visits.single.id, 'visit-1');
      expect(form.state.suggestions.clinicNames, ['Clinic']);
      await form.saveVaccination(
        SaveVaccinationParams(
          petId: 'pet-1',
          vaccineName: 'Rabies',
          status: VaccinationStatus.administered,
          date: DateTime(2020, 1, 2),
          vetVisitId: 'visit-1',
          clinicName: 'New clinic',
          veterinarianName: 'Dr. New',
          nextDoseDate: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      expect(form.state.isSaved, isTrue);
      expect(
        await getIt<VetVisitRepository>().getSuggestions(
          clinicName: 'New clinic',
        ),
        const Success(
          VetVisitSuggestions(
            clinicNames: ['Clinic', 'New clinic'],
            veterinarianNames: ['Dr. New'],
          ),
        ),
      );
      expect(otherForm.state, const VaccinationFormState());
      await list.loadVaccinations('pet-1');
      final rows = (list.state as VaccinationsLoaded).vaccinations;
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.id).toSet(), hasLength(2));
      expect(
        rows.every((row) => row.id.isNotEmpty && row.petId == 'pet-1'),
        isTrue,
      );
      expect(rows.first.status, VaccinationStatus.planned);
      expect(rows.first.vetVisitId, isNull);
      expect(rows.last.status, VaccinationStatus.administered);
      expect(rows.last.vetVisitId, 'visit-1');
      expect(otherList.state, const VaccinationInitial());
      final repository = getIt<VaccinationRepository>();
      expect(
        await repository.getVaccinationById('pet-1', rows.last.id),
        Success(rows.last),
      );
      expect(
        await repository.getVaccinationById('pet-2', rows.last.id),
        const Error<Vaccination>(NotFoundFailure('Vaccination not found')),
      );
      await repository.deleteVaccination('pet-1', rows.last.id);
      expect(await repository.getVaccinations('pet-1'), Success([rows.first]));
    },
  );

  test(
    'Cubit factories provide independent state and use the registered repository',
    () async {
      await getIt<Database>().insert(DatabaseTables.pets, {
        'id': 'pet-1',
        'name': 'Milo',
        'species': 'cat',
        'sex': 'male',
        'reproductive_status': 'intact',
      });
      final list = getIt<VetVisitCubit>();
      final otherList = getIt<VetVisitCubit>();
      final form = getIt<VetVisitFormCubit>();
      final otherForm = getIt<VetVisitFormCubit>();
      for (final cubit in [list, otherList, form, otherForm]) {
        addTearDown(cubit.close);
      }
      expect(identical(list, otherList), isFalse);
      expect(identical(form, otherForm), isFalse);
      await form.saveVetVisit(
        petId: 'pet-1',
        visitedOn: DateTime(2026, 10, 15),
        reason: 'Checkup',
      );
      expect(form.state.isSaved, isTrue);
      expect(otherForm.state, const VetVisitFormState());
      await list.loadVetVisits('pet-1');
      final loaded = list.state as VetVisitsLoaded;
      expect(loaded.visits.single.id, isNotEmpty);
      expect(loaded.visits.single.petId, 'pet-1');
      expect(loaded.visits.single.reason, 'Checkup');
      expect(otherList.state, const VetVisitInitial());
    },
  );

  test(
    'registered vet repository persists, reads and deletes through SQLite',
    () async {
      await getIt<Database>().insert(DatabaseTables.pets, {
        'id': 'pet-1',
        'name': 'Milo',
        'species': 'cat',
        'sex': 'male',
        'reproductive_status': 'intact',
      });
      final repository = getIt<VetVisitRepository>();
      final visit = VetVisit(
        id: 'visit-1',
        petId: 'pet-1',
        visitedOn: DateTime(2026, 10, 15),
        reason: 'Checkup',
        clinicName: 'Clinic',
        veterinarianName: 'Dr. Smith',
      );
      expect(await repository.createVetVisit(visit), const Success<void>(null));
      expect(
        await repository.getVetVisitById('pet-1', 'visit-1'),
        Success(visit),
      );
      expect(await repository.getVetVisits('pet-1'), Success([visit]));
      expect(
        await repository.getSuggestions(clinicName: 'Clinic'),
        const Success(
          VetVisitSuggestions(
            clinicNames: ['Clinic'],
            veterinarianNames: ['Dr. Smith'],
          ),
        ),
      );
      expect(
        await repository.getVetVisitById('pet-2', 'visit-1'),
        const Error<VetVisit>(NotFoundFailure('Vet visit not found')),
      );
      expect(
        await repository.deleteVetVisit('pet-1', 'visit-1'),
        const Success<void>(null),
      );
      expect(
        await repository.getVetVisits('pet-1'),
        const Success<List<VetVisit>>([]),
      );
    },
  );

  test('external links share one URL launcher', () {
    final launcher = getIt<ExternalLinkLauncher>();
    expect(launcher, isA<UrlExternalLinkLauncher>());
    expect(getIt<ExternalLinkLauncher>(), same(launcher));
  });
}
