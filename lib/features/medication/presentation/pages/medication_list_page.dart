import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/router/care_record_changes.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_route_extra.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/core/widgets/app_pet_filter.dart';
import 'package:patilog/core/widgets/app_pet_picker.dart';
import 'package:patilog/core/widgets/app_view_selector.dart';
import 'package:patilog/core/widgets/care_record_card.dart';
import 'package:patilog/core/widgets/error_view.dart';
import 'package:patilog/core/widgets/pet_care_tabs.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';
import 'package:patilog/features/medication/presentation/utils/medication_actions.dart';
import 'package:patilog/features/medication/presentation/utils/medication_display.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_clock.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_doses.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_list_content.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

class MedicationListPage extends StatefulWidget {
  final String? petId;
  final String? petName;
  final List<Pet> pets;
  final bool petsLoaded;
  final bool active;
  const MedicationListPage({
    super.key,
    this.petId,
    this.petName,
    this.pets = const [],
    this.petsLoaded = true,
    this.active = true,
  });
  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  int _tab = 0;
  String? _selectedPetId;
  bool _dosePanelOpen = false;
  bool get _global => widget.petId == null;
  MedicationCubit get _cubit => context.read<MedicationCubit>();
  Map<String, Pet> get _petsById => {
    for (final pet in widget.pets) pet.id: pet,
  };
  String? get _filterId =>
      _petsById.containsKey(_selectedPetId) ? _selectedPetId : null;
  String? _name(String id) => _global ? _petsById[id]?.name : widget.petName;
  bool get _busy =>
      _cubit.state is MedicationsLoaded &&
      (_cubit.state as MedicationsLoaded).pendingAction != null;
  Future<void> _reload() => _global
      ? _cubit.loadAllMedications()
      : _cubit.loadMedications(widget.petId!);

  Future<void> _add() async {
    if (_busy) return;
    if (_global && widget.pets.isEmpty) {
      await context.push(AppRoutes.addEditPet);
      return;
    }
    final pet = _global
        ? await pickCarePet(context, widget.pets, selectedPetId: _filterId)
        : null;
    if (!mounted ||
        _busy ||
        _global && (pet == null || !_petsById.containsKey(pet.id))) {
      return;
    }
    final id = widget.petId ?? pet!.id;
    final saved = await context.push<bool>(
      AppRoutes.addEditMedication(id),
      extra: MedicationFormExtra(petId: id, petName: _name(id)),
    );
    if (!mounted || _global || PetCareChanges.maybeOf(context) != null) return;
    if (saved == true) await _reload();
  }

  Future<void> _open(Medication medication) async {
    if (_busy || _global && !_petsById.containsKey(medication.petId)) return;
    final deleted = await context.push<String>(
      AppRoutes.medicationDetail(medication.petId, medication.id),
      extra: PetCareRouteExtra(
        petId: medication.petId,
        petName: _name(medication.petId),
      ),
    );
    if (!mounted || _global || PetCareChanges.maybeOf(context) != null) return;
    if (deleted != null) {
      _cubit.removeDeletedMedication(deleted);
    } else {
      await _reload();
    }
  }

  void _publish(MedicationsLoaded state) {
    final mutation = state.lastMutation;
    if (mutation == null) return;
    final deletedId = mutation.action is DeleteMedicationAction
        ? mutation.action.medicationId
        : null;
    if (_global) {
      CareRecordChanges.maybeOf(context)?.changed(
        mutation.petId,
        PetCareTab.medications,
        deletedId: deletedId,
        globalListIsCurrent: true,
      );
    } else {
      PetCareChanges.recordChanged(
        context,
        mutation.petId,
        PetCareTab.medications,
        deletedId: deletedId,
        listIsCurrent: true,
      );
    }
  }

  Future<void> _record(MedicationDose dose) async {
    setState(() => _dosePanelOpen = true);
    try {
      await showMedicationDoseSheet(
        context,
        dose,
        editor: MedicationDoseEditor.forCubit(context, dose),
        petIdentity: _global
            ? CarePetIdentity(pet: _petsById[dose.medication.petId])
            : null,
      );
    } finally {
      if (mounted) setState(() => _dosePanelOpen = false);
    }
  }

