import 'package:patilog/core/result/result.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/domain/repositories/medication_repository.dart';

final class CreateMedicationParams {
  final String petId;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final int intervalDays;
  final List<int> doseTimes;
  final String? dosageInstructions;
  final String? vetVisitId;
  final String? clinicName;
  final String? veterinarianName;
  final String? notes;

  const CreateMedicationParams({
    required this.petId,
    required this.name,
    required this.startDate,
    this.endDate,
    required this.intervalDays,
    required this.doseTimes,
    this.dosageInstructions,
    this.vetVisitId,
    this.clinicName,
    this.veterinarianName,
    this.notes,
  });
}

final class CreateMedication {
  final MedicationRepository repository;
  final IdGenerator idGenerator;

  const CreateMedication(this.repository, this.idGenerator);

  Future<Result<void>> call(CreateMedicationParams params) {
    final medicationId = idGenerator.generate();
    final period = MedicationPeriod(
      id: idGenerator.generate(),
      medicationId: medicationId,
      startDate: params.startDate,
      endDate: params.endDate,
      intervalDays: params.intervalDays,
      doseTimes: params.doseTimes,
      dosageInstructions: params.dosageInstructions,
      vetVisitId: params.vetVisitId,
      clinicName: params.clinicName,
      veterinarianName: params.veterinarianName,
      notes: params.notes,
    );
    return repository.createMedication(
      Medication(
        id: medicationId,
        petId: params.petId,
        name: params.name,
        periods: [period],
      ),
    );
  }
}
