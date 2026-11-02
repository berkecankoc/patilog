import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/notification/data/codecs/notification_target_codec.dart';
import 'package:petlytics/features/notification/data/data_sources/notification_local_data_source.dart';
import 'package:petlytics/features/notification/data/data_sources/notification_preferences_local_data_source.dart';
import 'package:petlytics/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:petlytics/features/notification/domain/entities/notification_permission_status.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/domain/entities/notification_reminder.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/notification/presentation/utils/notification_content.dart';
import 'package:petlytics/core/l10n/app_locale.dart';
import 'package:petlytics/l10n/generated/app_localizations_tr.dart';
import '../../../../helpers/notification_test_harness.dart'
    show englishNotificationContent;

class MockNotifications extends Mock implements NotificationLocalDataSource {}

class MockPreferences extends Mock
    implements NotificationPreferencesLocalDataSource {}

void main() {
  late MockNotifications notifications;
  late MockPreferences preferences;
  late NotificationRepositoryImpl repository;
  late List<PendingNotificationRequest> pending;
  late List<(int, NotificationReminder, bool)> scheduled;
  final current = DateTime(2030, 1, 1, 10);
  const allowed = NotificationPermissionStatus(
    canShowNotifications: true,
    canScheduleExactAlarms: true,
    requiresExactAlarmPermission: true,
  );
  NotificationReminder vaccine({
    String pet = 'pet1',
    String id = 'vax1',
    int minute = 600,
    String title = 'Vaccine',
  }) => NotificationReminder(
    target: VaccinationNotificationTarget(
      petId: pet,
      vaccinationId: id,
      daysBefore: 1,
    ),
    scheduledDate: DateTime(2030, 1, 2),
    scheduledMinute: minute,
    title: title,
    body: 'Reminder',
  );
  NotificationReminder dose({String pet = 'pet1', String id = 'med1'}) =>
      NotificationReminder(
        target: MedicationDoseNotificationTarget(
          petId: pet,
          medicationId: id,
          periodId: 'period',
          scheduledDate: DateTime(2030, 1, 2),
          scheduledMinute: 600,
        ),
        scheduledDate: DateTime(2030, 1, 2),
        scheduledMinute: 600,
        title: 'Dose',
        body: 'Reminder',
      );
  PendingNotificationRequest request(int id, NotificationReminder reminder) =>
      PendingNotificationRequest(
        id,
        reminder.title,
        reminder.body,
        NotificationTargetCodec.encode(reminder.target),
      );

  Future<Result<void>> synchronize(List<NotificationReminder> reminders) =>
      repository.synchronizeReminders(
        reminders,
        channels: englishNotificationContent.channels,
      );

  setUpAll(() {
    registerFallbackValue(vaccine());
    registerFallbackValue(englishNotificationContent.channels);
  });

  for (final exact in [true, false]) {
    test(
      'feeding uses ${exact ? 'exact' : 'normal'} scheduling with the available permission',
      () async {
        when(notifications.getPermissionStatus).thenAnswer(
          (_) async => NotificationPermissionStatus(
            canShowNotifications: true,
            canScheduleExactAlarms: exact,
            requiresExactAlarmPermission: true,
          ),
        );
        final reminder = NotificationReminder(
          target: FeedingMealNotificationTarget(
            petId: 'pet1',
            planId: 'plan',
            mealId: 'meal',
            scheduledDate: DateTime(2030, 1, 2),
            scheduledMinute: 720,
          ),
          scheduledDate: DateTime(2030, 1, 2),
          scheduledMinute: 720,
          title: 'Meal',
          body: '40 g',
        );
        expect(await synchronize([reminder]), isA<Success<void>>());
        expect(scheduled.single.$3, exact);
        verifyNever(notifications.requestNotificationPermission);
        verifyNever(notifications.requestExactAlarmPermission);
      },
    );
  }

  test(
    'rejects feeding reminder time mismatches before native mutations',
    () async {
      final reminder = NotificationReminder(
        target: FeedingMealNotificationTarget(
          petId: 'pet1',
          planId: 'plan',
          mealId: 'meal',
          scheduledDate: DateTime(2030, 1, 2),
          scheduledMinute: 720,
        ),
        scheduledDate: DateTime(2030, 1, 2),
        scheduledMinute: 721,
        title: 'Meal',
        body: '40 g',
      );
      expect(await synchronize([reminder]), isA<Error<void>>());
      verifyZeroInteractions(notifications);
    },
  );
  setUp(() {
    notifications = MockNotifications();
    preferences = MockPreferences();
    repository = NotificationRepositoryImpl(
      preferences,
      notifications,
      now: () => current,
    );
    pending = [];
    scheduled = [];
    when(notifications.initialize).thenAnswer((_) async => null);
    when(
      () => notifications.openedNotifications,
    ).thenAnswer((_) => const Stream.empty());
    when(notifications.getPermissionStatus).thenAnswer((_) async => allowed);
    when(
      notifications.requestNotificationPermission,
    ).thenAnswer((_) async => allowed);
    when(
      notifications.requestExactAlarmPermission,
    ).thenAnswer((_) async => allowed);
    when(notifications.openNotificationSettings).thenAnswer((_) async {});
    when(notifications.refreshTimeZone).thenAnswer((_) async {});
    when(() => notifications.updateChannels(any())).thenAnswer((_) async {});
    when(
      notifications.getPendingNotifications,
    ).thenAnswer((_) async => List.of(pending));
    when(() => notifications.cancelReminder(any())).thenAnswer((call) async {
      pending.removeWhere((item) => item.id == call.positionalArguments.single);
    });
    when(
      () => notifications.scheduleReminder(
        any(),
        any(),
        exact: any(named: 'exact'),
        channels: any(named: 'channels'),
      ),
    ).thenAnswer((call) async {
      final id = call.positionalArguments[0] as int;
      final reminder = call.positionalArguments[1] as NotificationReminder;
      scheduled.add((id, reminder, call.namedArguments[#exact] as bool));
      pending.removeWhere((item) => item.id == id);
      pending.add(request(id, reminder));
    });
    when(
      preferences.getPreferences,
    ).thenAnswer((_) async => NotificationPreferences());
  });

  test(
    'initialization and reading preferences do not request permissions',
    () async {
      expect(
        await repository.initialize(),
        const Success<NotificationTarget?>(null),
      );
      expect(
        await repository.getPreferences(),
        Success(NotificationPreferences()),
      );
      verifyNever(notifications.requestNotificationPermission);
      verifyNever(notifications.requestExactAlarmPermission);
      verifyNever(notifications.getPendingNotifications);
    },
  );

  test('forwards valid tap targets as a stream', () async {
    final target = vaccine().target;
    when(
      () => notifications.openedNotifications,
    ).thenAnswer((_) => Stream.value(target));
    await expectLater(
      repository.openedNotifications,
      emitsInOrder([target, emitsDone]),
    );
  });

  test(
    'maps preference read/write failures independently of native scheduling',
    () async {
      final value = NotificationPreferences();
      when(
        preferences.getPreferences,
      ).thenThrow(const PreferencesStorageException());
      when(
        () => preferences.savePreferences(value),
      ).thenThrow(const PreferencesStorageException());
      expect(
        await repository.getPreferences(),
        const Error<NotificationPreferences>(
          PreferencesStorageFailure('Failed to load notification preferences'),
        ),
      );
      expect(
        await repository.savePreferences(value),
        const Error<void>(
          PreferencesStorageFailure('Failed to save notification preferences'),
        ),
      );
      verifyZeroInteractions(notifications);
    },
  );

  test(
    'saves preferences without requesting permission or touching the queue',
    () async {
      final value = NotificationPreferences(medicationRemindersEnabled: true);
      when(() => preferences.savePreferences(value)).thenAnswer((_) async {});
      expect(
        await repository.savePreferences(value),
        const Success<void>(null),
      );
      verify(() => preferences.savePreferences(value)).called(1);
      verifyZeroInteractions(notifications);
    },
  );

  test('reads and explicitly requests permission capabilities', () async {
    expect(await repository.getPermissionStatus(), const Success(allowed));
    expect(
      await repository.requestNotificationPermission(),
      const Success(allowed),
    );
    expect(
      await repository.requestExactAlarmPermission(),
      const Success(allowed),
    );
    expect(
      await repository.openNotificationSettings(),
      const Success<void>(null),
    );
  });

  for (final operation in [
    'initialize',
    'status',
    'permission',
    'exact',
    'settings',
  ]) {
    test('maps native $operation failure to a safe result', () async {
      final error = PlatformException(
        code: 'failure',
        message: 'Private native details',
      );
      final Future<Result<Object?>> result;
      switch (operation) {
        case 'initialize':
          when(notifications.initialize).thenThrow(error);
          result = repository.initialize();
        case 'status':
          when(notifications.getPermissionStatus).thenThrow(error);
          result = repository.getPermissionStatus();
        case 'permission':
          when(notifications.requestNotificationPermission).thenThrow(error);
          result = repository.requestNotificationPermission();
        case 'exact':
          when(notifications.requestExactAlarmPermission).thenThrow(error);
          result = repository.requestExactAlarmPermission();
        default:
          when(notifications.openNotificationSettings).thenThrow(error);
          result = repository.openNotificationSettings();
      }
      expect(
        await result,
        isA<Error<Object?>>().having(
          (value) => value.failure,
          'safe notification failure',
          isA<NotificationFailure>().having(
            (failure) => failure.message,
            'message',
            isNot(contains('Private native')),
          ),
        ),
      );
    });
  }

  test(
    'preserves native IDs across repository recreation and updates content/time',
    () async {
      final original = vaccine();
      pending = [request(42, original)];
      final changed = vaccine(minute: 900, title: 'Updated vaccine');
      expect(await synchronize([changed]), const Success<void>(null));
      expect(scheduled, [(42, changed, false)]);
      final recreated = NotificationRepositoryImpl(
        preferences,
        notifications,
        now: () => current,
      );
      expect(
        await recreated.synchronizeReminders([
          changed,
        ], channels: englishNotificationContent.channels),
        const Success<void>(null),
      );
      expect(scheduled.last.$1, 42);
      expect(pending.map((item) => item.id), [42]);
      verify(notifications.refreshTimeZone).called(2);
    },
  );

  test(
    'removes stale, duplicate and malformed owned entries while retaining foreign IDs',
    () async {
      final desired = vaccine();
      pending = [
        const PendingNotificationRequest(1, 'Foreign', null, 'other:payload'),
        request(4, desired),
        request(9, desired),
        request(5, vaccine(id: 'old')),
        const PendingNotificationRequest(
          7,
          null,
          null,
          'petlytics.reminder.v1:{',
        ),
      ];
      expect(await synchronize([desired, dose()]), const Success<void>(null));
      expect(pending.map((item) => item.id).toSet(), {1, 4, 2});
      verify(() => notifications.cancelReminder(9)).called(1);
      verify(() => notifications.cancelReminder(5)).called(1);
      verify(() => notifications.cancelReminder(7)).called(1);
      verifyNever(() => notifications.cancelReminder(1));
      expect(scheduled.last.$3, isTrue);
    },
  );

  test(
    'uses inexact medication scheduling when exact permission is denied',
    () async {
      when(notifications.getPermissionStatus).thenAnswer(
        (_) async => const NotificationPermissionStatus(
          canShowNotifications: true,
          canScheduleExactAlarms: false,
          requiresExactAlarmPermission: true,
        ),
      );
      expect(await synchronize([dose()]), const Success<void>(null));
      expect(scheduled.single.$3, isFalse);
      verifyNever(notifications.requestExactAlarmPermission);
    },
  );

  test(
    'denied display permission leaves an existing queue unchanged',
    () async {
      final original = vaccine();
      pending = [request(3, original)];
      when(notifications.getPermissionStatus).thenAnswer(
        (_) async => const NotificationPermissionStatus(
          canShowNotifications: false,
          canScheduleExactAlarms: false,
          requiresExactAlarmPermission: true,
        ),
      );
      expect(await synchronize([dose()]), isA<Error<void>>());
      expect(pending.single.id, 3);
      expect(scheduled, isEmpty);
      verifyNever(() => notifications.cancelReminder(any()));
    },
  );

  test(
    'empty reconciliation cancels only owned entries without needing a time zone or permission',
    () async {
      pending = [
        request(1, vaccine()),
        const PendingNotificationRequest(2, null, null, null),
      ];
      expect(await synchronize([]), const Success<void>(null));
      expect(pending.single.id, 2);
      verifyNever(notifications.refreshTimeZone);
      verifyNever(notifications.getPermissionStatus);
    },
  );

  test('rejects invalid batches before any native interaction', () async {
    final wrongDose = NotificationReminder(
      target: dose().target,
      scheduledDate: DateTime(2030, 1, 2),
      scheduledMinute: 601,
      title: '',
      body: '',
    );
    final past = NotificationReminder(
      target: vaccine().target,
      scheduledDate: current,
      scheduledMinute: 600,
      title: '',
      body: '',
    );
    final invalidMinute = NotificationReminder(
      target: vaccine().target,
      scheduledDate: DateTime(2030, 1, 2),
      scheduledMinute: 1440,
      title: '',
      body: '',
    );
    for (final batch in [
      [vaccine(), vaccine()],
      [wrongDose],
      [past],
      [invalidMinute],
      List.generate(65, (index) => vaccine(id: '$index')),
    ]) {
      expect(await synchronize(batch), isA<Error<void>>());
    }
    verifyZeroInteractions(notifications);
  });

  test(
    'foreign requests count toward the shared capacity without being removed',
    () async {
      pending = [const PendingNotificationRequest(99, null, null, 'foreign')];
      expect(
        await synchronize(List.generate(64, (i) => vaccine(id: '$i'))),
        isA<Error<void>>(),
      );
      expect(scheduled, isEmpty);
      expect(pending.single.id, 99);
      verifyNever(() => notifications.cancelReminder(any()));
    },
  );

  test('accepts the complete 64 reminder budget', () async {
    expect(
      await synchronize(List.generate(64, (i) => vaccine(id: '$i'))),
      const Success<void>(null),
    );
    expect(pending, hasLength(64));
    expect(pending.map((item) => item.id).toSet(), hasLength(64));
  });

  test(
    'replacing a full queue cancels the displaced item before adding and keeps other IDs',
    () async {
      final original = List.generate(64, (i) => vaccine(id: '$i'));
      await synchronize(original);
      final retainedIds = {for (final item in pending) item.payload: item.id};
      final displacedId = pending.last.id;
      final replacement = [
        vaccine(id: 'nearer', minute: 540),
        ...original.take(63),
      ];
      when(
        () => notifications.scheduleReminder(
          any(),
          any(),
          exact: any(named: 'exact'),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer((call) async {
        final id = call.positionalArguments[0] as int;
        final reminder = call.positionalArguments[1] as NotificationReminder;
        pending.removeWhere((item) => item.id == id);
        pending.add(request(id, reminder));
        expect(pending.length, lessThanOrEqualTo(64));
      });
      expect(await synchronize(replacement), const Success<void>(null));
      verify(() => notifications.cancelReminder(displacedId)).called(1);
      expect(pending, hasLength(64));
      expect(
        pending.map((item) => item.payload),
        unorderedEquals(
          replacement.map(
            (item) => NotificationTargetCodec.encode(item.target),
          ),
        ),
      );
      for (final item in pending.where(
        (item) => retainedIds.containsKey(item.payload),
      )) {
        expect(item.id, retainedIds[item.payload]);
      }
    },
  );

  for (final type in ['pet', 'medication', 'vaccination']) {
    test(
      'cancels $type by known owner/record IDs without preferences or clinical reads',
      () async {
        pending = [
          request(1, vaccine()),
          request(2, dose()),
          request(3, vaccine(pet: 'pet2')),
          request(4, dose(pet: 'pet2')),
          request(5, vaccine(id: 'other')),
          request(6, dose(id: 'other')),
        ];
        final result = await switch (type) {
          'pet' => repository.cancelPetReminders('pet1'),
          'medication' => repository.cancelMedicationReminders('pet1', 'med1'),
          _ => repository.cancelVaccinationReminders('pet1', 'vax1'),
        };
        expect(result, const Success<void>(null));
        expect(
          pending.map((item) => item.id),
          type == 'pet'
              ? [3, 4]
              : type == 'medication'
              ? [1, 3, 4, 5, 6]
              : [2, 3, 4, 5, 6],
        );
        verifyZeroInteractions(preferences);
        verifyNever(notifications.getPermissionStatus);
        verifyNever(notifications.refreshTimeZone);
      },
    );
  }

  test(
    'failed scheduling reports partial native state and a retry reconciles it',
    () async {
      var calls = 0;
      when(
        () => notifications.scheduleReminder(
          any(),
          any(),
          exact: any(named: 'exact'),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer((call) async {
        if (++calls == 2) throw PlatformException(code: 'schedule_failed');
        final id = call.positionalArguments[0] as int;
        final reminder = call.positionalArguments[1] as NotificationReminder;
        pending.removeWhere((item) => item.id == id);
        pending.add(request(id, reminder));
      });
      final batch = [vaccine(), dose()];
      expect(await synchronize(batch), isA<Error<void>>());
      expect(pending, hasLength(1));
      final retainedId = pending.single.id;
      expect(await synchronize(batch), const Success<void>(null));
      expect(pending, hasLength(2));
      expect(pending.any((item) => item.id == retainedId), isTrue);
    },
  );

  test(
    'serializes synchronization and cancellation, using a snapshot of caller input',
    () async {
      final gate = Completer<void>();
      when(
        () => notifications.scheduleReminder(
          any(),
          any(),
          exact: any(named: 'exact'),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer((call) async {
        await gate.future;
        pending.add(
          request(
            call.positionalArguments[0] as int,
            call.positionalArguments[1] as NotificationReminder,
          ),
        );
      });
      final input = [vaccine()];
      final sync = synchronize(input);
      input.clear();
      final cancel = repository.cancelPetReminders('pet1');
      await Future<void>.delayed(Duration.zero);
      verify(notifications.getPendingNotifications).called(1);
      gate.complete();
      expect(await sync, const Success<void>(null));
      expect(await cancel, const Success<void>(null));
      expect(pending, isEmpty);
    },
  );

  test(
    'failed cancellation returns an error and does not poison later queue operations',
    () async {
      pending = [request(1, vaccine())];
      when(
        () => notifications.cancelReminder(1),
      ).thenThrow(PlatformException(code: 'cancel_failed'));
      expect(await repository.cancelPetReminders('pet1'), isA<Error<void>>());
      when(
        () => notifications.cancelReminder(1),
      ).thenAnswer((_) async => pending.clear());
      expect(
        await repository.cancelPetReminders('pet1'),
        const Success<void>(null),
      );
    },
  );

  test(
    'localization replaces owned text under the same native IDs, retaining foreign reminders',
    () async {
      final original = vaccine(title: 'Milo · Vaccine');
      pending = [
        request(77, original),
        const PendingNotificationRequest(
          500,
          'Foreign',
          'Foreign body',
          'foreign-payload',
        ),
      ];
      final labels = NotificationContent(
        AppLocalizationsTr('tr_TR'),
        turkishLocale,
      ).channels;
      final translated = NotificationReminder(
        target: original.target,
        scheduledDate: original.scheduledDate,
        scheduledMinute: original.scheduledMinute,
        title: original.title,
        body: 'Aşı tarihi: 2 Oca 2030.',
      );
      expect(
        await repository.synchronizeReminders([translated], channels: labels),
        const Success<void>(null),
      );
      expect(pending.map((request) => request.id), [500, 77]);
      expect(
        pending.singleWhere((request) => request.id == 77).body,
        translated.body,
      );
      expect(
        pending.singleWhere((request) => request.id == 500).payload,
        'foreign-payload',
      );
      expect(scheduled.single.$1, 77);
      expect(scheduled.single.$2.target, original.target);
      expect(scheduled.single.$2.scheduledDate, original.scheduledDate);
      expect(scheduled.single.$2.scheduledMinute, original.scheduledMinute);
      verify(() => notifications.updateChannels(labels)).called(1);
      verifyNever(() => notifications.cancelReminder(any()));
    },
  );

  test(
    'empty queues still update localized channels without requesting permission',
    () async {
      final labels = NotificationContent(
        AppLocalizationsTr('tr_TR'),
        turkishLocale,
      ).channels;
      expect(
        await repository.synchronizeReminders([], channels: labels),
        const Success<void>(null),
      );
      verify(() => notifications.updateChannels(labels)).called(1);
      verifyNever(notifications.getPermissionStatus);
      verifyNever(notifications.requestNotificationPermission);
      verifyNever(notifications.requestExactAlarmPermission);
      expect(scheduled, isEmpty);
    },
  );

  test(
    'channel metadata failures preserve pending entries and remain retryable',
    () async {
      pending = [request(77, vaccine())];
      when(
        () => notifications.updateChannels(any()),
      ).thenThrow(PlatformException(code: 'channel_update_failed'));
      expect(await synchronize([vaccine()]), isA<Error<void>>());
      expect(pending.single.id, 77);
      expect(scheduled, isEmpty);
      verifyNever(() => notifications.cancelReminder(any()));
      when(() => notifications.updateChannels(any())).thenAnswer((_) async {});
      expect(await synchronize([vaccine()]), const Success<void>(null));
      expect(pending.single.id, 77);
    },
  );
}
