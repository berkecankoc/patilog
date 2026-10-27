import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/vaccination/data/data_sources/vaccination_local_data_source.dart';
import 'package:petlytics/features/vaccination/data/models/vaccination_model.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';

final class VaccinationRepositoryImpl implements VaccinationRepository {
  final VaccinationLocalDataSource localDataSource;

  const VaccinationRepositoryImpl(this.localDataSource);

  @override
  Future<Result<List<Vaccination>>> getAllVaccinations() async {
    try {
      final models = await localDataSource.getAllVaccinations();
      return Success(models.map((model) => model.toEntity()).toList());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load vaccinations'));
    }
  }

  @override
  Future<Result<List<Vaccination>>> getVaccinations(
    String petId, {
    String? vetVisitId,
  }) async {
    try {
      final models = await localDataSource.getVaccinations(
        petId,
        vetVisitId: vetVisitId,
      );
      return Success(models.map((model) => model.toEntity()).toList());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load vaccinations'));
    }
  }

  @override
  Future<Result<Vaccination>> getVaccinationById(
    String petId,
    String vaccinationId,
  ) async {
    try {
      final model = await localDataSource.getVaccinationById(
        petId,
        vaccinationId,
      );
      return Success(model.toEntity());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load vaccination'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Vaccination not found'));
    }
  }

  @override
  Future<Result<void>> createVaccination(
    Vaccination vaccination, {
    Vaccination? nextDose,
  }) async {
    try {
      await localDataSource.createVaccination(
        VaccinationModel.fromEntity(vaccination),
        nextDose: nextDose == null
            ? null
            : VaccinationModel.fromEntity(nextDose),
      );
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to create vaccination'));
    }
  }

  @override
  Future<Result<void>> updateVaccination(
    Vaccination vaccination, {
    Vaccination? nextDose,
  }) async {
    try {
      await localDataSource.updateVaccination(
        VaccinationModel.fromEntity(vaccination),
        nextDose: nextDose == null
            ? null
            : VaccinationModel.fromEntity(nextDose),
      );
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to update vaccination'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Vaccination not found'));
    }
  }

  @override
  Future<Result<void>> deleteVaccination(
    String petId,
    String vaccinationId,
  ) async {
    try {
      await localDataSource.deleteVaccination(petId, vaccinationId);
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to delete vaccination'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Vaccination not found'));
    }
  }

  @override
  Future<Result<VaccinationSuggestions>> getSuggestions({
    String? clinicName,
  }) async {
    try {
      final suggestions = await localDataSource.getSuggestions(
        clinicName: clinicName,
      );
      return Success(suggestions);
    } on LocalDataSourceException {
      return const Error(
        LocalDatabaseFailure('Failed to load vaccination suggestions'),
      );
    }
  }
}
