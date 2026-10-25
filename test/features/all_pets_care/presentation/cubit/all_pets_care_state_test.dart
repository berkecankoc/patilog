import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';

void main() {
  final today = DateTime(2026, 10, 20, 10);
  Vaccination vaccination(
    String id,
    int day,
    VaccinationStatus status, {
    String petId = 'a',
  }) => Vaccination(
    id: id,
    petId: petId,
    vaccineName: 'Rabies',
    status: status,
    date: DateTime(2026, 10, day),
  );

  test(
    'groups planned dates by calendar day, keeping administered history separate',
    () {
      final late = vaccination('late', 19, VaccinationStatus.planned);
      final due = vaccination('today', 20, VaccinationStatus.planned);
      final next = vaccination('next', 21, VaccinationStatus.planned);
      final done = vaccination('done', 19, VaccinationStatus.administered);
      final state = AllPetsCareState(
        currentTime: today,
        vaccinations: CareRecords(
          records: [late, due, next, done],
          hasLoaded: true,
        ),
      );
      expect(state.overdueVaccinations, [late]);
      expect(state.todayVaccinations, [due]);
      expect(state.upcomingVaccinations, [next]);
      expect(state.administeredVaccinations, [done]);
      final nextDay = state.copyWith(currentTime: DateTime(2026, 10, 21));
      expect(nextDay.overdueVaccinations, [late, due]);
      expect(nextDay.todayVaccinations, [next]);
    },
  );
  test('snapshots and filter maps own immutable copies', () {
    final source = [vaccination('a', 20, VaccinationStatus.planned)];
    final filters = {AllPetsCareSection.vaccinations: 'a'};
    final state = AllPetsCareState(
      currentTime: today,
      vaccinations: CareRecords(records: source),
      petFilters: filters,
    );
    source.clear();
    filters.clear();
    expect(state.vaccinations.records, hasLength(1));
    expect(state.petFilters[AllPetsCareSection.vaccinations], 'a');
    expect(() => state.vaccinations.records.clear(), throwsUnsupportedError);
    expect(() => state.petFilters.clear(), throwsUnsupportedError);
  });
  test('copying independent load errors retains other data', () {
    final records = CareRecords(
      records: [vaccination('a', 20, VaccinationStatus.planned)],
      hasLoaded: true,
    );
    final state = AllPetsCareState(currentTime: today, vaccinations: records);
    final failed = state.copyWith(
      vaccinations: records.copyWith(error: 'Try again'),
    );
    expect(failed.vaccinations.records, records.records);
    expect(failed.vaccinations.hasLoaded, isTrue);
    expect(failed.vaccinations.copyWith(clearError: true).error, isNull);
    expect(failed.pets, state.pets);
  });
}
