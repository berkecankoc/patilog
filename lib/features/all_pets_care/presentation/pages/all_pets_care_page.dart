import 'dart:async';
import 'package:petlytics/core/widgets/app_view_selector.dart';
import 'package:petlytics/core/widgets/app_pet_filter.dart';
import 'package:petlytics/core/widgets/app_feeding_icon.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_state.dart';
import 'package:petlytics/features/feeding/presentation/pages/feeding_page.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:petlytics/core/widgets/care_record_card.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_doses.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_list_content.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_avatar.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_list_page.dart';
import 'package:petlytics/features/vaccination/presentation/widgets/vaccination_list_content.dart';
import 'package:petlytics/features/vet_visit/presentation/widgets/vet_visit_list_content.dart';

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
  bool _dosePanelOpen = false;
  bool _catalog = false;
  StreamSubscription<FeedingState>? _feedingChanges;
  bool get _busy =>
      _cubit.state.isBusy ||
      widget.section == AllPetsCareSection.feeding &&
          context.read<FeedingCubit>().state is FeedingLoaded &&
          (context.read<FeedingCubit>().state as FeedingLoaded).pendingAction !=
              null;
  final _visited = <AllPetsCareSection>{};
  final _buckets = <AllPetsCareSection, PageStorageBucket>{};
  AllPetsCareCubit get _cubit => context.read<AllPetsCareCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_visible &&
          !_dosePanelOpen &&
          (widget.section == AllPetsCareSection.medications ||
              widget.section == AllPetsCareSection.vaccinations) &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _cubit.refreshForClockChange();
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
      if (widget.section == AllPetsCareSection.feeding &&
          _feedingChanges == null) {
        _feedingChanges = context.read<FeedingCubit>().stream.listen((_) {
          if (mounted) setState(() {});
        });
      }
      _cubit.activate(widget.section);
    });
  }

  void _recordChanged() {
    if (!_started) return;
    final change = _changes?.last;
    if (change == null) return;
    if (change.globalListIsCurrent) return;
    if (change.petDeleted && change.petId != null) {
      _cubit.removeDeletedPet(change.petId!);
    } else {
      switch (change.tab) {
        case PetCareTab.profile || PetCareTab.weightHistory:
          _cubit.invalidate(AllPetsCareSection.pets);
        case PetCareTab.vetVisits:
          if (change.deletedId != null) {
            _cubit.removeDeletedVisit(change.petId!, change.deletedId!);
          } else {
            _cubit.invalidate(AllPetsCareSection.vetVisits);
            _cubit.invalidate(AllPetsCareSection.vaccinations);
            _cubit.invalidate(AllPetsCareSection.medications);
          }
        case PetCareTab.vaccinations:
          if (change.deletedId != null) {
            _cubit.removeDeletedVaccination(change.petId!, change.deletedId!);
          } else {
            _cubit.invalidate(AllPetsCareSection.vaccinations);
          }
        case PetCareTab.medications:
          if (change.deletedId != null) {
            _cubit.removeDeletedMedication(change.petId!, change.deletedId!);
          } else {
            _cubit.invalidate(AllPetsCareSection.medications);
          }
        case PetCareTab.feeding:
          break;
      }
    }
    if (_visible) _scheduleSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _started &&
        _visible &&
        !_dosePanelOpen) {
      _cubit.refreshActive();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feedingChanges?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_scheduleSync);
    _changes?.removeListener(_recordChanged);
    super.dispose();
  }

  Future<void> _perform(AllPetsCareAction action) async {
    if (_cubit.state.isBusy) return;
    if (action is! SaveGlobalDose) {
      final pet = _cubit.state.petsById[action.petId];
      if (pet == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AppConfirmationDialog(
          title: switch (action) {
            DeleteGlobalVetVisit() => AppLocalizations.of(
              context,
            ).deleteVetVisitTitle,
            DeleteGlobalVaccination() => AppLocalizations.of(
              context,
            ).deleteVaccinationTitle,
            _ => AppLocalizations.of(context).clearDoseRecordTitle,
          },
          message: switch (action) {
            DeleteGlobalVetVisit() => AppLocalizations.of(
              context,
            ).deleteGlobalVisitMessage(pet.name),
            DeleteGlobalVaccination() => AppLocalizations.of(
              context,
            ).deleteGlobalVaccinationMessage(pet.name),
            _ => AppLocalizations.of(context).clearDoseRecordMessage,
          },
          confirmLabel: action is ClearGlobalDose
              ? AppLocalizations.of(context).clearRecord
              : AppLocalizations.of(context).deleteAction,
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    await _cubit.performAction(action);
  }

  Future<void> _add() async {
    if (_cubit.state.isBusy) return;
    if (widget.section == AllPetsCareSection.pets ||
        _cubit.state.pets.records.isEmpty) {
      await context.push(AppRoutes.addEditPet);
      return;
    }
    final state = _cubit.state;
    Pet? pet = state.petsById[state.petFilters[widget.section]];
    if (pet == null && state.pets.records.length == 1) {
      pet = state.pets.records.single;
    }
    pet ??= await showModalBottomSheet<Pet>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(sheetContext).choosePet,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(sheetContext).close,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.pets.records.length,
                itemBuilder: (_, index) {
                  final pet = state.pets.records[index];
                  return ListTile(
                    leading: PetAvatar(pet: pet, size: 40, iconSize: 24),
                    title: Text(pet.name),
                    subtitle: Text(
                      pet.speciesAndBreed(AppLocalizations.of(sheetContext)),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(sheetContext).pop(pet),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || pet == null) return;
    final selected = _cubit.state.petsById[pet.id];
    if (selected == null) return;
    final extra = switch (widget.section) {
      AllPetsCareSection.vetVisits => VetVisitFormExtra(
        petId: selected.id,
        petName: selected.name,
      ),
      AllPetsCareSection.vaccinations => VaccinationFormExtra(
        petId: selected.id,
        petName: selected.name,
      ),
      _ => MedicationFormExtra(petId: selected.id, petName: selected.name),
    };
    final location = switch (widget.section) {
      AllPetsCareSection.vetVisits => AppRoutes.addEditVetVisit(selected.id),
      AllPetsCareSection.vaccinations => AppRoutes.addEditVaccination(
        selected.id,
      ),
      _ => AppRoutes.addEditMedication(selected.id),
    };
    await context.push(location, extra: extra);
  }

  void _open(String location, String petId) {
    final state = _cubit.state;
    final pet = state.petsById[petId];
    if (state.isBusy || pet == null) return;
    context.push(
      location,
      extra: PetCareRouteExtra(petId: petId, petName: pet.name),
    );
  }

  MedicationDoseEditor _editor(MedicationDose dose) => MedicationDoseEditor(
    changes: _cubit.stream,
    now: _cubit.now,
    read: () {
      final state = _cubit.state;
      return (
        dose: state.doses.records
            .where(
              (row) =>
                  row.period.id == dose.period.id &&
                  row.scheduledMinute == dose.scheduledMinute &&
                  DateUtils.isSameDay(row.scheduledDate, dose.scheduledDate),
            )
            .firstOrNull,
        known: state.doseResultsKnown,
        busy: state.isBusy,
        error: state.actionError,
      );
    },
    save: (log) => _cubit.performAction(
      SaveGlobalDose(dose.medication.petId, dose.medication.id, log),
    ),
    clear: (log) => _perform(
      ClearGlobalDose(dose.medication.petId, dose.medication.id, log),
    ),
  );

  Future<void> _editDose(MedicationDose dose) async {
    _dosePanelOpen = true;
    try {
      await showMedicationDoseSheet(
        context,
        dose,
        editor: _editor(dose),
        petIdentity: CarePetIdentity(
          pet: _cubit.state.petsById[dose.medication.petId],
        ),
      );
    } finally {
      _dosePanelOpen = false;
      if (mounted && _visible) _cubit.refreshForClockChange();
    }
  }

  CareRecords<Object?> _records(
    AllPetsCareState state,
    AllPetsCareSection section,
  ) => switch (section) {
    AllPetsCareSection.pets => state.pets,
    AllPetsCareSection.vetVisits => state.visits,
    AllPetsCareSection.vaccinations => state.vaccinations,
    AllPetsCareSection.medications => state.medications,
    AllPetsCareSection.feeding => state.pets,
  };

  Widget _filter(AllPetsCareState state, AllPetsCareSection section) =>
      state.pets.records.length < 2
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: AppPetFilter(
            key: ValueKey((section, state.petFilters[section])),
            pets: state.pets.records,
            selectedPetId: state.petFilters[section],
            onChanged: state.isBusy
                ? null
                : (value) => _cubit.selectPet(section, value),
          ),
        );

  Widget _vaccines(AllPetsCareState state) {
    final groups = [
      (
        AppLocalizations.of(context).overdue,
        state.overdueVaccinations,
        Icons.event_busy_outlined,
      ),
      (
        AppLocalizations.of(context).today,
        state.todayVaccinations,
        Icons.today_outlined,
      ),
      (
        AppLocalizations.of(context).upcoming,
        state.upcomingVaccinations,
        Icons.event_outlined,
      ),
      (
        AppLocalizations.of(context).history,
        state.administeredVaccinations,
        Icons.history,
      ),
    ];
    return VaccinationListContent(
      groups: [
        for (final (title, rows, icon) in groups)
          (title: title, icon: icon, records: rows),
      ],
      petsById: state.petsById,
      header: _filter(state, AllPetsCareSection.vaccinations),
      isDeleting: (vaccination) =>
          state.pendingAction ==
          DeleteGlobalVaccination(vaccination.petId, vaccination.id),
      onOpen: state.isBusy
          ? null
          : (vaccination) => _open(
              AppRoutes.vaccinationDetail(vaccination.petId, vaccination.id),
              vaccination.petId,
            ),
      onDelete: state.isBusy || state.vaccinations.isLoading
          ? null
          : (vaccination) => _perform(
              DeleteGlobalVaccination(vaccination.petId, vaccination.id),
            ),
    );
  }

  Widget _medications(AllPetsCareState state) {
    final selector = Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: AppViewSelector(
        labels: [
          AppLocalizations.of(context).doses,
          AppLocalizations.of(context).medications,
        ],
        selectedIndex: _catalog ? 1 : 0,
        onSelected: state.isBusy
            ? null
            : (index) {
                if (!_cubit.state.isBusy) {
                  setState(() => _catalog = index == 1);
                }
              },
      ),
    );
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _filter(state, AllPetsCareSection.medications),
        selector,
        if (!_catalog)
          MedicationDateSelector(
            date: state.doseDate,
            now: _cubit.now,
            compact: true,
            onChanged: state.isBusy || state.medications.isLoading
                ? null
                : _cubit.loadDoses,
          ),
      ],
    );
    return _catalog
        ? MedicationCatalogContent(
            medications: state.visibleMedications,
            currentTime: state.currentTime,
            petsById: state.petsById,
            header: header,
            onOpen: state.isBusy
                ? null
                : (medication) => _open(
                    AppRoutes.medicationDetail(medication.petId, medication.id),
                    medication.petId,
                  ),
          )
        : MedicationDoseListContent(
            doses: state.visibleDoses,
            known: state.doseResultsKnown,
            loading: state.doses.isLoading,
            busy: state.isBusy || state.medications.isLoading,
            petsById: state.petsById,
            editorFor: _editor,
            onRecord: _editDose,
            header: header,
            empty: CareEmptyView(
              icon: Icons.schedule_outlined,
              title: AppLocalizations.of(context).noDoses,
              message: AppLocalizations.of(context).allPetsNoDayDoses,
            ),
          );
  }

  String _loadErrorMessage(AllPetsCareSection section) => switch (section) {
    AllPetsCareSection.pets => AppLocalizations.of(context).petsLoadFailed,
    AllPetsCareSection.vetVisits => AppLocalizations.of(
      context,
    ).visitsLoadFailed,
    AllPetsCareSection.vaccinations => AppLocalizations.of(
      context,
    ).vaccinationsLoadFailed,
    AllPetsCareSection.medications => AppLocalizations.of(
      context,
    ).medicationsLoadFailed,
    AllPetsCareSection.feeding => AppLocalizations.of(
      context,
    ).feedingLoadFailed,
  };

  Widget _content(AllPetsCareSection section, AllPetsCareState state) {
    final data = _records(state, section);
    if (!data.hasLoaded) {
      return data.error != null
          ? ErrorView(
              message: _loadErrorMessage(section),
              onRetry: _cubit.refreshActive,
            )
          : const Center(child: CircularProgressIndicator());
    }
    if (section == AllPetsCareSection.feeding) {
      return FeedingPage(pets: state.pets.records);
    }
    if (section != AllPetsCareSection.pets &&
        state.pets.hasLoaded &&
        state.pets.records.isEmpty) {
      return CareEmptyView(
        icon: Icons.pets_outlined,
        title: AppLocalizations.of(context).noPetsYet,
        message: AppLocalizations.of(context).petsEmptyDescription,
      );
    }
    if (section == AllPetsCareSection.pets) {
      return PetListPage.fromRecords(
        pets: state.pets.records,
        onOpenPet: (pet) => _open(AppRoutes.petDetail(pet.id), pet.id),
      );
    }
    if (section == AllPetsCareSection.vetVisits) {
      return VetVisitListContent(
        visits: state.visibleVisits,
        petsById: state.petsById,
        header: _filter(state, section),
        isDeleting: (visit) =>
            state.pendingAction == DeleteGlobalVetVisit(visit.petId, visit.id),
        onOpen: state.isBusy
            ? null
            : (visit) => _open(
                AppRoutes.vetVisitDetail(visit.petId, visit.id),
                visit.petId,
              ),
        onDelete: state.isBusy || state.visits.isLoading
            ? null
            : (visit) => _perform(DeleteGlobalVetVisit(visit.petId, visit.id)),
      );
    }
    if (section == AllPetsCareSection.vaccinations) {
      return _vaccines(state);
    }
    return _medications(state);
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return BlocBuilder<AllPetsCareCubit, AllPetsCareState>(
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
        final labelStyle = Theme.of(
          context,
        ).textTheme.labelSmall!.copyWith(letterSpacing: 0);
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
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.3),
          )..layout(maxWidth: navigationWidth / labels.length - 4);
          labelHeight = math.max(labelHeight, painter.height);
          labelHeights.add(painter.height);
          painter.dispose();
        }
        final section = widget.section;
        final data = _records(state, section);
        final noPets = state.pets.hasLoaded && state.pets.records.isEmpty;
        final addLabel = noPets
            ? strings.addFirstPet
            : section == AllPetsCareSection.pets
            ? strings.addPet
            : switch (section) {
                AllPetsCareSection.vetVisits => strings.addVisit,
                AllPetsCareSection.vaccinations => strings.addVaccination,
                _ => strings.addMedication,
              };
        final loading =
            data.isLoading ||
            state.isBusy ||
            section == AllPetsCareSection.medications && state.doses.isLoading;
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
                    onPressed: state.isBusy
                        ? null
                        : () {
                            if (!_cubit.state.isBusy && _visible) {
                              context.push(AppRoutes.settings);
                            }
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
                section != AllPetsCareSection.feeding &&
                    data.hasLoaded &&
                    state.pets.hasLoaded &&
                    (section != AllPetsCareSection.medications ||
                        _catalog ||
                        state.visibleMedications.isEmpty ||
                        noPets)
                ? FloatingActionButton.extended(
                    tooltip: addLabel,
                    isExtended:
                        MediaQuery.textScalerOf(context).scale(14) <= 21,
                    onPressed: state.isBusy ? null : _add,
                    icon: const Icon(Icons.add),
                    label: Text(addLabel),
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
                              section != AllPetsCareSection.pets)
                            Flexible(
                              child: AppErrorFeedback(
                                message: AppLocalizations.of(
                                  context,
                                ).petNamesRefreshFailed,
                                retryLabel: AppLocalizations.of(
                                  context,
                                ).retryPets,
                                onRetry: state.isBusy ? null : _cubit.loadPets,
                              ),
                            ),
                          if (state.actionError != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: switch (state.failedAction) {
                                  DeleteGlobalVetVisit() =>
                                    strings.visitDeleteFailed,
                                  DeleteGlobalVaccination() =>
                                    strings.vaccinationDeleteFailed,
                                  ClearGlobalDose() => strings.doseClearFailed,
                                  SaveGlobalDose() => strings.doseSaveFailed,
                                  _ => strings.somethingWentWrong,
                                },
                                retryLabel:
                                    state.failedAction is GlobalDoseAction
                                    ? AppLocalizations.of(
                                        context,
                                      ).retryDoseRecord
                                    : AppLocalizations.of(
                                        context,
                                      ).retryDeletion,
                                onRetry: state.isBusy
                                    ? null
                                    : () {
                                        final action =
                                            _cubit.state.failedAction;
                                        if (action != null) _perform(action);
                                      },
                              ),
                            ),
                          if (data.hasLoaded && data.error != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: _loadErrorMessage(section),
                                onRetry: state.isBusy
                                    ? null
                                    : _cubit.refreshActive,
                              ),
                            ),
                          if (section == AllPetsCareSection.medications &&
                              !_catalog &&
                              state.doses.error != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: strings.doseLoadFailed,
                                retryLabel: AppLocalizations.of(
                                  context,
                                ).retryDoseRecords,
                                onRetry: state.isBusy
                                    ? null
                                    : () => _cubit.loadDoses(state.doseDate),
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
                  if (loading)
                    Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        semanticsLabel: AppLocalizations.of(
                          context,
                        ).updatingCareRecords,
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
