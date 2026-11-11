import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/vet_visit/data/data_sources/vet_visit_local_data_source.dart';
import 'package:patilog/features/vet_visit/data/models/vet_visit_model.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:patilog/features/vet_visit/domain/repositories/vet_visit_repository.dart';

final class VetVisitRepositoryImpl implements VetVisitRepository {
  final VetVisitLocalDataSource localDataSource;

  const VetVisitRepositoryImpl(this.localDataSource);

  @override
  Future<Result<List<VetVisit>>> getAllVetVisits() async {
    try {
      final models = await localDataSource.getAllVetVisits();
      return Success(models.map((model) => model.toEntity()).toList());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load vet visits'));
    }
  }

  @override
  Future<Result<List<VetVisit>>> getVetVisits(String petId) async {
    try {
      final models = await localDataSource.getVetVisits(petId);
      return Success(models.map((model) => model.toEntity()).toList());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load vet visits'));
    }
  }

  @override
  Future<Result<VetVisit>> getVetVisitById(String petId, String visitId) async {
    try {
      final model = await localDataSource.getVetVisitById(petId, visitId);
      return Success(model.toEntity());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load vet visit'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Vet visit not found'));
    }
  }

  @override
  Future<Result<void>> createVetVisit(VetVisit visit) async {
    try {
      await localDataSource.createVetVisit(VetVisitModel.fromEntity(visit));
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to create vet visit'));
    }
  }

  @override
  Future<Result<void>> updateVetVisit(VetVisit visit) async {
    try {
      await localDataSource.updateVetVisit(VetVisitModel.fromEntity(visit));
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to update vet visit'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Vet visit not found'));
    }
  }

  @override
  Future<Result<void>> deleteVetVisit(String petId, String visitId) async {
    try {
      await localDataSource.deleteVetVisit(petId, visitId);
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to delete vet visit'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Vet visit not found'));
    }
  }

  @override
  Future<Result<VetVisitSuggestions>> getSuggestions({
    String? clinicName,
  }) async {
    try {
      final suggestions = await localDataSource.getSuggestions(
        clinicName: clinicName,
      );
      return Success(suggestions);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to load suggestions'));
    }
  }
}
