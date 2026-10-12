import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/pet/data/models/pet_model.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class PetLocalDataSource {
  Future<List<PetModel>> getPets();
  Future<PetModel> getPetById(String id);
  Future<void> createPet(PetModel pet);
  Future<void> updatePet(PetModel pet);
  Future<void> deletePet(String id);
}

final class PetLocalDataSourceImpl implements PetLocalDataSource {
  final Database db;
  const PetLocalDataSourceImpl(this.db);

  @override
  Future<void> createPet(PetModel pet) async {
    try {
      await db.insert(DatabaseTables.pets, pet.toJson());
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> deletePet(String id) async {
    try {
      final affectedRows = await db.delete(
        DatabaseTables.pets,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (affectedRows == 0) throw const LocalDataNotFoundException();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<PetModel> getPetById(String id) async {
    try {
      final rows = await db.query(
        DatabaseTables.pets,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) throw const LocalDataNotFoundException();

      return PetModel.fromJson(rows.first);
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<List<PetModel>> getPets() async {
    try {
      final rows = await db.query(DatabaseTables.pets);
      return rows.map(PetModel.fromJson).toList();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> updatePet(PetModel pet) async {
    try {
      final affectedRows = await db.update(
        DatabaseTables.pets,
        pet.toJson(),
        where: 'id = ?',
        whereArgs: [pet.id],
      );

      if (affectedRows == 0) throw const LocalDataNotFoundException();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }
}
