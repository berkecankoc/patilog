import 'package:patilog/core/database/database_tables.dart';
import 'package:patilog/core/error/exception.dart';
import 'package:patilog/features/weight_history/data/models/weight_entry_model.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class WeightHistoryLocalDataSource {
  Future<List<WeightEntryModel>> getWeightEntries(String petId);
  Future<List<WeightEntryModel>> getAllWeightEntries();
  Future<void> createWeightEntry(WeightEntryModel entry);
  Future<void> updateWeightEntry(WeightEntryModel entry);
  Future<void> deleteWeightEntry(String id);
}

final class WeightHistoryLocalDataSourceImpl
    implements WeightHistoryLocalDataSource {
  final Database db;
  const WeightHistoryLocalDataSourceImpl(this.db);

  @override
  Future<List<WeightEntryModel>> getWeightEntries(String petId) =>
      _readEntries(petId: petId);

  @override
  Future<List<WeightEntryModel>> getAllWeightEntries() => _readEntries();

  Future<List<WeightEntryModel>> _readEntries({String? petId}) async {
    try {
      final rows = await db.query(
        DatabaseTables.weightEntries,
        where: petId == null ? null : 'pet_id = ?',
        whereArgs: petId == null ? null : [petId],
        // For equal measurement times, prefer the most recently added row.
        orderBy: 'measured_at DESC, rowid DESC',
      );
      return rows.map(WeightEntryModel.fromJson).toList();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> createWeightEntry(WeightEntryModel entry) async {
    try {
      await db.insert(DatabaseTables.weightEntries, entry.toJson());
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> updateWeightEntry(WeightEntryModel entry) async {
    try {
      final affectedRows = await db.update(
        DatabaseTables.weightEntries,
        entry.toJson(),
        where: 'id = ? AND pet_id = ?',
        whereArgs: [entry.id, entry.petId],
      );
      if (affectedRows == 0) throw const LocalDataNotFoundException();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> deleteWeightEntry(String id) async {
    try {
      final affectedRows = await db.delete(
        DatabaseTables.weightEntries,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (affectedRows == 0) throw const LocalDataNotFoundException();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }
}
