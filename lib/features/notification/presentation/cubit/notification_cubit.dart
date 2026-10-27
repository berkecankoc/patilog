import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';
import 'package:petlytics/features/notification/domain/entities/notification_data.dart';
import 'package:petlytics/features/notification/domain/entities/notification_permission_status.dart';
import 'package:petlytics/features/notification/domain/entities/notification_plan.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/notification/domain/repositories/notification_repository.dart';
import 'package:petlytics/features/notification/domain/use_cases/load_notification_data.dart';
import 'package:petlytics/features/notification/domain/use_cases/plan_notification_reminders.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_state.dart';

final class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository repository;
  final LoadNotificationData loadData;
  final PlanNotificationReminders planReminders;
  final DateTime Function() now;
  NotificationData? _data;
  StreamSubscription<NotificationTarget>? _taps;
  Future<void> _work = Future.value();
  bool _initialized = false;
  bool _closing = false;
  int _revision = 0;
  DateTime? _lastClockCheck;
  ({
    String petId,
    bool petDeleted,
    String? medicationId,
    String? vaccinationId,
  })?
  _failedDeletion;

  NotificationCubit(
    this.repository,
    this.loadData,
    this.planReminders, {
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(const NotificationState());

  Future<void> initialize() {
    if (_closing || isClosed || state.isBusy) return _work;
    emit(state.copyWith(isBusy: true));
    final revision = ++_revision;
    return _enqueue(() => _initialize(revision));
  }

  Future<void> _initialize(int revision) async {
    if (_stopped) return;
    emit(state.copyWith(isBusy: true));
    _taps ??= repository.openedNotifications.listen((target) {
      if (!_closing && !isClosed) emit(state.copyWith(pendingTarget: target));
    });
    if (!_initialized) {
      final initialized = await repository.initialize();
      if (_stopped) return;
      switch (initialized) {
        case Error<NotificationTarget?>():
          _fail(NotificationAction.initialize, initialized.failure.message);
          return;
        case Success<NotificationTarget?>():
          _initialized = true;
          if (initialized.data != null) {
            emit(state.copyWith(pendingTarget: initialized.data));
          }
      }
    }
    if (state.preferences == null) {
      final preferences = await repository.getPreferences();
      if (_stopped) return;
      switch (preferences) {
        case Error<NotificationPreferences>():
          _fail(NotificationAction.initialize, preferences.failure.message);
          return;
        case Success<NotificationPreferences>():
          emit(state.copyWith(preferences: preferences.data));
      }
    }
    await _refresh(revision);
  }

  Future<void> refresh() {
    if (_stopped) return Future.value();
    final revision = ++_revision;
    return _enqueue(
      () => !_initialized || state.preferences == null
          ? _initialize(revision)
          : _refresh(revision),
    );
  }

  Future<void> _refresh(int revision) async {
    if (_stopped) return;
    emit(state.copyWith(isBusy: true));
    final preferences = state.preferences!;
    if (!preferences.medicationRemindersEnabled &&
        !preferences.vaccinationRemindersEnabled) {
      _data = NotificationData();
      await _synchronize(
        NotificationPlan(reminders: [], hasMore: false),
        revision,
      );
      return;
    }
    final permissions = await repository.getPermissionStatus();
    if (_stopped) return;
    if (permissions case Error<NotificationPermissionStatus>()) {
      _data = null;
      _fail(NotificationAction.synchronize, permissions.failure.message);
      return;
    }
    final status = (permissions as Success<NotificationPermissionStatus>).data;
    emit(state.copyWith(permissions: status));
    if (!status.canShowNotifications) {
      _data = NotificationData();
      await _synchronize(
        NotificationPlan(reminders: [], hasMore: false),
        revision,
      );
      return;
    }
    final loaded = await loadData(preferences, now());
    if (_stopped) return;
    switch (loaded) {
      case Error<NotificationData>():
        _data = null;
        _fail(NotificationAction.synchronize, loaded.failure.message);
      case Success<NotificationData>():
        _data = loaded.data;
        await _synchronize(
          planReminders(loaded.data, preferences, now()),
          revision,
        );
    }
  }

  Future<void> _synchronize(NotificationPlan plan, int revision) async {
    // A newer mutation will refresh/cancel next; never submit a stale read.
    if (_stopped || revision != _revision) return;
    final result = await repository.synchronizeReminders(plan.reminders);
    if (_stopped) return;
    switch (result) {
      case Error<void>():
        _fail(NotificationAction.synchronize, result.failure.message);
      case Success<void>():
        _failedDeletion = null;
        emit(
          state.copyWith(
            plan: plan,
            lastSyncedAt: now(),
            isBusy: false,
            clearIssue: true,
          ),
        );
    }
  }

  Future<void> removeDeleted({
    required String petId,
    bool petDeleted = false,
    String? medicationId,
    String? vaccinationId,
  }) {
    if (_stopped) return Future.value();
    final revision = ++_revision;
    return _enqueue(() async {
      emit(state.copyWith(isBusy: true));
      final result = await (petDeleted
          ? repository.cancelPetReminders(petId)
          : medicationId != null
          ? repository.cancelMedicationReminders(petId, medicationId)
          : repository.cancelVaccinationReminders(petId, vaccinationId!));
      if (_stopped) return;
      _data = _data?.without(
        petId: petId,
        petDeleted: petDeleted,
        medicationId: medicationId,
        vaccinationId: vaccinationId,
      );
      if (result case Error<void>()) {
        _failedDeletion = (
          petId: petId,
          petDeleted: petDeleted,
          medicationId: medicationId,
          vaccinationId: vaccinationId,
        );
        _fail(NotificationAction.synchronize, result.failure.message);
      } else {
        _failedDeletion = null;
        if (_data != null && state.preferences != null) {
          await _synchronize(
            planReminders(_data!, state.preferences!, now()),
            revision,
          );
        } else {
          emit(state.copyWith(isBusy: false));
        }
      }
    });
  }

  Future<void> setPreferences(NotificationPreferences value) {
    final previous = state.preferences;
    if (_stopped || state.isBusy || previous == null || previous == value) {
      return Future.value();
    }
    emit(state.copyWith(isBusy: true, isSaving: true, clearSaveError: true));
    final revision = ++_revision;
    return _enqueue(() async {
      final medicationOn =
          value.medicationRemindersEnabled &&
          !previous.medicationRemindersEnabled;
      final vaccinationOn =
          value.vaccinationRemindersEnabled &&
          !previous.vaccinationRemindersEnabled;
      if (medicationOn || vaccinationOn) {
        var permission = await repository.getPermissionStatus();
        if (_stopped) return;
        if (permission case Success<NotificationPermissionStatus>(
          data: final status,
        ) when !status.canShowNotifications) {
          permission = await repository.requestNotificationPermission();
          if (_stopped) return;
        }
        if (permission
            case Success<NotificationPermissionStatus>(data: final status)
            when medicationOn &&
                status.canShowNotifications &&
                status.requiresExactAlarmPermission &&
                !status.canScheduleExactAlarms) {
          permission = await repository.requestExactAlarmPermission();
          if (_stopped) return;
        }
        if (permission case Error<NotificationPermissionStatus>()) {
          _saveFailed(value, permission.failure.message);
          return;
        }
        emit(
          state.copyWith(
            permissions:
                (permission as Success<NotificationPermissionStatus>).data,
          ),
        );
      }
      final saved = await repository.savePreferences(value);
      if (_stopped) return;
      if (saved case Error<void>()) {
        _saveFailed(value, saved.failure.message);
        return;
      }
      emit(
        state.copyWith(
          preferences: value,
          isSaving: false,
          clearSaveError: true,
        ),
      );
      await _refresh(revision);
    });
  }

  Future<void> retrySave() => state.failedPreferences == null
      ? Future.value()
      : setPreferences(state.failedPreferences!);

  Future<void> perform(NotificationAction action) {
    if (_stopped || state.isBusy) return Future.value();
    if (action == NotificationAction.initialize) return initialize();
    if (action == NotificationAction.synchronize) return refresh();
    emit(state.copyWith(isBusy: true));
    final revision = ++_revision;
    return _enqueue(() async {
      final result = await switch (action) {
        NotificationAction.notificationPermission =>
          repository.requestNotificationPermission(),
        NotificationAction.exactPermission =>
          repository.requestExactAlarmPermission(),
        _ => repository.openNotificationSettings(),
      };
      if (_stopped) return;
      if (result case Error(:final failure)) {
        _fail(action, failure.message);
      } else {
        if (result case Success<NotificationPermissionStatus>()) {
          emit(state.copyWith(permissions: result.data));
        }
        if (!_initialized || state.preferences == null) {
          await _initialize(revision);
        } else {
          await _refresh(revision);
        }
      }
    });
  }

  Future<void> retry() {
    final deletion = _failedDeletion;
    if (deletion != null) {
      return removeDeleted(
        petId: deletion.petId,
        petDeleted: deletion.petDeleted,
        medicationId: deletion.medicationId,
        vaccinationId: deletion.vaccinationId,
      );
    }
    return state.issue == null ? Future.value() : perform(state.issue!.action);
  }

  void acknowledgeTarget() {
    if (!_stopped) emit(state.copyWith(clearPendingTarget: true));
  }

  Future<void> refreshForClockChange() {
    if (_stopped || state.isBusy || state.preferences == null) {
      return Future.value();
    }
    final current = now();
    final previous = _lastClockCheck ?? state.lastSyncedAt;
    _lastClockCheck = current;
    final next = state.plan?.nextRefreshAt;
    if (previous != null &&
            (current.isBefore(previous) ||
                calendarDayNumber(previous) != calendarDayNumber(current)) ||
        next != null && !next.isAfter(current) ||
        state.issue != null) {
      return refresh();
    }
    return Future.value();
  }

  bool get _stopped => _closing || isClosed;
  Future<void> _enqueue(Future<void> Function() operation) {
    final work = _work.then((_) async {
      if (!_stopped) await operation();
    });
    _work = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  void _fail(NotificationAction action, String message) => emit(
    state.copyWith(isBusy: false, issue: NotificationIssue(action, message)),
  );

  void _saveFailed(NotificationPreferences value, String message) => emit(
    state.copyWith(
      isBusy: false,
      isSaving: false,
      saveError: message,
      failedPreferences: value,
    ),
  );

  @override
  Future<void> close() async {
    _closing = true;
    await _taps?.cancel();
    await super.close();
  }
}
