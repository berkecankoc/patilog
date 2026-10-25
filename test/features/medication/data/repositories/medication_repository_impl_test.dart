import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/medication/data/data_sources/medication_local_data_source.dart';
import 'package:petlytics/features/medication/data/models/medication_dose_log_model.dart';
import 'package:petlytics/features/medication/data/models/medication_model.dart';
import 'package:petlytics/features/medication/data/models/medication_period_model.dart';
import 'package:petlytics/features/medication/data/repositories/medication_repository_impl.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_suggestions.dart';

class MockMedicationLocalDataSource extends Mock
    implements MedicationLocalDataSource {}

void main() {
  late MockMedicationLocalDataSource source;
  late MedicationRepositoryImpl repository;
  final day = DateTime(2026, 10, 20);
  final period = MedicationPeriod(
    id: 'period',
    medicationId: 'medicine',
    startDate: day,
    intervalDays: 2,
    doseTimes: [480],
    dosageInstructions: 'Half',
    clinicName: 'Clinic',
    veterinarianName: 'Dr. Smith',
    notes: 'After food',
    vetVisitId: 'visit',
  );
  final medication = Medication(
    id: 'medicine',
    petId: 'pet',
    name: 'Medicine',
    periods: [period],
  );
  final log = MedicationDoseLog(
    periodId: 'period',
    scheduledDate: day,
    scheduledMinute: 480,
    status: MedicationDoseStatus.given,
    givenAt: DateTime.utc(2026, 10, 20, 5),
  );
  final model = MedicationModel.fromEntity(medication);
  final periodModel = MedicationPeriodModel.fromEntity(period);
  final logModel = MedicationDoseLogModel.fromEntity(log);

  setUp(() {
    source = MockMedicationLocalDataSource();
    repository = MedicationRepositoryImpl(source);
  });

  test(
    'all medications map complete periods without per-pet queries',
    () async {
      final other = Medication(
        id: 'other',
        petId: 'other-pet',
        name: 'Other medicine',
        periods: [
          MedicationPeriod(
            id: 'other-period',
            medicationId: 'other',
            startDate: day,
            intervalDays: 1,
            doseTimes: [600],
          ),
        ],
      );
      when(
        source.getAllMedications,
      ).thenAnswer((_) async => [MedicationModel.fromEntity(other), model]);
      expect(
        await repository.getAllMedications(),
        Success([other, medication]),
      );
      verify(source.getAllMedications).called(1);
      verifyNever(() => source.getMedications(any()));
    },
  );

  test(
    'all dose logs retain the requested range and actual result fields',
    () async {
      final end = DateTime(2026, 10, 21);
      final other = MedicationDoseLog(
        periodId: 'other-period',
        scheduledDate: day,
        scheduledMinute: 600,
        status: MedicationDoseStatus.skipped,
      );
      when(() => source.getAllDoseLogs(fromDate: day, toDate: end)).thenAnswer(
        (_) async => [logModel, MedicationDoseLogModel.fromEntity(other)],
      );
      expect(
        await repository.getAllDoseLogs(fromDate: day, toDate: end),
        Success([log, other]),
      );
      verify(() => source.getAllDoseLogs(fromDate: day, toDate: end)).called(1);
    },
  );

  test('all-pet reads preserve empty lists as success', () async {
    when(source.getAllMedications).thenAnswer((_) async => []);
    when(
      () => source.getAllDoseLogs(fromDate: day, toDate: day),
    ).thenAnswer((_) async => []);
    expect(
      await repository.getAllMedications(),
      const Success<List<Medication>>([]),
    );
    expect(
      await repository.getAllDoseLogs(fromDate: day, toDate: day),
      const Success<List<MedicationDoseLog>>([]),
    );
  });

  test('period lock read preserves the scoped boolean result', () async {
    for (final hasLogs in [false, true]) {
      when(
        () => source.hasDoseLogs('pet', 'medicine', 'period'),
      ).thenAnswer((_) async => hasLogs);
      expect(
        await repository.hasDoseLogs('pet', 'medicine', 'period'),
        Success(hasLogs),
      );
    }
  });

  test('linked list and detail reads map the complete period data', () async {
    when(
      () => source.getMedications('pet', vetVisitId: 'visit'),
    ).thenAnswer((_) async => [model]);
    when(
      () => source.getMedicationById('pet', 'medicine'),
    ).thenAnswer((_) async => model);
    expect(
      await repository.getMedications('pet', vetVisitId: 'visit'),
      Success<List<Medication>>([medication]),
    );
    expect(
      await repository.getMedicationById('pet', 'medicine'),
      Success(medication),
    );
    verify(() => source.getMedications('pet', vetVisitId: 'visit')).called(1);
    verify(() => source.getMedicationById('pet', 'medicine')).called(1);
  });

  test(
    'creation and period writes convert every field through their models',
    () async {
      when(() => source.createMedication(model)).thenAnswer((_) async {});
      when(
        () => source.createPeriod('pet', periodModel),
      ).thenAnswer((_) async {});
      when(
        () => source.updatePeriod('pet', periodModel),
      ).thenAnswer((_) async {});
      expect(
        await repository.createMedication(medication),
        const Success<void>(null),
      );
      expect(
        await repository.createPeriod('pet', period),
        const Success<void>(null),
      );
      expect(
        await repository.updatePeriod('pet', period),
        const Success<void>(null),
      );
      verify(() => source.createMedication(model)).called(1);
      verify(() => source.createPeriod('pet', periodModel)).called(1);
      verify(() => source.updatePeriod('pet', periodModel)).called(1);
    },
  );

  test('dose reads retain the caller range and map actual times', () async {
    when(
      () => source.getDoseLogs(
        'pet',
        medicationId: 'medicine',
        fromDate: day,
        toDate: day,
      ),
    ).thenAnswer((_) async => [logModel]);
    expect(
      await repository.getDoseLogs(
        'pet',
        medicationId: 'medicine',
        fromDate: day,
        toDate: day,
      ),
      Success<List<MedicationDoseLog>>([log]),
    );
    verify(
      () => source.getDoseLogs(
        'pet',
        medicationId: 'medicine',
        fromDate: day,
        toDate: day,
      ),
    ).called(1);
  });

  test(
    'dose save and clear preserve ownership and the exact natural key',
    () async {
      when(
        () => source.saveDoseLog('pet', 'medicine', logModel),
      ).thenAnswer((_) async {});
      when(
        () => source.clearDoseLog(
          'pet',
          'medicine',
          periodId: 'period',
          scheduledDate: day,
          scheduledMinute: 480,
        ),
      ).thenAnswer((_) async {});
      expect(
        await repository.saveDoseLog('pet', 'medicine', log),
        const Success<void>(null),
      );
      expect(
        await repository.clearDoseLog(
          'pet',
          'medicine',
          periodId: 'period',
          scheduledDate: day,
          scheduledMinute: 480,
        ),
        const Success<void>(null),
      );
      verify(() => source.saveDoseLog('pet', 'medicine', logModel)).called(1);
      verify(
        () => source.clearDoseLog(
          'pet',
          'medicine',
          periodId: 'period',
          scheduledDate: day,
          scheduledMinute: 480,
        ),
      ).called(1);
    },
  );

  test(
    'suggestions preserve clinic scope and empty lists are successful reads',
    () async {
      const suggestions = MedicationSuggestions(
        medicationNames: ['Medicine'],
        clinicNames: ['Clinic'],
        veterinarianNames: ['Dr. Smith'],
      );
      when(
        () => source.getSuggestions(clinicName: 'Clinic'),
      ).thenAnswer((_) async => suggestions);
      when(() => source.getMedications('pet')).thenAnswer((_) async => []);
      expect(
        await repository.getSuggestions(clinicName: 'Clinic'),
        const Success(suggestions),
      );
      expect(
        await repository.getMedications('pet'),
        const Success<List<Medication>>([]),
      );
      verify(() => source.getSuggestions(clinicName: 'Clinic')).called(1);
    },
  );

  final operations =
      <
        String,
        ({
          Future<dynamic> Function() sourceCall,
          Future<dynamic> Function() call,
          String error,
        })
      >{
        'list': (
          sourceCall: () => source.getMedications('pet'),
          call: () => repository.getMedications('pet'),
          error: 'Failed to load medications',
        ),
        'all medications': (
          sourceCall: () => source.getAllMedications(),
          call: () => repository.getAllMedications(),
          error: 'Failed to load medications',
        ),
        'all doses': (
          sourceCall: () => source.getAllDoseLogs(fromDate: day, toDate: day),
          call: () => repository.getAllDoseLogs(fromDate: day, toDate: day),
          error: 'Failed to load dose records',
        ),
        'detail': (
          sourceCall: () => source.getMedicationById('pet', 'medicine'),
          call: () => repository.getMedicationById('pet', 'medicine'),
          error: 'Failed to load medication',
        ),
        'create': (
          sourceCall: () => source.createMedication(model),
          call: () => repository.createMedication(medication),
          error: 'Failed to create medication',
        ),
        'rename': (
          sourceCall: () =>
              source.renameMedication('pet', 'medicine', 'Changed'),
          call: () => repository.renameMedication('pet', 'medicine', 'Changed'),
          error: 'Failed to rename medication',
        ),
        'delete': (
          sourceCall: () => source.deleteMedication('pet', 'medicine'),
          call: () => repository.deleteMedication('pet', 'medicine'),
          error: 'Failed to delete medication',
        ),
        'create period': (
          sourceCall: () => source.createPeriod('pet', periodModel),
          call: () => repository.createPeriod('pet', period),
          error: 'Failed to create medication period',
        ),
        'update period': (
          sourceCall: () => source.updatePeriod('pet', periodModel),
          call: () => repository.updatePeriod('pet', period),
          error: 'Failed to update medication period',
        ),
        'delete period': (
          sourceCall: () => source.deletePeriod('pet', 'medicine', 'period'),
          call: () => repository.deletePeriod('pet', 'medicine', 'period'),
          error: 'Failed to delete medication period',
        ),
        'period lock': (
          sourceCall: () => source.hasDoseLogs('pet', 'medicine', 'period'),
          call: () => repository.hasDoseLogs('pet', 'medicine', 'period'),
          error: 'Failed to check medication period',
        ),
        'read doses': (
          sourceCall: () =>
              source.getDoseLogs('pet', fromDate: day, toDate: day),
          call: () => repository.getDoseLogs('pet', fromDate: day, toDate: day),
          error: 'Failed to load dose records',
        ),
        'save dose': (
          sourceCall: () => source.saveDoseLog('pet', 'medicine', logModel),
          call: () => repository.saveDoseLog('pet', 'medicine', log),
          error: 'Failed to save dose record',
        ),
        'clear dose': (
          sourceCall: () => source.clearDoseLog(
            'pet',
            'medicine',
            periodId: 'period',
            scheduledDate: day,
            scheduledMinute: 480,
          ),
          call: () => repository.clearDoseLog(
            'pet',
            'medicine',
            periodId: 'period',
            scheduledDate: day,
            scheduledMinute: 480,
          ),
          error: 'Failed to clear dose record',
        ),
        'suggestions': (
          sourceCall: () => source.getSuggestions(),
          call: () => repository.getSuggestions(),
          error: 'Failed to load medication suggestions',
        ),
      };
  for (final entry in operations.entries) {
    test(
      '${entry.key} maps storage errors without leaking SQL details',
      () async {
        when(
          entry.value.sourceCall,
        ).thenThrow(const LocalDataSourceException());
        final result = await entry.value.call();
        expect(result, isA<Error>());
        expect(
          (result as Error).failure,
          LocalDatabaseFailure(entry.value.error),
        );
        verify(entry.value.sourceCall).called(1);
      },
    );
    if (![
      'list',
      'all medications',
      'all doses',
      'suggestions',
      'read doses',
    ].contains(entry.key)) {
      test(
        '${entry.key} maps missing or mismatched ownership to not found',
        () async {
          when(
            entry.value.sourceCall,
          ).thenThrow(const LocalDataNotFoundException());
          final result = await entry.value.call();
          expect(result, isA<Error>());
          expect((result as Error).failure, isA<NotFoundFailure>());
        },
      );
    }
  }
}
