import 'package:equatable/equatable.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';

enum AllPetsCareSection {
  pets,
  vetVisits,
  vaccinations,
  medications,
  feeding,
  weightHistory,
}

final class CareRecords<T> extends Equatable {
  final List<T> records;
  final bool hasLoaded;
  final bool isLoading;
  final String? error;

  CareRecords({
    List<T> records = const [],
    this.hasLoaded = false,
    this.isLoading = false,
    this.error,
  }) : records = List.unmodifiable(records);

  CareRecords<T> copyWith({
    List<T>? records,
    bool? hasLoaded,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => CareRecords(
    records: records ?? this.records,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [records, hasLoaded, isLoading, error];
}

/// The directory is shared by global destinations; clinical state stays in
/// each feature's Cubit, just as it does in a pet's care hub.
final class AllPetsCareState extends Equatable {
  final AllPetsCareSection activeSection;
  final CareRecords<Pet> pets;

  AllPetsCareState({
    this.activeSection = AllPetsCareSection.pets,
    CareRecords<Pet>? pets,
  }) : pets = pets ?? CareRecords();

  late final Map<String, Pet> petsById = Map.unmodifiable({
    for (final pet in pets.records) pet.id: pet,
  });

  AllPetsCareState copyWith({
    AllPetsCareSection? activeSection,
    CareRecords<Pet>? pets,
  }) => AllPetsCareState(
    activeSection: activeSection ?? this.activeSection,
    pets: pets ?? this.pets,
  );

  @override
  List<Object?> get props => [activeSection, pets];
}
