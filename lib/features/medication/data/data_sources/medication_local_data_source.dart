import 'package:characters/characters.dart';
import 'package:petlytics/core/database/care_name_suggestions.dart';
import 'package:petlytics/core/database/database_tables.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/features/medication/data/models/medication_dose_log_model.dart';
import 'package:petlytics/features/medication/data/models/medication_model.dart';
import 'package:petlytics/features/medication/data/models/medication_model_values.dart';
import 'package:petlytics/features/medication/data/models/medication_period_model.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/entities/medication_suggestions.dart';
import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class MedicationLocalDataSource {
  Future<List<MedicationModel>> getMedications(
    String petId, {
    String? vetVisitId,
  });
  Future<MedicationModel> getMedicationById(String petId, String medicationId);
  Future<void> createMedication(MedicationModel medication);
  Future<void> renameMedication(String petId, String medicationId, String name);
  Future<void> deleteMedication(String petId, String medicationId);
  Future<void> createPeriod(String petId, MedicationPeriodModel period);
  Future<void> updatePeriod(String petId, MedicationPeriodModel period);
  Future<void> deletePeriod(String petId, String medicationId, String periodId);
  Future<List<MedicationDoseLogModel>> getDoseLogs(
    String petId, {
    String? medicationId,
    required DateTime fromDate,
    required DateTime toDate,
  });
  Future<void> saveDoseLog(
    String petId,
    String medicationId,
    MedicationDoseLogModel log,
  );
  Future<void> clearDoseLog(
    String petId,
    String medicationId, {
    required String periodId,
    required DateTime scheduledDate,
    required int scheduledMinute,
  });
  Future<MedicationSuggestions> getSuggestions({String? clinicName});
}

final class MedicationLocalDataSourceImpl implements MedicationLocalDataSource {
  final Database db;
  final DateTime Function() now;

  MedicationLocalDataSourceImpl(this.db, {this.now = DateTime.now});

  Future<T> _transaction<T>(Future<T> Function(Transaction) action) async {
    try {
      return await db.transaction(action);
    } on DatabaseException {
      throw const LocalDataSourceException();
    }
  }

  @override
  Future<List<MedicationModel>> getMedications(
    String petId, {
    String? vetVisitId,
  }) => _transaction(
    (txn) => _readMedications(txn, petId, vetVisitId: vetVisitId),
  );

  @override
  Future<MedicationModel> getMedicationById(
    String petId,
    String medicationId,
  ) => _transaction((txn) async {
    final models = await _readMedications(
      txn,
      petId,
      medicationId: medicationId,
    );
    if (models.isEmpty) throw const LocalDataNotFoundException();
    return models.single;
  });

  Future<List<MedicationModel>> _readMedications(
    DatabaseExecutor txn,
    String petId, {
    String? medicationId,
    String? vetVisitId,
  }) async {
    final where =
        '''m.pet_id = ?
      ${medicationId == null ? '' : 'AND m.id = ?'}
      ${vetVisitId == null ? '' : '''AND EXISTS (
        SELECT 1 FROM ${DatabaseTables.medicationPeriods} linked
        JOIN ${DatabaseTables.vetVisits} v ON v.id = linked.vet_visit_id
        WHERE linked.medication_id = m.id AND v.id = ? AND v.pet_id = m.pet_id
      )'''}''';
    final args = [petId, ?medicationId, ?vetVisitId];
    final medications = await txn.rawQuery('''
      SELECT m.* FROM ${DatabaseTables.medications} m WHERE $where ORDER BY m.rowid DESC
    ''', args);
    if (medications.isEmpty) return [];
    // Read all matching periods in one query, including unlinked successor plans.
    final rows = await txn.rawQuery('''
      SELECT p.* FROM ${DatabaseTables.medicationPeriods} p
      JOIN ${DatabaseTables.medications} m ON m.id = p.medication_id
      WHERE $where ORDER BY p.start_date ASC
    ''', args);
    final periods = <String, List<MedicationPeriodModel>>{};
    for (final row in rows) {
      final period = MedicationPeriodModel.fromJson(row);
      (periods[period.medicationId] ??= []).add(period);
    }
    return [
      for (final row in medications)
        MedicationModel.fromJson(row, periods: periods[row['id']] ?? []),
    ];
  }