  Widget _empty(
    String title,
    String explanation, {
    String? action,
    VoidCallback? onAction,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(explanation, textAlign: TextAlign.center),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(onPressed: onAction, child: Text(action)),
            ),
        ],
      ),
    ),
  );

  Widget _selector(bool busy) => Padding(
    padding: EdgeInsets.fromLTRB(24, _global ? 8 : 16, 24, 8),
    child: AppViewSelector(
      labels: [
        AppLocalizations.of(context).doses,
        AppLocalizations.of(context).medications,
      ],
      selectedIndex: _tab,
      onSelected: busy
          ? null
          : (index) {
              if (!_busy) setState(() => _tab = index);
            },
    ),
  );

  Widget _filter(bool busy) => widget.pets.length < 2
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: AppPetFilter(
            key: ValueKey(_filterId),
            pets: widget.pets,
            selectedPetId: _filterId,
            onChanged: busy
                ? null
                : (id) {
                    if (!_busy) {
                      _cubit.dismissActionError();
                      setState(() => _selectedPetId = id);
                    }
                  },
          ),
        );

  Widget _doses(MedicationsLoaded state, {Widget? header}) {
    final busy = _busy || state.isRefreshing;
    final list = MedicationDoseListContent(
      doses: state.doses.doses
          .where(
            (d) =>
                !_global ||
                _filterId == null ||
                d.medication.petId == _filterId,
          )
          .toList(),
      known:
          state.doses.hasLoaded &&
          !state.doses.isLoading &&
          state.doses.error == null &&
          !state.isRefreshing &&
          (!_global || state.refreshError == null),
      loading: state.doses.isLoading,
      busy: busy,
      petsById: _global ? _petsById : null,
      onRecord: _record,
      header: header,
      empty: state.doses.isLoading && !state.doses.hasLoaded
          ? const Center(child: CircularProgressIndicator())
          : _global
          ? CareEmptyView(
              icon: Icons.schedule_outlined,
              title: AppLocalizations.of(context).noDoses,
              message: AppLocalizations.of(context).allPetsNoDayDoses,
            )
          : _empty(
              AppLocalizations.of(context).noDoses,
              AppLocalizations.of(context).noDosesForDay,
              action: AppLocalizations.of(context).viewMedications,
              onAction: () => setState(() => _tab = 1),
            ),
    );
    return _global
        ? list
        : Column(
            children: [
              MedicationDateSelector(
                date: state.doses.date,
                now: _cubit.now,
                onChanged: busy ? null : _cubit.loadDoses,
              ),
              Expanded(child: list),
            ],
          );
  }

  Widget _records(MedicationsLoaded state) {
    final busy = _busy || state.isRefreshing;
    final header = _global
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filter(busy),
              _selector(_busy),
              if (_tab == 0)
                MedicationDateSelector(
                  date: state.doses.date,
                  now: _cubit.now,
                  compact: true,
                  onChanged: busy ? null : _cubit.loadDoses,
                ),
            ],
          )
        : null;
    return _tab == 0
        ? _doses(state, header: header)
        : MedicationCatalogContent(
            medications: state.medications
                .where(
                  (m) => !_global || _filterId == null || m.petId == _filterId,
                )
                .toList(),
            currentTime: state.currentTime,
            petsById: _global ? _petsById : null,
            header: header,
            onOpen: _busy || !_global && state.isRefreshing ? null : _open,
          );
  }

  @override
  Widget build(BuildContext context) {
    if (_global) {
      _cubit.setPetContext(
        widget.pets.map((p) => p.id),
        selectedPetId: _filterId,
        active: widget.active,
      );
    }
    final active =
        !_dosePanelOpen &&
        (_global
            ? widget.active
            : PetCareTabs.maybeOf(context) == null ||
                  PetCareTabs.maybeOf(context)?.active ==
                      PetCareTab.medications);
    return MedicationClock(
      active: active,
      onResume: _reload,
      child: BlocConsumer<MedicationCubit, MedicationState>(
        listenWhen: (previous, current) =>
            current is MedicationsLoaded &&
            current.mutationRevision >
                (previous is MedicationsLoaded ? previous.mutationRevision : 0),
        listener: (_, state) => _publish(state as MedicationsLoaded),
        builder: (context, state) {
          final strings = AppLocalizations.of(context);
          final loaded = state is MedicationsLoaded ? state : null;
          final busy = loaded?.pendingAction != null;
          final noPets = _global && widget.petsLoaded && widget.pets.isEmpty;
          final visibleEmpty =
              loaded?.medications
                  .where(
                    (m) =>
                        !_global || _filterId == null || m.petId == _filterId,
                  )
                  .isEmpty ==
              true;
          final label = noPets ? strings.addFirstPet : strings.addMedication;
          return PopScope(
            canPop: !busy,
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: _global
                  ? null
                  : petCareAppBar(
                      context,
                      title: PetCareTitle(
                        title: strings.medications,
                        petName: widget.petName,
                      ),
                      toolbarHeight: PetCareTitle.toolbarHeight(context),
                      busy: busy,
                      progress:
                          loaded?.isRefreshing == true ||
                              loaded?.doses.isLoading == true ||
                              busy
                          ? LinearProgressIndicator(
                              semanticsLabel: strings.updatingMedications,
                            )
                          : null,
                    ),
              floatingActionButton:
                  loaded != null &&
                      (!_global || widget.petsLoaded) &&
                      (_tab == 1 || visibleEmpty || noPets)
                  ? FloatingActionButton.extended(
                      isExtended:
                          MediaQuery.textScalerOf(context).scale(14) <= 21,
                      onPressed: busy || loaded.isRefreshing ? null : _add,
                      icon: const Icon(Icons.add),
                      tooltip: label,
                      label: Text(label),
                    )
                  : null,
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: loaded == null
                        ? state is MedicationError
                              ? ErrorView(
                                  message: state.failure is NotFoundFailure
                                      ? strings.medicationNotFound
                                      : strings.medicationsLoadFailed,
                                  onRetry: _reload,
                                )
                              : const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              if (loaded.actionError != null ||
                                  loaded.refreshError != null)
                                Flexible(
                                  child: AppErrorFeedback(
                                    message: loaded.actionError != null
                                        ? medicationActionError(
                                            strings,
                                            loaded.failedAction,
                                          )
                                        : strings.medicationsLoadFailed,
                                    retryLabel: loaded.failedAction != null
                                        ? (_global
                                              ? strings.retryDoseRecord
                                              : strings.retryAction)
                                        : strings.retry,
                                    onRetry: busy
                                        ? null
                                        : () {
                                            final action = loaded.failedAction;
                                            if (action != null) {
                                              performMedicationAction(
                                                context,
                                                _cubit,
                                                action,
                                              );
                                            } else {
                                              _reload();
                                            }
                                          },
                                  ),
                                ),
                              if (_tab == 0 && loaded.doses.error != null)
                                Flexible(
                                  child: AppErrorFeedback(
                                    message: strings.doseLoadFailed,
                                    retryLabel: strings.retryDoseRecords,
                                    onRetry: busy
                                        ? null
                                        : () => _cubit.loadDoses(
                                            loaded.doses.date,
                                          ),
                                  ),
                                ),
                              if (!_global) _selector(busy),
                              Expanded(
                                child: noPets
                                    ? CareEmptyView(
                                        icon: Icons.pets_outlined,
                                        title: strings.noPetsYet,
                                        message: strings.petsEmptyDescription,
                                      )
                                    : !_global && loaded.medications.isEmpty
                                    ? _empty(
                                        strings.noMedications,
                                        strings.medicationsEmpty,
                                      )
                                    : _records(loaded),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
