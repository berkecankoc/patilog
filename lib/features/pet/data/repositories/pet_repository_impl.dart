import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/pet/data/data_sources/pet_local_data_source.dart';
import 'package:patilog/features/pet/data/models/pet_model.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/repositories/pet_repository.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/data/models/weight_entry_model.dart';

final class PetRepositoryImpl implements PetRepository {
  final PetLocalDataSource localDataSource;
  const PetRepositoryImpl(this.localDataSource);

  @override
  Future<Result<void>> createPet(Pet pet, {WeightEntry? weightEntry}) async {
    try {
      await localDataSource.createPet(
        PetModel.fromEntity(pet),
        weightEntry: weightEntry == null
            ? null
            : WeightEntryModel.fromEntity(weightEntry),
      );
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to create pet'));
    }
  }

  @override
  Future<Result<void>> deletePet(String id) async {
    try {
      await localDataSource.deletePet(id);
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to delete pet'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Pet not found'));
    }
  }

  @override
  Future<Result<Pet>> getPetById(String id) async {
    try {
      final model = await localDataSource.getPetById(id);
      return Success(model.toEntity());
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to get pet'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Pet not found'));
    }
  }

  @override
  Future<Result<List<Pet>>> getPets() async {
    try {
      final models = await localDataSource.getPets();
      final pets = models.map((model) => model.toEntity()).toList();
      return Success(pets);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to get pets'));
    }
  }

  @override
  Future<Result<void>> updatePet(Pet pet, {WeightEntry? weightEntry}) async {
    try {
      await localDataSource.updatePet(
        PetModel.fromEntity(pet),
        weightEntry: weightEntry == null
            ? null
            : WeightEntryModel.fromEntity(weightEntry),
      );
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to update pet'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Pet not found'));
    }
  }
}
