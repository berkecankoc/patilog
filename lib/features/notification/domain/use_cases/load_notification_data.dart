import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/notification/domain/entities/notification_data.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';

final class LoadNotificationData {
  final PetRepository pets;
  final MedicationRepository medications;
  final VaccinationRepository vaccinations;

  const LoadNotificationData(this.pets, this.medications, this.vaccinations);

  Future<Result<NotificationData>> call(
    NotificationPreferences preferences,
    DateTime now,
  ) async {
    if (!preferences.medicationRemindersEnabled &&
        !preferences.vaccinationRemindersEnabled) {
      return Success(NotificationData());
    }
    final today = DateTime(now.year, now.month, now.day);
    final petRead = pets.getPets();
    final medicationRead = preferences.medicationRemindersEnabled
        ? medications.getAllMedications()
        : Future.value(const Success<List<Medication>>([]));
    // Future days cannot have results; only today's future doses can already be recorded.
    final logRead = preferences.medicationRemindersEnabled
        ? medications.getAllDoseLogs(fromDate: today, toDate: today)
        : Future.value(const Success<List<MedicationDoseLog>>([]));
    final vaccinationRead = preferences.vaccinationRemindersEnabled
        ? vaccinations.getAllVaccinations()
        : Future.value(const Success<List<Vaccination>>([]));
    final (petResult, medicationResult, logResult, vaccinationResult) = (
      await petRead,
      await medicationRead,
      await logRead,
      await vaccinationRead,
    );
    if (petResult is Error<List<Pet>>) return Error(petResult.failure);
    if (medicationResult is Error<List<Medication>>) {
      return Error(medicationResult.failure);
    }
    if (logResult is Error<List<MedicationDoseLog>>) {
      return Error(logResult.failure);
    }
    if (vaccinationResult is Error<List<Vaccination>>) {
      return Error(vaccinationResult.failure);
    }
    return Success(
      NotificationData(
        pets: (petResult as Success<List<Pet>>).data,
        medications: (medicationResult as Success<List<Medication>>).data,
        logs: (logResult as Success<List<MedicationDoseLog>>).data,
        vaccinations: (vaccinationResult as Success<List<Vaccination>>).data,
      ),
    );
  }
}
