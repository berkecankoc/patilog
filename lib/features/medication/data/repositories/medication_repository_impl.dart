import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/medication/data/data_sources/medication_local_data_source.dart';
import 'package:patilog/features/medication/data/models/medication_dose_log_model.dart';
import 'package:patilog/features/medication/data/models/medication_model.dart';
import 'package:patilog/features/medication/data/models/medication_period_model.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose_log.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/domain/entities/medication_suggestions.dart';
import 'package:patilog/features/medication/domain/repositories/medication_repository.dart';

final class MedicationRepositoryImpl implements MedicationRepository {
  final MedicationLocalDataSource localDataSource;

  const MedicationRepositoryImpl(this.localDataSource);

  @override
  Future<Result<List<Medication>>> getAllMedications() => _result(
    () async => (await localDataSource.getAllMedications())
        .map((model) => model.toEntity())
        .toList(),
    'Failed to load medications',
  );

  @override
  Future<Result<List<MedicationDoseLog>>> getAllDoseLogs({
    required DateTime fromDate,
    required DateTime toDate,
  }) => _result(
    () async => (await localDataSource.getAllDoseLogs(
      fromDate: fromDate,
      toDate: toDate,
    )).map((model) => model.toEntity()).toList(),
    'Failed to load dose records',
  );

  Future<Result<T>> _result<T>(
    Future<T> Function() action,
    String message,
  ) async {
    try {
      return Success(await action());
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Medication record not found'));
    } on LocalDataSourceException {
      return Error(LocalDatabaseFailure(message));
    }
  }

  @override
  Future<Result<List<Medication>>> getMedications(
    String petId, {
    String? vetVisitId,
  }) => _result(
    () async => (await localDataSource.getMedications(
      petId,
      vetVisitId: vetVisitId,
    )).map((model) => model.toEntity()).toList(),
    'Failed to load medications',
  );

  @override
  Future<Result<Medication>> getMedicationById(
    String petId,
    String medicationId,
  ) => _result(
    () async => (await localDataSource.getMedicationById(
      petId,
      medicationId,
    )).toEntity(),
    'Failed to load medication',
  );

  @override
  Future<Result<void>> createMedication(Medication medication) => _result(
    () => localDataSource.createMedication(
      MedicationModel.fromEntity(medication),
    ),
    'Failed to create medication',
  );

  @override
  Future<Result<void>> renameMedication(
    String petId,
    String medicationId,
    String name,
  ) => _result(
    () => localDataSource.renameMedication(petId, medicationId, name),
    'Failed to rename medication',
  );

  @override
  Future<Result<void>> deleteMedication(String petId, String medicationId) =>
      _result(
        () => localDataSource.deleteMedication(petId, medicationId),
        'Failed to delete medication',
      );

  @override
  Future<Result<void>> createPeriod(
    String petId,
    MedicationPeriod period, {
    String? medicationName,
  }) => _result(
    () => medicationName == null
        ? localDataSource.createPeriod(
            petId,
            MedicationPeriodModel.fromEntity(period),
          )
        : localDataSource.createPeriod(
            petId,
            MedicationPeriodModel.fromEntity(period),
            medicationName: medicationName,
          ),
    'Failed to create medication period',
  );

  @override
  Future<Result<void>> updatePeriod(
    String petId,
    MedicationPeriod period, {
    String? medicationName,
  }) => _result(
    () => medicationName == null
        ? localDataSource.updatePeriod(
            petId,
            MedicationPeriodModel.fromEntity(period),
          )
        : localDataSource.updatePeriod(
            petId,
            MedicationPeriodModel.fromEntity(period),
            medicationName: medicationName,
          ),
    'Failed to update medication period',
  );

  @override
  Future<Result<bool>> hasDoseLogs(
    String petId,
    String medicationId,
    String periodId,
  ) => _result(
    () => localDataSource.hasDoseLogs(petId, medicationId, periodId),
    'Failed to check medication period',
  );

  @override
  Future<Result<void>> deletePeriod(
    String petId,
    String medicationId,
    String periodId,
  ) => _result(
    () => localDataSource.deletePeriod(petId, medicationId, periodId),
    'Failed to delete medication period',
  );

  @override
  Future<Result<List<MedicationDoseLog>>> getDoseLogs(
    String petId, {
    String? medicationId,
    required DateTime fromDate,
    required DateTime toDate,
  }) => _result(
    () async => (await localDataSource.getDoseLogs(
      petId,
      medicationId: medicationId,
      fromDate: fromDate,
      toDate: toDate,
    )).map((model) => model.toEntity()).toList(),
    'Failed to load dose records',
  );

  @override
  Future<Result<void>> saveDoseLog(
    String petId,
    String medicationId,
    MedicationDoseLog log,
  ) => _result(
    () => localDataSource.saveDoseLog(
      petId,
      medicationId,
      MedicationDoseLogModel.fromEntity(log),
    ),
    'Failed to save dose record',
  );

  @override
  Future<Result<void>> clearDoseLog(
    String petId,
    String medicationId, {
    required String periodId,
    required DateTime scheduledDate,
    required int scheduledMinute,
  }) => _result(
    () => localDataSource.clearDoseLog(
      petId,
      medicationId,
      periodId: periodId,
      scheduledDate: scheduledDate,
      scheduledMinute: scheduledMinute,
    ),
    'Failed to clear dose record',
  );

  @override
  Future<Result<MedicationSuggestions>> getSuggestions({String? clinicName}) =>
      _result(
        () => localDataSource.getSuggestions(clinicName: clinicName),
        'Failed to load medication suggestions',
      );
}
