import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/notification/domain/entities/notification_data.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import '../../../../helpers/notification_test_harness.dart';

void main() {
  late NotificationTestHarness h;
  setUp(() => h = NotificationTestHarness());
  tearDown(() => h.dispose());

  test('disabled categories cause no pet or clinical reads', () async {
    final result = await h.loader(NotificationPreferences(), h.clock);
    expect((result as Success<NotificationData>).data.medications, isEmpty);
    verifyZeroInteractions(h.pets);
    verifyZeroInteractions(h.medications);
    verifyZeroInteractions(h.vaccinations);
  });

  test(
    'loads only enabled categories, with today-only logs in a single bulk read',
    () async {
      h.medicines.add(h.medication());
      final result = await h.loader(
        NotificationPreferences(medicationRemindersEnabled: true),
        h.clock,
      );
      expect(
        (result as Success<NotificationData>).data.medications,
        h.medicines,
      );
      verify(h.pets.getPets).called(1);
      verify(h.medications.getAllMedications).called(1);
      verify(
        () => h.medications.getAllDoseLogs(
          fromDate: DateTime(2030, 1, 1),
          toDate: DateTime(2030, 1, 1),
        ),
      ).called(1);
      verifyZeroInteractions(h.vaccinations);
    },
  );

  test(
    'vaccination-only loading does not read medication schedules or logs',
    () async {
      h.vaccines.add(h.vaccination());
      final result = await h.loader(
        NotificationPreferences(vaccinationRemindersEnabled: true),
        h.clock,
      );
      expect(
        (result as Success<NotificationData>).data.vaccinations,
        h.vaccines,
      );
      verifyZeroInteractions(h.medications);
    },
  );

  for (final source in ['pets', 'medications', 'logs', 'vaccinations']) {
    test(
      '$source read failure is not converted into an empty successful snapshot',
      () async {
        const failure = LocalDatabaseFailure('Read failed');
        switch (source) {
          case 'pets':
            when(h.pets.getPets).thenAnswer((_) async => const Error(failure));
          case 'medications':
            when(
              h.medications.getAllMedications,
            ).thenAnswer((_) async => const Error(failure));
          case 'logs':
            when(
              () => h.medications.getAllDoseLogs(
                fromDate: any(named: 'fromDate'),
                toDate: any(named: 'toDate'),
              ),
            ).thenAnswer((_) async => const Error(failure));
          default:
            when(
              h.vaccinations.getAllVaccinations,
            ).thenAnswer((_) async => const Error(failure));
        }
        expect(
          await h.loader(
            NotificationPreferences(
              medicationRemindersEnabled: true,
              vaccinationRemindersEnabled: true,
            ),
            h.clock,
          ),
          const Error<NotificationData>(failure),
        );
      },
    );
  }
}
