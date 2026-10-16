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
    try {
      await db.insert(DatabaseTables.vetVisits, visit.toJson());
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> updateVetVisit(VetVisitModel visit) async {
    try {
      final affectedRows = await db.update(
        DatabaseTables.vetVisits,
        visit.toJson(),
        where: 'pet_id = ? AND id = ?',
        whereArgs: [visit.petId, visit.id],
      );
      if (affectedRows == 0) throw const LocalDataNotFoundException();
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

  @override
  Future<VetVisitSuggestions> getSuggestions({String? clinicName}) async {
    try {
      final rows = await db.query(
        DatabaseTables.vetVisits,
        columns: ['clinic_name', 'veterinarian_name'],
        orderBy: 'rowid DESC',
      );
      final clinics = <String, String>{};
      final veterinarians = <String, String>{};
      final selectedClinic = clinicName?.trim().toLowerCase() ?? '';
      for (final row in rows) {
        final clinic = (row['clinic_name'] as String?)?.trim() ?? '';
        final veterinarian =
            (row['veterinarian_name'] as String?)?.trim() ?? '';
        final clinicKey = clinic.toLowerCase();
        if (clinic.isNotEmpty) clinics.putIfAbsent(clinicKey, () => clinic);
        if (veterinarian.isNotEmpty &&
            (selectedClinic.isEmpty || selectedClinic == clinicKey)) {
          veterinarians.putIfAbsent(
            veterinarian.toLowerCase(),
            () => veterinarian,
          );
        }
      }
      int compareNames(String a, String b) =>
          a.toLowerCase().compareTo(b.toLowerCase());
      return VetVisitSuggestions(
        clinicNames: clinics.values.toList()..sort(compareNames),
        veterinarianNames: veterinarians.values.toList()..sort(compareNames),
      );
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }
}
