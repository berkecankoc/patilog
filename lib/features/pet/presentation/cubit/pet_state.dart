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

  const PetLoaded(this.pet);

  @override
  List<Object?> get props => [pet];
}

final class PetsLoaded extends PetState {
  final List<Pet> pets;

  const PetsLoaded(this.pets);

  @override
  List<Object?> get props => [pets];
}

final class PetError extends PetState {
  final String message;

  const PetError(this.message);

  @override
  List<Object?> get props => [message];
}