  @override
  Future<void> createMedication(MedicationModel medication) =>
      _transaction((txn) async {
        _validateName(medication.name);
        if (medication.periods.length != 1 ||
            medication.periods.single.medicationId != medication.id) {
          throw const LocalDataSourceException();
        }
        final pets = await txn.query(
          DatabaseTables.pets,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [medication.petId],
          limit: 1,
        );
        if (pets.isEmpty) throw const LocalDataNotFoundException();
        await _validatePeriod(txn, medication.petId, medication.periods.single);
        await txn.insert(DatabaseTables.medications, medication.toJson());
        await txn.insert(
          DatabaseTables.medicationPeriods,
          medication.periods.single.toJson(),
        );
      });

  @override
  Future<void> renameMedication(
    String petId,
    String medicationId,
    String name,
  ) => _transaction((txn) async {
    _validateName(name);
    final count = await txn.update(
      DatabaseTables.medications,
      {'name': name.trim()},
      where: 'pet_id = ? AND id = ?',
      whereArgs: [petId, medicationId],
    );
    if (count == 0) throw const LocalDataNotFoundException();
  });

  @override
  Future<void> deleteMedication(String petId, String medicationId) =>
      _transaction((txn) async {
        final count = await txn.delete(
          DatabaseTables.medications,
          where: 'pet_id = ? AND id = ?',
          whereArgs: [petId, medicationId],
        );
        if (count == 0) throw const LocalDataNotFoundException();
      });

  @override
  Future<void> createPeriod(String petId, MedicationPeriodModel period) =>
      _transaction((txn) async {
        final periods = await _ownedPeriods(txn, petId, period.medicationId);
        await _validatePeriod(txn, petId, period);
        if (calendarDayNumber(period.startDate) <= calendarDayNumber(now()) ||
            calendarDayNumber(period.startDate) <=
                calendarDayNumber(periods.first.startDate)) {
          throw const LocalDataSourceException();
        }
        await txn.insert(DatabaseTables.medicationPeriods, period.toJson());
        await _validatePreservedLogs(txn, period.medicationId);
      });

  @override
  Future<void> updatePeriod(String petId, MedicationPeriodModel period) =>
      _transaction((txn) async {
        final periods = await _ownedPeriods(txn, petId, period.medicationId);
        final index = periods.indexWhere((value) => value.id == period.id);
        if (index < 0) throw const LocalDataNotFoundException();
        final previous = periods[index];
        await _validatePeriod(txn, petId, period);
        final changedStart =
            calendarDayNumber(previous.startDate) !=
            calendarDayNumber(period.startDate);
        if ((index > 0 &&
                changedStart &&
                calendarDayNumber(period.startDate) <=
                    calendarDayNumber(now())) ||
            (index > 0 &&
                calendarDayNumber(period.startDate) <=
                    calendarDayNumber(periods.first.startDate)) ||
            (index == 0 &&
                periods.length > 1 &&
                calendarDayNumber(period.startDate) >=
                    calendarDayNumber(periods[1].startDate))) {
          throw const LocalDataSourceException();
        }
        final logs = await txn.query(
          DatabaseTables.medicationDoseLogs,
          columns: ['period_id'],
          where: 'period_id = ?',
          whereArgs: [period.id],
          limit: 1,
        );
        final sameTimes =
            previous.doseTimes.length == period.doseTimes.length &&
            previous.doseTimes.indexed.every(
              (entry) => entry.$2 == period.doseTimes[entry.$1],
            );
        if (logs.isNotEmpty &&
            (changedStart ||
                previous.intervalDays != period.intervalDays ||
                !sameTimes ||
                optionalText(previous.dosageInstructions) !=
                    optionalText(period.dosageInstructions))) {
          throw const LocalDataSourceException();
        }
        await txn.update(
          DatabaseTables.medicationPeriods,
          period.toJson(),
          where: 'id = ? AND medication_id = ?',
          whereArgs: [period.id, period.medicationId],
        );
        await _validatePreservedLogs(txn, period.medicationId);
      });

