import 'package:equatable/equatable.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';

sealed class VaccinationState extends Equatable {
  const VaccinationState();
}

final class VaccinationInitial extends VaccinationState {
  const VaccinationInitial();

  @override
  List<Object?> get props => [];
}

final class VaccinationLoading extends VaccinationState {
  const VaccinationLoading();

  @override
  List<Object?> get props => [];
}

final class VaccinationsLoaded extends VaccinationState {
  final String petId;
  final List<Vaccination> vaccinations;
  final String? vetVisitId;
  final bool isRefreshing;
  final String? refreshError;
  final bool isDeleting;
  final Vaccination? deletionVaccination;
  final String? deleteError;

  const VaccinationsLoaded(
    this.petId,
    this.vaccinations, {
    this.vetVisitId,
    this.isRefreshing = false,
    this.refreshError,
    this.isDeleting = false,
    this.deletionVaccination,
    this.deleteError,
  });

  @override
  List<Object?> get props => [
    petId,
    vaccinations,
    vetVisitId,
    isRefreshing,
    refreshError,
    isDeleting,
    deletionVaccination,
    deleteError,
  ];
}

final class VaccinationLoaded extends VaccinationState {
  final Vaccination vaccination;
  final bool isRefreshing;
  final String? refreshError;
  final bool isDeleting;
  final String? deleteError;

  const VaccinationLoaded(
    this.vaccination, {
    this.isRefreshing = false,
    this.refreshError,
    this.isDeleting = false,
    this.deleteError,
  });

  @override
  List<Object?> get props => [
    vaccination,
    isRefreshing,
    refreshError,
    isDeleting,
    deleteError,
  ];
}

final class VaccinationDeleted extends VaccinationState {
  final String vaccinationId;

  const VaccinationDeleted(this.vaccinationId);

  @override
  List<Object?> get props => [vaccinationId];
}

final class VaccinationError extends VaccinationState {
  final String message;

  const VaccinationError(this.message);

  @override
  List<Object?> get props => [message];
}
