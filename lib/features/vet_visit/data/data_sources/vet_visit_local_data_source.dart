import 'package:petlytics/core/database/care_name_suggestions.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/vet_visit/data/models/vet_visit_model.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit_suggestions.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class VetVisitLocalDataSource {
  Future<List<VetVisitModel>> getVetVisits(String petId);
  Future<VetVisitModel> getVetVisitById(String petId, String visitId);
  Future<void> createVetVisit(VetVisitModel visit);
  Future<void> updateVetVisit(VetVisitModel visit);
  Future<void> deleteVetVisit(String petId, String visitId);
  Future<VetVisitSuggestions> getSuggestions({String? clinicName});
}

final class VetVisitLocalDataSourceImpl implements VetVisitLocalDataSource {
  final Database db;

  const VetVisitLocalDataSourceImpl(this.db);

  @override
  Future<List<VetVisitModel>> getVetVisits(String petId) async {
    try {
      final rows = await db.query(
        DatabaseTables.vetVisits,
        where: 'pet_id = ?',
        whereArgs: [petId],
        orderBy: 'visited_on DESC, rowid DESC',
      );
      return rows.map(VetVisitModel.fromJson).toList();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<VetVisitModel> getVetVisitById(String petId, String visitId) async {
    try {
      final rows = await db.query(
        DatabaseTables.vetVisits,
        where: 'pet_id = ? AND id = ?',
        whereArgs: [petId, visitId],
        limit: 1,
      );
      if (rows.isEmpty) throw const LocalDataNotFoundException();
      return VetVisitModel.fromJson(rows.single);
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> createVetVisit(VetVisitModel visit) async {
    _validateDate(visit);
    try {
      await db.insert(DatabaseTables.vetVisits, visit.toJson());
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> updateVetVisit(VetVisitModel visit) async {
    _validateDate(visit);
    try {
      await db.transaction((txn) async {
        final rows = await txn.query(
          DatabaseTables.vetVisits,
          columns: ['visited_on'],
          where: 'pet_id = ? AND id = ?',
          whereArgs: [visit.petId, visit.id],
          limit: 1,
        );
        if (rows.isEmpty) throw const LocalDataNotFoundException();
        final values = visit.toJson();
        await txn.update(
          DatabaseTables.vetVisits,
          values,
          where: 'pet_id = ? AND id = ?',
          whereArgs: [visit.petId, visit.id],
        );
        if (rows.single['visited_on'] != values['visited_on']) {
          await txn.update(
            DatabaseTables.vaccinations,
            {'date': values['visited_on']},
            where: 'pet_id = ? AND vet_visit_id = ?',
            whereArgs: [visit.petId, visit.id],
          );
        }
      });
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> deleteVetVisit(String petId, String visitId) async {
    try {
      final affectedRows = await db.delete(
        DatabaseTables.vetVisits,
        where: 'pet_id = ? AND id = ?',
        whereArgs: [petId, visitId],
      );
      if (affectedRows == 0) throw const LocalDataNotFoundException();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  void _validateDate(VetVisitModel visit) {
    final date = visit.visitedOn;
    final now = DateTime.now();
    if (DateTime(
      date.year,
      date.month,
      date.day,
    ).isAfter(DateTime(now.year, now.month, now.day))) {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<VetVisitSuggestions> getSuggestions({String? clinicName}) async {
    try {
      final names = await readCareNameSuggestions(db, clinicName: clinicName);
      return VetVisitSuggestions(
        clinicNames: names.clinicNames,
        veterinarianNames: names.veterinarianNames,
      );
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }
}
