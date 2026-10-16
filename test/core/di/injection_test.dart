import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
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
