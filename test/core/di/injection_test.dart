import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/medication/domain/use_cases/create_medication.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_form_state.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';
import 'package:petlytics/features/vaccination/domain/use_cases/save_vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_state.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:petlytics/features/vet_visit/domain/repositories/vet_visit_repository.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_state.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
}
