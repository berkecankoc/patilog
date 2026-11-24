import 'package:equatable/equatable.dart';
import 'package:patilog/features/notification/domain/entities/notification_permission_status.dart';
import 'package:patilog/features/notification/domain/entities/notification_plan.dart';
import 'package:patilog/features/notification/domain/entities/notification_preferences.dart';
import 'package:patilog/features/notification/domain/entities/notification_target.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';

enum NotificationAction {
  initialize,
  synchronize,

  /// Asks for permission, then opens device settings if it stays blocked: a
  /// decided permission never prompts again on iOS (or after repeated Android
  /// denials), while an undecided one has no settings entry yet.
  notificationPermission,
  exactPermission,
  openSettings,
}

final class NotificationIssue extends Equatable {
  final NotificationAction action;
  final String message;
  const NotificationIssue(this.action, this.message);
  @override
  List<Object?> get props => [action, message];
}

final class NotificationState extends Equatable {
  final NotificationPreferences? preferences;
  final NotificationPermissionStatus? permissions;
  final NotificationPlan? plan;
  final DateTime? lastSyncedAt;
  final NotificationTarget? pendingTarget;
  final bool isBusy;
  final bool isSaving;
  final NotificationIssue? issue;
  final String? saveError;
  final NotificationPreferences? failedPreferences;

  /// A disabled category to offer after a saved record; shown app-wide.
  final ReminderCategory? reminderOffer;

  const NotificationState({
    this.preferences,
    this.permissions,
    this.plan,
    this.lastSyncedAt,
    this.pendingTarget,
    bool isBusy = false,
    this.isSaving = false,
    this.issue,
    this.saveError,
    this.failedPreferences,
    this.reminderOffer,
  }) : isBusy = isBusy || isSaving;

  NotificationState copyWith({
    NotificationPreferences? preferences,
    NotificationPermissionStatus? permissions,
    NotificationPlan? plan,
    DateTime? lastSyncedAt,
    NotificationTarget? pendingTarget,
    bool clearPendingTarget = false,
    bool? isBusy,
    bool? isSaving,
    NotificationIssue? issue,
    bool clearIssue = false,
    String? saveError,
    NotificationPreferences? failedPreferences,
    bool clearSaveError = false,
    ReminderCategory? reminderOffer,
    bool clearReminderOffer = false,
  }) => NotificationState(
    preferences: preferences ?? this.preferences,
    permissions: permissions ?? this.permissions,
    plan: plan ?? this.plan,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    pendingTarget: clearPendingTarget
        ? null
        : pendingTarget ?? this.pendingTarget,
    isBusy: isBusy ?? this.isBusy,
    isSaving: isSaving ?? this.isSaving,
    issue: clearIssue ? null : issue ?? this.issue,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    failedPreferences: clearSaveError
        ? null
        : failedPreferences ?? this.failedPreferences,
    reminderOffer: clearReminderOffer
        ? null
        : reminderOffer ?? this.reminderOffer,
  );

  @override
  List<Object?> get props => [
    preferences,
    permissions,
    plan,
    lastSyncedAt,
    pendingTarget,
    isBusy,
    isSaving,
    issue,
    saveError,
    failedPreferences,
    reminderOffer,
  ];
}
