import 'package:petlytics/core/error/failure.dart';
import 'package:equatable/equatable.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';

sealed class MedicationState extends Equatable {
  const MedicationState();
}

final class MedicationInitial extends MedicationState {
  const MedicationInitial();

  @override
  List<Object?> get props => [];
}

final class MedicationLoading extends MedicationState {
  const MedicationLoading();

  @override
  List<Object?> get props => [];
}

final class MedicationError extends MedicationState {
  final Failure failure;

  const MedicationError(this.failure);

  @override
  List<Object?> get props => [failure];
}

final class MedicationDeleted extends MedicationState {
  final String medicationId;

  const MedicationDeleted(this.medicationId);

  @override
  List<Object?> get props => [medicationId];
}

final class MedicationDosesState extends Equatable {
  final DateTime date;
  final List<MedicationDose> doses;
  final bool hasLoaded;
  final bool isLoading;
  final String? error;
  final bool followsToday;

  const MedicationDosesState({
    required this.date,
    this.doses = const [],
    this.hasLoaded = false,
    this.isLoading = false,
    this.error,
    this.followsToday = true,
  });

  @override
  List<Object?> get props => [
    date,
    doses,
    hasLoaded,
    isLoading,
    error,
    followsToday,
  ];
}

final class MedicationCalendarState extends Equatable {
  final DateTime month;
  final List<MedicationDose> doses;
  final bool hasLoaded;
  final bool isLoading;
  final String? error;

  const MedicationCalendarState({
    required this.month,
    this.doses = const [],
    this.hasLoaded = false,
    this.isLoading = false,
    this.error,
  });

  @override
  List<Object?> get props => [month, doses, hasLoaded, isLoading, error];
}

final class MedicationsLoaded extends MedicationState {
  final String petId;
  final List<Medication> medications;
  final String? medicationId;
  final String? vetVisitId;
  final DateTime currentTime;
  final MedicationDosesState doses;
  final MedicationCalendarState? calendar;
  final bool isRefreshing;
  final String? refreshError;
  final MedicationAction? pendingAction;
  final MedicationAction? failedAction;
  final String? actionError;

  MedicationsLoaded({
    required this.petId,
    required List<Medication> medications,
    this.medicationId,
    this.vetVisitId,
    required this.currentTime,
    required this.doses,
    this.calendar,
    this.isRefreshing = false,
    this.refreshError,
    this.pendingAction,
    this.failedAction,
    this.actionError,
  }) : medications = List.unmodifiable(medications);

  MedicationsLoaded copyWith({
    List<Medication>? medications,
    DateTime? currentTime,
    MedicationDosesState? doses,
    MedicationCalendarState? calendar,
    bool? isRefreshing,
    String? refreshError,
    bool clearRefreshError = false,
    MedicationAction? pendingAction,
    bool clearPendingAction = false,
    MedicationAction? failedAction,
    String? actionError,
    bool clearActionError = false,
  }) => MedicationsLoaded(
    petId: petId,
    medications: medications ?? this.medications,
    medicationId: medicationId,
    vetVisitId: vetVisitId,
    currentTime: currentTime ?? this.currentTime,
    doses: doses ?? this.doses,
    calendar: calendar ?? this.calendar,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
    pendingAction: clearPendingAction
        ? null
        : pendingAction ?? this.pendingAction,
    failedAction: clearActionError ? null : failedAction ?? this.failedAction,
    actionError: clearActionError ? null : actionError ?? this.actionError,
  );

  @override
  List<Object?> get props => [
    petId,
    medications,
    medicationId,
    vetVisitId,
    currentTime,
    doses,
    calendar,
    isRefreshing,
    refreshError,
    pendingAction,
    failedAction,
    actionError,
  ];
}

/// Retains the exact failed intent. Destructive retries still need UI confirmation.
sealed class MedicationAction extends Equatable {
  final String medicationId;

  const MedicationAction(this.medicationId);
}

final class DeleteMedicationAction extends MedicationAction {
  const DeleteMedicationAction(super.medicationId);

  @override
  List<Object?> get props => [medicationId];
}

final class DeleteMedicationPeriodAction extends MedicationAction {
  final String periodId;

  const DeleteMedicationPeriodAction(super.medicationId, this.periodId);

  @override
  List<Object?> get props => [medicationId, periodId];
}

final class SaveMedicationDoseAction extends MedicationAction {
  final MedicationDoseLog log;

  const SaveMedicationDoseAction(super.medicationId, this.log);

  @override
  List<Object?> get props => [medicationId, log];
}

final class ClearMedicationDoseAction extends MedicationAction {
  final MedicationDoseLog log;

  const ClearMedicationDoseAction(super.medicationId, this.log);

  @override
  List<Object?> get props => [medicationId, log];
}
