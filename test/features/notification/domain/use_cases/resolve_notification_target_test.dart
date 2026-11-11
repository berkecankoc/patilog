import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/result/result.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';
import 'package:patilog/features/notification/domain/use_cases/resolve_notification_target.dart';
import '../../../../helpers/notification_test_harness.dart';

void main() {
  late NotificationTestHarness h;
  late ResolveNotificationTarget resolve;
  final meal = FeedingMealNotificationTarget(
    petId: 'pet1',
    planId: 'feed1',
    mealId: 'feed1-720',
    scheduledDate: DateTime(2030, 1, 2),
    scheduledMinute: 720,
  );
  const vaccine = VaccinationNotificationTarget(
    petId: 'pet1',
    vaccinationId: 'vax1',
    daysBefore: 0,
  );
  final dose = MedicationDoseNotificationTarget(
    petId: 'pet1',
    medicationId: 'med1',
    periodId: 'period-med1',
    scheduledDate: DateTime(2030, 1, 2),
    scheduledMinute: 720,
  );
  setUp(() {
    h = NotificationTestHarness();
    resolve = ResolveNotificationTarget(
      h.pets,
      h.medications,
      h.vaccinations,
      h.feeding,
    );
    when(
      () => h.pets.getPetById('pet1'),
    ).thenAnswer((_) async => Success(h.directory.first));
    when(
      () => h.vaccinations.getVaccinationById('pet1', 'vax1'),
    ).thenAnswer((_) async => Success(h.vaccination()));
    when(
      () => h.medications.getMedicationById('pet1', 'med1'),
    ).thenAnswer((_) async => Success(h.medication()));
  });

  test(
    'feeding validates the pet, exact meal and effective plan on the requested day',
    () async {
      h.feedingPlans.add(h.feedingPlan());
      expect(await resolve(meal), isA<Success<Pet>>());
      h.feedingPlans.add(h.feedingPlan(id: 'new', start: DateTime(2030, 1, 2)));
      expect(await resolve(meal), isA<Error<Pet>>());
      h.feedingPlans.clear();
      expect(await resolve(meal), isA<Error<Pet>>());
      verifyZeroInteractions(h.medications);
      verifyZeroInteractions(h.vaccinations);
    },
  );

  test(
    'feeding rejects another pet plan even if a repository returns it',
    () async {
      when(
        () => h.feeding.getFeedingPlans('pet1'),
      ).thenAnswer((_) async => Success([h.feedingPlan(petId: 'pet2')]));
      expect(await resolve(meal), isA<Error<Pet>>());
    },
  );
  tearDown(() => h.dispose());

  for (final target in [vaccine, dose]) {
    test(
      'resolves $target with canonical owner name and scoped reads',
      () async {
        final result = await resolve(target) as Success<Pet>;
        expect(result.data.id, target.petId);
        expect(result.data.name, 'Milo');
        verify(() => h.pets.getPetById('pet1')).called(1);
        verifyNever(h.pets.getPets);
      },
    );
  }
  test('missing pet propagates failure without querying its records', () async {
    when(
      () => h.pets.getPetById('pet1'),
    ).thenAnswer((_) async => const Error(NotFoundFailure('Missing pet')));
    expect(
      await resolve(vaccine),
      const Error<Pet>(NotFoundFailure('Missing pet')),
    );
    verifyZeroInteractions(h.vaccinations);
  });
  test(
    'storage failures remain retryable rather than becoming not found',
    () async {
      when(() => h.vaccinations.getVaccinationById('pet1', 'vax1')).thenAnswer(
        (_) async => const Error(LocalDatabaseFailure('Read failed')),
      );
      expect(
        await resolve(vaccine),
        const Error<Pet>(LocalDatabaseFailure('Read failed')),
      );
    },
  );
  test(
    'wrong owner or record IDs are rejected even if a repository returns them',
    () async {
      when(
        () => h.pets.getPetById('pet1'),
      ).thenAnswer((_) async => Success(h.directory.last));
      expect(await resolve(vaccine), isA<Error<Pet>>());
      verifyZeroInteractions(h.vaccinations);
      when(
        () => h.pets.getPetById('pet1'),
      ).thenAnswer((_) async => Success(h.directory.first));
      when(
        () => h.vaccinations.getVaccinationById('pet1', 'vax1'),
      ).thenAnswer((_) async => Success(h.vaccination(petId: 'pet2')));
      expect(await resolve(vaccine), isA<Error<Pet>>());
      when(
        () => h.medications.getMedicationById('pet1', 'med1'),
      ).thenAnswer((_) async => Success(h.medication(id: 'other')));
      expect(await resolve(dose), isA<Error<Pet>>());
    },
  );
  test(
    'obsolete or replaced dose schedules do not open a different dose',
    () async {
      for (final medication in [
        h.medication(times: [540]),
        h.medication(interval: 2),
        h.medication(end: DateTime(2030, 1, 1)),
        h.medication(
          periods: [
            MedicationPeriod(
              id: 'replacement',
              medicationId: 'med1',
              startDate: DateTime(2030, 1, 1),
              intervalDays: 1,
              doseTimes: [720],
            ),
          ],
        ),
        h.medication(
          periods: [
            h.medication().periods.single,
            MedicationPeriod(
              id: 'later',
              medicationId: 'med1',
              startDate: DateTime(2030, 1, 2),
              intervalDays: 1,
              doseTimes: [720],
            ),
          ],
        ),
      ]) {
        when(
          () => h.medications.getMedicationById('pet1', 'med1'),
        ).thenAnswer((_) async => Success(medication));
        expect(await resolve(dose), isA<Error<Pet>>());
      }
    },
  );
}