  @override
  Future<void> deletePeriod(
    String petId,
    String medicationId,
    String periodId,
  ) => _transaction((txn) async {
    final periods = await _ownedPeriods(txn, petId, medicationId);
    final index = periods.indexWhere((period) => period.id == periodId);
    if (index < 0) throw const LocalDataNotFoundException();
    if (periods.length == 1 ||
        calendarDayNumber(periods[index].startDate) <=
            calendarDayNumber(now())) {
      throw const LocalDataSourceException();
    }
    await txn.delete(
      DatabaseTables.medicationPeriods,
      where: 'id = ? AND medication_id = ?',
      whereArgs: [periodId, medicationId],
    );
    await _validatePreservedLogs(txn, medicationId);
  });

  @override
  Future<List<MedicationDoseLogModel>> getDoseLogs(
    String petId, {
    String? medicationId,
    required DateTime fromDate,
    required DateTime toDate,
  }) => _transaction((txn) async {
    if (calendarDayNumber(fromDate) > calendarDayNumber(toDate)) {
      throw const LocalDataSourceException();
    }
    if (medicationId != null) {
      await _requireMedication(txn, petId, medicationId);
    }
    final rows = await txn.rawQuery(
      '''
      SELECT l.* FROM ${DatabaseTables.medicationDoseLogs} l
      JOIN ${DatabaseTables.medicationPeriods} p ON p.id = l.period_id
      JOIN ${DatabaseTables.medications} m ON m.id = p.medication_id
      WHERE m.pet_id = ? ${medicationId == null ? '' : 'AND m.id = ?'}
        AND l.scheduled_date BETWEEN ? AND ?
      ORDER BY l.scheduled_date, l.scheduled_minute, l.period_id
    ''',
      [
        petId,
        ?medicationId,
        calendarDateKey(fromDate),
        calendarDateKey(toDate),
      ],
    );
    return rows.map(MedicationDoseLogModel.fromJson).toList();
  });

  @override
  Future<void> saveDoseLog(
    String petId,
    String medicationId,
    MedicationDoseLogModel log,
  ) => _transaction((txn) async {
    final periods = await _ownedPeriods(txn, petId, medicationId);
    if (!periods.any((period) => period.id == log.periodId)) {
      throw const LocalDataNotFoundException();
    }
    final currentTime = now();
    if (!_isScheduled(periods, log) ||
        calendarDayNumber(log.scheduledDate) > calendarDayNumber(currentTime) ||
        (log.status == MedicationDoseStatus.given
            ? log.givenAt == null || log.givenAt!.isAfter(currentTime)
            : log.givenAt != null)) {
      throw const LocalDataSourceException();
    }
    final values = log.toJson();
    final count = await txn.update(
      DatabaseTables.medicationDoseLogs,
      {'status': values['status'], 'given_at': values['given_at']},
      where: 'period_id = ? AND scheduled_date = ? AND scheduled_minute = ?',
      whereArgs: [log.periodId, values['scheduled_date'], log.scheduledMinute],
    );
    // Update/insert works on older Android SQLite versions without UPSERT.
    if (count == 0) await txn.insert(DatabaseTables.medicationDoseLogs, values);
  });

  @override
  Future<void> clearDoseLog(
    String petId,
    String medicationId, {
    required String periodId,
    required DateTime scheduledDate,
    required int scheduledMinute,
  }) => _transaction((txn) async {
    final periods = await _ownedPeriods(txn, petId, medicationId);
    if (!periods.any((period) => period.id == periodId)) {
      throw const LocalDataNotFoundException();
    }
    final count = await txn.delete(
      DatabaseTables.medicationDoseLogs,
      where: 'period_id = ? AND scheduled_date = ? AND scheduled_minute = ?',
      whereArgs: [periodId, calendarDateKey(scheduledDate), scheduledMinute],
    );
    if (count == 0) throw const LocalDataNotFoundException();
  });

