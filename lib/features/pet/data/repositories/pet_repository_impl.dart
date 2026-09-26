import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/pet/data/data_sources/pet_local_data_source.dart';
import 'package:petlytics/features/pet/data/models/pet_model.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';

final class PetRepositoryImpl implements PetRepository {
  final PetLocalDataSource localDataSource;
  const PetRepositoryImpl(this.localDataSource);

  @override
  Future<Result<void>> createPet(Pet pet) async {
    try {
      await localDataSource.createPet(PetModel.fromEntity(pet));
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
  Future<Result<void>> updatePet(Pet pet) async {
    try {
      await localDataSource.updatePet(PetModel.fromEntity(pet));
      return const Success(null);
    } on LocalDataSourceException {
      return const Error(LocalDatabaseFailure('Failed to update pet'));
    } on LocalDataNotFoundException {
      return const Error(NotFoundFailure('Pet not found'));
    }
  }
}
