import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_plan.dart';
import 'package:petlytics/features/feeding/domain/use_cases/calculate_feeding_meals.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';

final class ResolveNotificationTarget {
  final PetRepository pets;
  final MedicationRepository medications;
  final VaccinationRepository vaccinations;
  final FeedingRepository feeding;
  const ResolveNotificationTarget(
    this.pets,
    this.medications,
    this.vaccinations,
    this.feeding,
  );

  Future<Result<Pet>> call(NotificationTarget target) async {
    const missing = Error<Pet>(
      NotFoundFailure('This reminder’s record is no longer available.'),
    );
    final owner = await pets.getPetById(target.petId);
    if (owner case Error<Pet>()) return Error(owner.failure);
    final pet = (owner as Success<Pet>).data;
    if (pet.id != target.petId) return missing;
    switch (target) {
      case FeedingMealNotificationTarget():
        final result = await feeding.getFeedingPlans(target.petId);
        if (result case Error<List<FeedingPlan>>()) {
          return Error(result.failure);
        }
        final meals = const CalculateFeedingMeals()(
          plans: (result as Success<List<FeedingPlan>>).data,
          entries: const [],
          fromDate: target.scheduledDate,
          toDate: target.scheduledDate,
        );
        if (!meals.any(
          (m) =>
              m.plan.petId == pet.id &&
              m.plan.id == target.planId &&
              m.meal.id == target.mealId &&
              m.meal.scheduledMinute == target.scheduledMinute,
        )) {
          return missing;
        }
      case VaccinationNotificationTarget():
        final result = await vaccinations.getVaccinationById(
          target.petId,
          target.vaccinationId,
        );
        if (result case Error<Vaccination>()) return Error(result.failure);
        final record = (result as Success<Vaccination>).data;
        if (record.petId != pet.id || record.id != target.vaccinationId) {
          return missing;
        }
      case MedicationDoseNotificationTarget():
        final result = await medications.getMedicationById(
          target.petId,
          target.medicationId,
        );
        if (result case Error<Medication>()) return Error(result.failure);
        final record = (result as Success<Medication>).data;
        if (record.petId != pet.id || record.id != target.medicationId) {
          return missing;
        }
        final index = record.periods.indexWhere(
          (period) => period.id == target.periodId,
        );
        if (index < 0) {
          return const Error(
            NotFoundFailure('This dose is no longer scheduled.'),
          );
        }
        final period = record.periods[index];
        if (period.medicationId != record.id ||
            !period.isScheduledDose(
              target.scheduledDate,
              target.scheduledMinute,
              nextPeriodStart: index + 1 < record.periods.length
                  ? record.periods[index + 1].startDate
                  : null,
            )) {
          return const Error(
            NotFoundFailure('This dose is no longer scheduled.'),
          );
        }
    }
    return Success(pet);
  }
}