  @override
  Future<MedicationSuggestions> getSuggestions({String? clinicName}) =>
      _transaction((txn) async {
        final rows = await txn.query(
          DatabaseTables.medications,
          columns: ['name'],
          orderBy: 'rowid DESC',
        );
        final names = <String, String>{};
        for (final row in rows) {
          final name = (row['name'] as String).trim().replaceAll(
            RegExp(r'\s+'),
            ' ',
          );
          names.putIfAbsent(name.toLowerCase(), () => name);
        }
        final clinical = await readCareNameSuggestions(
          txn,
          clinicName: clinicName,
        );
        return MedicationSuggestions(
          medicationNames: names.values.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
          clinicNames: clinical.clinicNames,
          veterinarianNames: clinical.veterinarianNames,
        );
      });

  Future<void> _requireMedication(
    DatabaseExecutor txn,
    String petId,
    String medicationId,
  ) async {
    final rows = await txn.query(
      DatabaseTables.medications,
      columns: ['id'],
      where: 'pet_id = ? AND id = ?',
      whereArgs: [petId, medicationId],
      limit: 1,
    );
    if (rows.isEmpty) throw const LocalDataNotFoundException();
  }

  Future<List<MedicationPeriodModel>> _ownedPeriods(
    DatabaseExecutor txn,
    String petId,
    String medicationId,
  ) async {
    await _requireMedication(txn, petId, medicationId);
    return _readPeriods(txn, medicationId);
  }

  Future<List<MedicationPeriodModel>> _readPeriods(
    DatabaseExecutor txn,
    String medicationId,
  ) async => (await txn.query(
    DatabaseTables.medicationPeriods,
    where: 'medication_id = ?',
    whereArgs: [medicationId],
    orderBy: 'start_date',
  )).map(MedicationPeriodModel.fromJson).toList();

  void _validateName(String name) {
    if (name.trim().isEmpty || name.trim().characters.length > 50) {
      throw const LocalDataSourceException();
    }
  }

  Future<void> _validatePeriod(
    DatabaseExecutor txn,
    String petId,
    MedicationPeriodModel period,
  ) async {
    if (period.intervalDays <= 0 ||
        period.doseTimes.isEmpty ||
        period.doseTimes.toSet().length != period.doseTimes.length ||
        period.doseTimes.any((minute) => minute < 0 || minute > 1439) ||
        (period.endDate != null &&
            calendarDayNumber(period.endDate!) <
                calendarDayNumber(period.startDate)) ||
        (optionalText(period.dosageInstructions)?.characters.length ?? 0) >
            100 ||
        (optionalText(period.notes)?.characters.length ?? 0) > 200) {
      throw const LocalDataSourceException();
    }
    if (period.vetVisitId != null) {
      final visits = await txn.query(
        DatabaseTables.vetVisits,
        columns: ['id'],
        where: 'pet_id = ? AND id = ?',
        whereArgs: [petId, period.vetVisitId],
        limit: 1,
      );
      if (visits.isEmpty) throw const LocalDataNotFoundException();
    }
  }

  Future<void> _validatePreservedLogs(
    DatabaseExecutor txn,
    String medicationId,
  ) async {
    final periods = await _readPeriods(txn, medicationId);
    final rows = await txn.rawQuery(
      '''
      SELECT l.* FROM ${DatabaseTables.medicationDoseLogs} l
      JOIN ${DatabaseTables.medicationPeriods} p ON p.id = l.period_id
      WHERE p.medication_id = ?
    ''',
      [medicationId],
    );
    if (rows.any(
      (row) => !_isScheduled(periods, MedicationDoseLogModel.fromJson(row)),
    )) {
      throw const LocalDataSourceException();
    }
  }

  bool _isScheduled(
    List<MedicationPeriodModel> periods,
    MedicationDoseLogModel log,
  ) {
    final index = periods.indexWhere((period) => period.id == log.periodId);
    if (index < 0) return false;
    return periods[index].toEntity().isScheduledDose(
      log.scheduledDate,
      log.scheduledMinute,
      nextPeriodStart: index + 1 < periods.length
          ? periods[index + 1].startDate
          : null,
    );
  }
}
