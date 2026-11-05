import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_feeding_icon.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_state.dart';
import 'package:petlytics/features/feeding/presentation/pages/feeding_page.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/medication/presentation/pages/medication_list_page.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_list_page.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_list_page.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_list_page.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

const _destinations = [
  (icon: Icons.pets_outlined, path: AppRoutes.pets),
  (icon: Icons.event_note_outlined, path: AppRoutes.allVetVisits),
  (icon: Icons.vaccines_outlined, path: AppRoutes.allVaccinations),
  (icon: Icons.medication_outlined, path: AppRoutes.allMedications),
  (icon: Icons.rice_bowl_outlined, path: AppRoutes.allFeeding),
];

class AllPetsCarePage extends StatefulWidget {
  final AllPetsCareSection section;
  const AllPetsCarePage({super.key, required this.section});
  @override
  State<AllPetsCarePage> createState() => _AllPetsCarePageState();
}

class _AllPetsCarePageState extends State<AllPetsCarePage>
    with WidgetsBindingObserver {
  GoRouter? _router;
  CareRecordChanges? _changes;
  Timer? _timer;
  bool _visible = false;
  bool _started = false;
  bool _queued = false;
  Cubit<Object?>? _observed;
  StreamSubscription<Object?>? _featureChanges;
  Set<String> _directoryIds = {};
  final _visited = <AllPetsCareSection>{};
  final _buckets = <AllPetsCareSection, PageStorageBucket>{};
  AllPetsCareCubit get _cubit => context.read<AllPetsCareCubit>();
  Cubit<Object?>? get _feature => switch (widget.section) {
    AllPetsCareSection.pets => null,
    AllPetsCareSection.vetVisits => context.read<VetVisitCubit>(),
    AllPetsCareSection.vaccinations => context.read<VaccinationCubit>(),
    AllPetsCareSection.medications => context.read<MedicationCubit>(),
    AllPetsCareSection.feeding => context.read<FeedingCubit>(),
  };
  bool get _busy => switch (_feature?.state) {
    VetVisitsLoaded(:final isDeleting) => isDeleting,
    VaccinationsLoaded(:final isDeleting) => isDeleting,
    MedicationsLoaded(:final pendingAction) => pendingAction != null,
    FeedingLoaded(:final pendingAction) => pendingAction != null,
    _ => false,
  };
  bool get _loading => switch (_feature?.state) {
    VetVisitLoading() ||
    VaccinationLoading() ||
    MedicationLoading() ||
    FeedingLoading() => true,
    VetVisitsLoaded(:final isRefreshing) => isRefreshing,
    VaccinationsLoaded(:final isRefreshing) => isRefreshing,
    MedicationsLoaded(
      :final isRefreshing,
      :final doses,
      :final pendingAction,
    ) =>
      isRefreshing || doses.isLoading || pendingAction != null,
    FeedingLoaded(:final isRefreshing, :final pendingAction) =>
      isRefreshing || pendingAction != null,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted &&
          _visible &&
          widget.section == AllPetsCareSection.vaccinations &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_scheduleSync);
      _router = router;
      router.routerDelegate.addListener(_scheduleSync);
    }
    final changes = CareRecordChanges.maybeOf(context);
    if (changes != _changes) {
      _changes?.removeListener(_recordChanged);
      _changes = changes;
      changes?.addListener(_recordChanged);
    }
    _scheduleSync();
  }

  @override
  void didUpdateWidget(AllPetsCarePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    _visible =
        _router?.state.uri.path == _destinations[widget.section.index].path;
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      if (!_visible) {
        if (_started) setState(() {});
        return;
      }
      setState(() {
        _started = true;
        _visited.add(widget.section);
      });
      final feature = _feature;
      if (_observed != feature) {
        _featureChanges?.cancel();
        _observed = feature;
        _featureChanges = feature?.stream.listen((_) {
          if (!mounted) return;
          setState(() {});
          if (!_busy) _scheduleSync();
        });
      }
      if (_busy) return;
      _cubit.activate(widget.section);
      switch (widget.section) {
        case AllPetsCareSection.vetVisits:
          final cubit = context.read<VetVisitCubit>();
          if (cubit.needsReload) cubit.loadAllVetVisits();
        case AllPetsCareSection.vaccinations:
          final cubit = context.read<VaccinationCubit>();
          if (cubit.needsReload) cubit.loadAllVaccinations();
        case AllPetsCareSection.medications:
          final cubit = context.read<MedicationCubit>();
          if (cubit.needsReload) cubit.loadAllMedications();
        case AllPetsCareSection.pets || AllPetsCareSection.feeding:
          break;
      }
    });
  }

  void _removePetRecords(String id) {
    context.read<VetVisitCubit>().removeDeletedPet(id);
    context.read<VaccinationCubit>().removeDeletedPet(id);
    context.read<MedicationCubit>().removeDeletedPet(id);
    if (_visited.contains(AllPetsCareSection.feeding)) {
      context.read<FeedingCubit>().removeDeletedPet(id);
    }
  }

  void _directoryChanged(AllPetsCareState state) {
    if (!state.pets.hasLoaded) return;
    final ids = state.petsById.keys.toSet();
    for (final id in _directoryIds.difference(ids)) {
      _removePetRecords(id);
    }
    _directoryIds = ids;
  }

  void _recordChanged() {
    if (!_started) return;
    final change = _changes?.last;
    if (change == null) return;
    if (change.petDeleted && change.petId != null) {
      _cubit.removeDeletedPet(change.petId!);
      _removePetRecords(change.petId!);
    } else {
      switch (change.tab) {
        case PetCareTab.profile || PetCareTab.weightHistory:
          _cubit.invalidatePets();
        case PetCareTab.vetVisits:
          if (!change.globalListIsCurrent) {
            if (change.deletedId != null) {
              context.read<VetVisitCubit>().removeDeletedVisit(
                change.deletedId!,
                petId: change.petId,
              );
            } else {
              context.read<VetVisitCubit>().invalidateList();
            }
          }
          context.read<VaccinationCubit>().invalidateList();
          context.read<MedicationCubit>().invalidateList();
        case PetCareTab.vaccinations:
          if (!change.globalListIsCurrent) {
            if (change.deletedId != null) {
              context.read<VaccinationCubit>().removeDeletedVaccination(
                change.deletedId!,
                petId: change.petId,
              );
            } else {
              context.read<VaccinationCubit>().invalidateList();
            }
          }
        case PetCareTab.medications:
          if (!change.globalListIsCurrent) {
            if (change.deletedId != null) {
              context.read<MedicationCubit>().removeDeletedMedication(
                change.deletedId!,
                petId: change.petId,
              );
            } else {
              context.read<MedicationCubit>().invalidateList();
            }
          }
        case PetCareTab.feeding:
          break;
      }
    }
    if (_visible) _scheduleSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _started && _visible && !_busy) {
      switch (widget.section) {
        case AllPetsCareSection.pets:
          _cubit.loadPets();
        case AllPetsCareSection.vetVisits:
          context.read<VetVisitCubit>().loadAllVetVisits();
        case AllPetsCareSection.vaccinations:
          context.read<VaccinationCubit>().loadAllVaccinations();
        case AllPetsCareSection.medications || AllPetsCareSection.feeding:
          break; // Daily tracking pages own their clock/lifecycle refresh.
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _featureChanges?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_scheduleSync);
    _changes?.removeListener(_recordChanged);
    super.dispose();
  }

  void _openPet(Pet pet) {
    if (_busy) return;
    context.push(
      AppRoutes.petDetail(pet.id),
      extra: PetCareRouteExtra(petId: pet.id, petName: pet.name),
    );
  }

  Widget _content(AllPetsCareSection section, AllPetsCareState state) =>
      switch (section) {
        AllPetsCareSection.pets =>
          !state.pets.hasLoaded
              ? state.pets.error != null
                    ? ErrorView(
                        message: AppLocalizations.of(context).petsLoadFailed,
                        onRetry: _cubit.loadPets,
                      )
                    : const Center(child: CircularProgressIndicator())
              : PetListPage.fromRecords(
                  pets: state.pets.records,
                  onOpenPet: _openPet,
                ),
        AllPetsCareSection.vetVisits => VetVisitListPage(
          pets: state.pets.records,
          petsLoaded: state.pets.hasLoaded,
        ),
        AllPetsCareSection.vaccinations => VaccinationListPage(
          pets: state.pets.records,
          petsLoaded: state.pets.hasLoaded,
        ),
        AllPetsCareSection.medications => MedicationListPage(
          pets: state.pets.records,
          petsLoaded: state.pets.hasLoaded,
          active: _visible && widget.section == section,
        ),
        AllPetsCareSection.feeding =>
          !state.pets.hasLoaded
              ? state.pets.error != null
                    ? ErrorView(
                        message: AppLocalizations.of(context).petsLoadFailed,
                        onRetry: _cubit.loadPets,
                      )
                    : const Center(child: CircularProgressIndicator())
              : FeedingPage(pets: state.pets.records),
      };

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return BlocConsumer<AllPetsCareCubit, AllPetsCareState>(
      listener: (_, state) => _directoryChanged(state),
      builder: (context, state) {
        final strings = AppLocalizations.of(context);
        final labels = [
          strings.myPets,
          strings.vetVisits,
          strings.vaccinations,
          strings.medications,
          strings.feeding,
        ];
        final navigationLabels = [...labels]
          ..[AllPetsCareSection.vetVisits.index] = strings.vetVisitsNavigation;
        final labelStyle = Theme.of(context).textTheme.labelSmall!
            .copyWith(letterSpacing: 0);
        final navigationWidth =
            MediaQuery.sizeOf(context).width -
            MediaQuery.paddingOf(context).horizontal;
        var labelHeight = 0.0;
        final labelHeights = <double>[];
        for (final label in navigationLabels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: Directionality.of(context),
            locale: Localizations.localeOf(context),
            // Match NavigationBar's effective label scaling.
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: 1.3),
          )..layout(maxWidth: navigationWidth / labels.length - 4);
          labelHeight = math.max(labelHeight, painter.height);
          labelHeights.add(painter.height);
          painter.dispose();
        }

        final section = widget.section;
        final petLoading =
            section == AllPetsCareSection.pets && state.pets.isLoading;
        return PopScope(
          canPop: !_busy && section == AllPetsCareSection.pets,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !_busy && section != AllPetsCareSection.pets) {
              context.go(AppRoutes.pets);
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              scrolledUnderElevation: 0,
              title: Text(labels[section.index]),
              actions: [
                if (section == AllPetsCareSection.pets)
                  IconButton(
                    tooltip: strings.settingsTitle,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      if (!_busy && _visible) context.push(AppRoutes.settings);
                    },
                  ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              labelTextStyle: WidgetStatePropertyAll(
                labelStyle.copyWith(overflow: TextOverflow.clip),
              ),
              height: math.max(80, 40 + labelHeight),
              selectedIndex: section.index,
              onDestinationSelected: _busy
                  ? null
                  : (index) {
                      if (!_busy && index != widget.section.index) {
                        context.go(_destinations[index].path);
                      }
                    },
              destinations: [
                for (final (index, destination) in _destinations.indexed)
                  NavigationBarTheme(
                    data: NavigationBarTheme.of(context).copyWith(
                      // Reserve the same label slot, even when only one item wraps.
                      labelPadding: EdgeInsets.fromLTRB(
                        2,
                        4,
                        2,
                        labelHeight - labelHeights[index],
                      ),
                    ),
                    child: NavigationDestination(
                      icon: index == AllPetsCareSection.feeding.index
                          ? const AppFeedingIcon()
                          : Icon(destination.icon),
                      label: navigationLabels[index],
                      tooltip: labels[index],
                    ),
                  ),
              ],
            ),

            floatingActionButton:
                section == AllPetsCareSection.pets && state.pets.hasLoaded
                ? FloatingActionButton.extended(
                    tooltip: state.pets.records.isEmpty
                        ? strings.addFirstPet
                        : strings.addPet,
                    isExtended:
                        MediaQuery.textScalerOf(context).scale(14) <= 21,
                    onPressed: () => context.push(AppRoutes.addEditPet),
                    icon: const Icon(Icons.add),
                    label: Text(
                      state.pets.records.isEmpty
                          ? strings.addFirstPet
                          : strings.addPet,
                    ),
                  )
                : null,
            body: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        children: [
                          if (state.pets.error != null &&
                              (section != AllPetsCareSection.pets ||
                                  state.pets.hasLoaded))
                            Flexible(
                              child: AppErrorFeedback(
                                message: section == AllPetsCareSection.pets
                                    ? strings.petsLoadFailed
                                    : strings.petNamesRefreshFailed,
                                retryLabel: strings.retryPets,
                                onRetry: _busy ? null : _cubit.loadPets,
                              ),
                            ),
                          Expanded(
                            child: IndexedStack(
                              index: section.index,
                              sizing: StackFit.expand,
                              children: [
                                for (final tab in AllPetsCareSection.values)
                                  _visited.contains(tab)
                                      ? HeroMode(
                                          enabled: tab == section && _visible,
                                          child: TickerMode(
                                            enabled: tab == section && _visible,
                                            child: PrimaryScrollController.none(
                                              child: PageStorage(
                                                key: ValueKey(tab),
                                                bucket: _buckets.putIfAbsent(
                                                  tab,
                                                  PageStorageBucket.new,
                                                ),
                                                child: _content(tab, state),
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (petLoading || _loading || _busy)
                    Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        semanticsLabel: strings.updatingCareRecords,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
