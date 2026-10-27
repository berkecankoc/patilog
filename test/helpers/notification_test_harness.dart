import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/domain/repositories/medication_repository.dart';
import 'package:petlytics/features/notification/domain/entities/notification_data.dart';
import 'package:petlytics/features/notification/domain/entities/notification_permission_status.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/domain/entities/notification_reminder.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/notification/domain/repositories/notification_repository.dart';
import 'package:petlytics/features/notification/domain/use_cases/load_notification_data.dart';
import 'package:petlytics/features/notification/domain/use_cases/plan_notification_reminders.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/repositories/pet_repository.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination_reminder_settings.dart';
import 'package:petlytics/features/vaccination/domain/repositories/vaccination_repository.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockNotificationPets extends Mock implements PetRepository {}

class MockNotificationMedications extends Mock
    implements MedicationRepository {}

class MockNotificationVaccinations extends Mock
    implements VaccinationRepository {}

class NotificationTestHarness {
  final repository = MockNotificationRepository();
  final pets = MockNotificationPets();
  final medications = MockNotificationMedications();
  final vaccinations = MockNotificationVaccinations();
  final taps = StreamController<NotificationTarget>.broadcast();
  DateTime clock = DateTime(2030, 1, 1, 10);
  NotificationPreferences preferences = NotificationPreferences();
  NotificationPermissionStatus permission = const NotificationPermissionStatus(
    canShowNotifications: true,
    canScheduleExactAlarms: true,
    requiresExactAlarmPermission: true,
  );
  final directory = <Pet>[
    const Pet(
      id: 'pet1',
      name: 'Milo',
      species: PetSpecies.cat,
      sex: PetSex.male,
      reproductiveStatus: ReproductiveStatus.intact,
    ),
    const Pet(
      id: 'pet2',
      name: 'Luna',
      species: PetSpecies.dog,
      sex: PetSex.female,
      reproductiveStatus: ReproductiveStatus.intact,
    ),
  ];
  final medicines = <Medication>[];
  final vaccines = <Vaccination>[];
  final logs = <MedicationDoseLog>[];
  final submissions = <List<NotificationReminder>>[];
  final cancellations = <String>[];
  bool failSave = false;
  bool failSync = false;
  bool failCancel = false;
  final _cubits = <NotificationCubit>[];

  NotificationData get data => NotificationData(
    pets: directory,
    medications: medicines,
    vaccinations: vaccines,
    logs: logs,
  );
  LoadNotificationData get loader =>
      LoadNotificationData(pets, medications, vaccinations);

  Medication medication({
    String id = 'med1',
    String petId = 'pet1',
    List<MedicationPeriod>? periods,
    DateTime? start,
    DateTime? end,
    int interval = 1,
    List<int> times = const [720],
    String? dosage,
  }) => Medication(
    id: id,
    petId: petId,
    name: 'Medicine $id',
    periods:
        periods ??
        [
          MedicationPeriod(
            id: 'period-$id',
            medicationId: id,
            startDate: start ?? DateTime(2030, 1, 1),
            endDate: end,
            intervalDays: interval,
            doseTimes: times,
            dosageInstructions: dosage,
          ),
        ],
  );

  Vaccination vaccination({
    String id = 'vax1',
    String petId = 'pet1',
    DateTime? date,
    VaccinationStatus status = VaccinationStatus.planned,
    VaccinationReminderSettings? settings,
  }) => Vaccination(
    id: id,
    petId: petId,
    vaccineName: 'Vaccine $id',
    status: status,
    date: date ?? DateTime(2030, 1, 4),
    reminderSettings: settings,
  );

  NotificationTestHarness() {
    registerFallbackValue(NotificationPreferences());
    registerFallbackValue(DateTime(2030));
    when(() => repository.openedNotifications).thenAnswer((_) => taps.stream);
    when(repository.initialize).thenAnswer((_) async => const Success(null));
    when(
      repository.getPreferences,
    ).thenAnswer((_) async => Success(preferences));
    when(
      repository.getPermissionStatus,
    ).thenAnswer((_) async => Success(permission));
    when(
      repository.requestNotificationPermission,
    ).thenAnswer((_) async => Success(permission));
    when(
      repository.requestExactAlarmPermission,
    ).thenAnswer((_) async => Success(permission));
    when(
      repository.openNotificationSettings,
    ).thenAnswer((_) async => const Success(null));
    when(() => repository.savePreferences(any())).thenAnswer((call) async {
      if (failSave) {
        return const Error(PreferencesStorageFailure('Save failed'));
      }
      preferences = call.positionalArguments.single as NotificationPreferences;
      return const Success(null);
    });
    when(() => repository.synchronizeReminders(any())).thenAnswer((call) async {
      submissions.add(
        List.of(call.positionalArguments.single as List<NotificationReminder>),
      );
      return failSync
          ? const Error(NotificationFailure('Sync failed'))
          : const Success(null);
    });
    Future<Result<void>> cancel(String key) async {
      cancellations.add(key);
      return failCancel
          ? const Error<void>(NotificationFailure('Cancel failed'))
          : const Success<void>(null);
    }

    when(
      () => repository.cancelPetReminders(any()),
    ).thenAnswer((call) => cancel('pet:${call.positionalArguments[0]}'));
    when(
      () => repository.cancelMedicationReminders(any(), any()),
    ).thenAnswer((call) => cancel('med:${call.positionalArguments.join(':')}'));
    when(
      () => repository.cancelVaccinationReminders(any(), any()),
    ).thenAnswer((call) => cancel('vax:${call.positionalArguments.join(':')}'));
    when(pets.getPets).thenAnswer((_) async => Success(List.of(directory)));
    when(
      medications.getAllMedications,
    ).thenAnswer((_) async => Success(List.of(medicines)));
    when(
      () => medications.getAllDoseLogs(
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'),
      ),
    ).thenAnswer((_) async => Success(List.of(logs)));
    when(
      vaccinations.getAllVaccinations,
    ).thenAnswer((_) async => Success(List.of(vaccines)));
  }

  NotificationCubit createCubit() {
    final cubit = NotificationCubit(
      repository,
      loader,
      const PlanNotificationReminders(),
      now: () => clock,
    );
    _cubits.add(cubit);
    return cubit;
  }

  Future<void> dispose() async {
    for (final cubit in _cubits) {
      if (!cubit.isClosed) await cubit.close();
    }
    await taps.close();
  }
}
