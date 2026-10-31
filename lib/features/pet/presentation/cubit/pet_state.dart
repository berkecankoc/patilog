import 'package:equatable/equatable.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';

sealed class PetState extends Equatable {
  const PetState();
}

final class PetInitial extends PetState {
  const PetInitial();

  @override
  List<Object?> get props => [];
}

final class PetLoading extends PetState {
  const PetLoading();

  @override
  List<Object?> get props => [];
}

final class PetLoaded extends PetState {
  final Pet pet;
  final bool isDeleting;
  final Failure? deleteError;
  final bool isRefreshing;
  final Failure? refreshError;

  const PetLoaded(
    this.pet, {
    this.isDeleting = false,
    this.deleteError,
    this.isRefreshing = false,
    this.refreshError,
  });

  @override
  List<Object?> get props => [
    pet,
    isDeleting,
    deleteError,
    isRefreshing,
    refreshError,
  ];
}

final class PetsLoaded extends PetState {
  final List<Pet> pets;

  const PetsLoaded(this.pets);

  @override
  List<Object?> get props => [pets];
}

final class PetCreated extends PetState {
  const PetCreated();

  @override
  List<Object?> get props => [];
}

final class PetUpdated extends PetState {
  const PetUpdated();

  @override
  List<Object?> get props => [];
}

final class PetDeleted extends PetState {
  const PetDeleted();

  @override
  List<Object?> get props => [];
}

final class PetError extends PetState {
  final Failure failure;

  const PetError(this.failure);

  @override
  List<Object?> get props => [failure];
}
