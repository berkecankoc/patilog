import 'package:patilog/core/error/exception.dart';
import 'package:patilog/features/pet/data/models/pet_model.dart';
import 'package:patilog/features/weight_history/data/models/weight_entry_model.dart';
import 'package:patilog/core/database/database_tables.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class PetLocalDataSource {
  Future<List<PetModel>> getPets();
  Future<PetModel> getPetById(String id);
  Future<void> createPet(PetModel pet, {WeightEntryModel? weightEntry});
  Future<void> updatePet(PetModel pet, {WeightEntryModel? weightEntry});
  Future<void> deletePet(String id);
}

final class PetLocalDataSourceImpl implements PetLocalDataSource {
  final Database db;
  const PetLocalDataSourceImpl(this.db);

  // Do not read the legacy pets.weight column; history owns the current weight.
  static const _selectPetsWithWeight =
      '''
    SELECT p.id, p.name, p.species, p.sex, p.reproductive_status,
           p.breed, p.birth_date, p.microchip_id, p.image_path,
           (SELECT w.weight FROM ${DatabaseTables.weightEntries} w
            WHERE w.pet_id = p.id
            ORDER BY w.measured_at DESC, w.rowid DESC LIMIT 1) AS weight
    FROM ${DatabaseTables.pets} p
  ''';

  @override
  Future<void> createPet(PetModel pet, {WeightEntryModel? weightEntry}) async {
    try {
      await db.transaction((txn) async {
        await txn.insert(DatabaseTables.pets, pet.toJson());
        if (weightEntry != null) {
          await txn.insert(DatabaseTables.weightEntries, weightEntry.toJson());
        }
      });
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
      final rows = await db.rawQuery(
        '$_selectPetsWithWeight WHERE p.id = ? LIMIT 1',
        [id],
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
      final rows = await db.rawQuery(_selectPetsWithWeight);
      return rows.map(PetModel.fromJson).toList();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> updatePet(PetModel pet, {WeightEntryModel? weightEntry}) async {
    try {
      await db.transaction((txn) async {
        final affectedRows = await txn.update(
          DatabaseTables.pets,
          pet.toJson(),
          where: 'id = ?',
          whereArgs: [pet.id],
        );
        if (affectedRows == 0) throw const LocalDataNotFoundException();
        if (weightEntry != null) {
          await txn.insert(DatabaseTables.weightEntries, weightEntry.toJson());
        }
      });
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }
}
