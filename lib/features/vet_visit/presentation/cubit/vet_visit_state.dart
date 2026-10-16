import 'package:equatable/equatable.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';

sealed class VetVisitState extends Equatable {
  const VetVisitState();
}

final class VetVisitInitial extends VetVisitState {
  const VetVisitInitial();

  @override
  List<Object?> get props => [];
}

final class VetVisitLoading extends VetVisitState {
  const VetVisitLoading();

  @override
  List<Object?> get props => [];
}

final class VetVisitsLoaded extends VetVisitState {
  final String petId;
  final List<VetVisit> visits;
  final bool isRefreshing;
  final String? refreshError;
  final bool isDeleting;
  final VetVisit? deletionVisit;
  final String? deleteError;

  const VetVisitsLoaded(
    this.petId,
    this.visits, {
    this.isRefreshing = false,
    this.refreshError,
    this.isDeleting = false,
    this.deletionVisit,
    this.deleteError,
  });

  @override
  List<Object?> get props => [
    petId,
    visits,
    isRefreshing,
    refreshError,
    isDeleting,
    deletionVisit,
    deleteError,
  ];
}

final class VetVisitLoaded extends VetVisitState {
  final VetVisit visit;
  final bool isRefreshing;
  final String? refreshError;
  final bool isDeleting;
  final String? deleteError;

  const VetVisitLoaded(
    this.visit, {
    this.isRefreshing = false,
    this.refreshError,
    this.isDeleting = false,
    this.deleteError,
  });

  @override
  List<Object?> get props => [
    visit,
    isRefreshing,
    refreshError,
    isDeleting,
    deleteError,
  ];
}

final class VetVisitDeleted extends VetVisitState {
  final String visitId;

  const VetVisitDeleted(this.visitId);

  @override
  List<Object?> get props => [visitId];
}

final class VetVisitError extends VetVisitState {
  final String message;

  const VetVisitError(this.message);

  @override
  List<Object?> get props => [message];
}
