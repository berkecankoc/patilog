import 'package:patilog/core/database/database_tables.dart';
import 'package:sqflite/sqflite.dart';

Future<({List<String> clinicNames, List<String> veterinarianNames})>
readCareNameSuggestions(DatabaseExecutor db, {String? clinicName}) async {
  final rows = await db.rawQuery('''
    SELECT clinic_name, veterinarian_name FROM (
      SELECT clinic_name, veterinarian_name, 0 AS source, rowid AS position
      FROM ${DatabaseTables.vaccinations}
      UNION ALL
      SELECT clinic_name, veterinarian_name, 1 AS source, rowid AS position
      FROM ${DatabaseTables.vetVisits}
      UNION ALL
      SELECT clinic_name, veterinarian_name, 2 AS source, rowid AS position
      FROM ${DatabaseTables.medicationPeriods}
    ) ORDER BY source, position DESC
  ''');
  String clean(String? value) =>
      (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  final selectedClinic = clean(clinicName).toLowerCase();
  final clinics = <String, String>{};
  final veterinarians = <String, String>{};
  // Care forms share spelling priority without a separate name catalog.
  for (final row in rows) {
    final clinic = clean(row['clinic_name'] as String?);
    final veterinarian = clean(row['veterinarian_name'] as String?);
    final clinicKey = clinic.toLowerCase();
    if (clinic.isNotEmpty) clinics.putIfAbsent(clinicKey, () => clinic);
    if (veterinarian.isNotEmpty &&
        (selectedClinic.isEmpty || selectedClinic == clinicKey)) {
      veterinarians.putIfAbsent(veterinarian.toLowerCase(), () => veterinarian);
    }
  }
  int compareNames(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());
  return (
    clinicNames: clinics.values.toList()..sort(compareNames),
    veterinarianNames: veterinarians.values.toList()..sort(compareNames),
  );
}
