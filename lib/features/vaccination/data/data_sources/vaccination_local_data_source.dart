import 'package:petlytics/core/database/care_name_suggestions.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/vaccination/data/models/vaccination_model.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_suggestions.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class VaccinationLocalDataSource {
  Future<List<VaccinationModel>> getVaccinations(String petId);
  Future<VaccinationModel> getVaccinationById(
    String petId,
    String vaccinationId,
  );
  Future<void> createVaccination(
    VaccinationModel vaccination, {
    VaccinationModel? nextDose,
  });
  Future<void> updateVaccination(
    VaccinationModel vaccination, {
    VaccinationModel? nextDose,
  });
  Future<void> deleteVaccination(String petId, String vaccinationId);
  Future<VaccinationSuggestions> getSuggestions({String? clinicName});
}

final class VaccinationLocalDataSourceImpl
    implements VaccinationLocalDataSource {
  final Database db;

  const VaccinationLocalDataSourceImpl(this.db);

  @override
  Future<List<VaccinationModel>> getVaccinations(String petId) async {
    try {
      final rows = await db.query(
        DatabaseTables.vaccinations,
        where: 'pet_id = ?',
        whereArgs: [petId],
        orderBy: '''
          CASE WHEN status = 'planned' THEN 0 ELSE 1 END,
          CASE WHEN status = 'planned' THEN date END ASC,
          CASE WHEN status = 'administered' THEN date END DESC,
          rowid DESC
        ''',
      );
      return rows.map(VaccinationModel.fromJson).toList();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<VaccinationModel> getVaccinationById(
    String petId,
    String vaccinationId,
  ) async {
    try {
      final rows = await db.query(
        DatabaseTables.vaccinations,
        where: 'pet_id = ? AND id = ?',
        whereArgs: [petId, vaccinationId],
        limit: 1,
      );
      if (rows.isEmpty) throw const LocalDataNotFoundException();
      return VaccinationModel.fromJson(rows.single);
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> createVaccination(
    VaccinationModel vaccination, {
    VaccinationModel? nextDose,
  }) async {
    try {
      await db.transaction((txn) async {
        await _validateVaccination(txn, vaccination);
        if (nextDose != null) {
          _validateNextDose(vaccination, nextDose);
          await _validateVaccination(txn, nextDose);
        }
        await txn.insert(DatabaseTables.vaccinations, vaccination.toJson());
        if (nextDose != null) {
          await txn.insert(DatabaseTables.vaccinations, nextDose.toJson());
        }
      });
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> updateVaccination(
    VaccinationModel vaccination, {
    VaccinationModel? nextDose,
  }) async {
    try {
      await db.transaction((txn) async {
        final rows = await txn.query(
          DatabaseTables.vaccinations,
          columns: ['status'],
          where: 'pet_id = ? AND id = ?',
          whereArgs: [vaccination.petId, vaccination.id],
          limit: 1,
        );
        if (rows.isEmpty) throw const LocalDataNotFoundException();
        await _validateVaccination(txn, vaccination);
        if (nextDose != null) {
          if (rows.single['status'] != VaccinationStatus.planned.name) {
            throw const LocalDataSourceException();
          }
          _validateNextDose(vaccination, nextDose);
          await _validateVaccination(txn, nextDose);
        }
        await txn.update(
          DatabaseTables.vaccinations,
          vaccination.toJson(),
          where: 'pet_id = ? AND id = ?',
          whereArgs: [vaccination.petId, vaccination.id],
        );
        if (nextDose != null) {
          await txn.insert(DatabaseTables.vaccinations, nextDose.toJson());
        }
      });
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<void> deleteVaccination(String petId, String vaccinationId) async {
    try {
      final affectedRows = await db.delete(
        DatabaseTables.vaccinations,
        where: 'pet_id = ? AND id = ?',
        whereArgs: [petId, vaccinationId],
      );
      if (affectedRows == 0) throw const LocalDataNotFoundException();
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<VaccinationSuggestions> getSuggestions({String? clinicName}) async {
    try {
      final vaccinationRows = await db.query(
        DatabaseTables.vaccinations,
        columns: ['vaccine_name'],
        orderBy: 'rowid DESC',
      );
      final names = await readCareNameSuggestions(db, clinicName: clinicName);
      final vaccines = <String, String>{};
      for (final row in vaccinationRows) {
        final vaccine = (row['vaccine_name'] as String?)?.trim() ?? '';
        if (vaccine.isNotEmpty) {
          vaccines.putIfAbsent(vaccine.toLowerCase(), () => vaccine);
        }
      }
      int compareNames(String a, String b) =>
          a.toLowerCase().compareTo(b.toLowerCase());
      return VaccinationSuggestions(
        vaccineNames: vaccines.values.toList()..sort(compareNames),
        clinicNames: names.clinicNames,
        veterinarianNames: names.veterinarianNames,
      );
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  Future<void> _validateVaccination(
    DatabaseExecutor txn,
    VaccinationModel vaccination,
  ) async {
    final date = _calendarDate(vaccination.date);
    final today = _calendarDate(DateTime.now());
    if ((vaccination.status == VaccinationStatus.administered &&
            date.isAfter(today)) ||
        (vaccination.status == VaccinationStatus.planned &&
            date.isBefore(today))) {
      throw const LocalDataSourceException();
    }
    final visitId = vaccination.vetVisitId;
    if (visitId == null) return;
    if (vaccination.status != VaccinationStatus.administered) {
      throw const LocalDataSourceException();
    }
    // Check ownership inside the write transaction; the FK alone checks only ID.
    final visits = await txn.query(
      DatabaseTables.vetVisits,
      columns: ['id'],
      where: 'pet_id = ? AND id = ?',
      whereArgs: [vaccination.petId, visitId],
      limit: 1,
    );
    if (visits.isEmpty) throw const LocalDataSourceException();
  }

  void _validateNextDose(
    VaccinationModel vaccination,
    VaccinationModel nextDose,
  ) {
    final date = _calendarDate(vaccination.date);
    final nextDate = _calendarDate(nextDose.date);
    if (vaccination.status != VaccinationStatus.administered ||
        nextDose.status != VaccinationStatus.planned ||
        nextDose.id == vaccination.id ||
        nextDose.petId != vaccination.petId ||
        nextDose.vaccineName.trim().toLowerCase() !=
            vaccination.vaccineName.trim().toLowerCase() ||
        !nextDate.isAfter(date)) {
      throw const LocalDataSourceException();
    }
  }

  static DateTime _calendarDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
