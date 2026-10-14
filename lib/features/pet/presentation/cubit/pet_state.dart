import 'package:equatable/equatable.dart';
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
  final String? deleteError;

  const PetLoaded(this.pet, {this.isDeleting = false, this.deleteError});

  @override
  List<Object?> get props => [pet, isDeleting, deleteError];
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
  final String message;

  const PetError(this.message);

  @override
  List<Object?> get props => [message];
}
