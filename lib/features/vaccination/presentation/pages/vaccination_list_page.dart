import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_pet_filter.dart';
import 'package:petlytics/core/widgets/app_pet_picker.dart';
import 'package:petlytics/core/widgets/care_record_card.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/core/widgets/pet_care_tabs.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:petlytics/features/vaccination/presentation/utils/confirm_vaccination_deletion.dart';
import 'package:petlytics/features/vaccination/presentation/widgets/vaccination_list_content.dart';
import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

class VaccinationListPage extends StatefulWidget {
  final String? petId;
  final String? petName;
  final List<Pet> pets;
  final bool petsLoaded;

  const VaccinationListPage({
    super.key,
    this.petId,
    this.petName,
    this.pets = const [],
    this.petsLoaded = true,
  });
  @override
  State<VaccinationListPage> createState() => _VaccinationListPageState();
}

class _VaccinationListPageState extends State<VaccinationListPage> {
  String? _selectedPetId;
  bool _confirming = false;
  bool get _global => widget.petId == null;
  VaccinationCubit get _cubit => context.read<VaccinationCubit>();
  Map<String, Pet> get _petsById => {
    for (final pet in widget.pets) pet.id: pet,
  };
  String? get _filterId =>
      _petsById.containsKey(_selectedPetId) ? _selectedPetId : null;
  String? _name(String id) => _global ? _petsById[id]?.name : widget.petName;
  bool get _busy =>
      _confirming ||
      switch (_cubit.state) {
        VaccinationsLoaded(:final isDeleting, :final isRefreshing) =>
          isDeleting || isRefreshing,
        _ => false,
      };

  Future<void> _reload() => _global
      ? _cubit.loadAllVaccinations()
      : _cubit.loadVaccinations(widget.petId!);

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
      AppRoutes.addEditVaccination(id),
      extra: VaccinationFormExtra(petId: id, petName: _name(id)),
    );
    if (!mounted || _global || PetCareChanges.maybeOf(context) != null) return;
    if (saved == true) await _reload();
  }

  Future<void> _open(Vaccination record) async {
    if (_confirming ||
        _cubit.state is VaccinationsLoaded &&
            (_cubit.state as VaccinationsLoaded).isDeleting ||
        _global && !_petsById.containsKey(record.petId)) {
      return;
    }
    final deletedId = await context.push<String>(
      AppRoutes.vaccinationDetail(record.petId, record.id),
      extra: PetCareRouteExtra(
        petId: record.petId,
        petName: _name(record.petId),
      ),
    );
    if (!mounted || _global || PetCareChanges.maybeOf(context) != null) return;
    if (deletedId != null) {
      _cubit.removeDeletedVaccination(deletedId);
    } else {
      await _reload();
    }
  }

  Future<void> _delete(Vaccination record) async {
    if (_busy || _global && !_petsById.containsKey(record.petId)) return;
    setState(() => _confirming = true);
    final confirmed = await confirmVaccinationDeletion(
      context,
      record,
      petName: _global ? _name(record.petId) : null,
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (!confirmed) return;
    await _cubit.deleteListedVaccination(record);
    if (!mounted) return;
    if (_cubit.state
        case VaccinationsLoaded(
          :final vaccinations,
          deleteError: null,
          isDeleting: false,
        )
        when !vaccinations.any(
          (item) => item.id == record.id && item.petId == record.petId,
        )) {
      if (_global) {
        CareRecordChanges.maybeOf(context)?.changed(
          record.petId,
          PetCareTab.vaccinations,
          deletedId: record.id,
          globalListIsCurrent: true,
        );
      } else {
        PetCareChanges.recordChanged(
          context,
          record.petId,
          PetCareTab.vaccinations,
          deletedId: record.id,
          listIsCurrent: true,
        );
      }
    }
  }

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
                      _cubit.dismissDeletionError();
                      setState(() => _selectedPetId = id);
                    }
                  },
          ),
        );

  List<({String title, IconData icon, List<Vaccination> records})> _groups(
    List<Vaccination> records,
  ) {
    final strings = AppLocalizations.of(context);
    final today = calendarDayNumber(_cubit.now());
    List<Vaccination> planned(bool Function(int) test) => records
        .where(
          (v) =>
              v.status == VaccinationStatus.planned &&
              test(calendarDayNumber(v.date)),
        )
        .toList();
    return [
      if (_global) ...[
        (
          title: strings.overdue,
          icon: Icons.event_busy_outlined,
          records: planned((day) => day < today),
        ),
        (
          title: strings.today,
          icon: Icons.today_outlined,
          records: planned((day) => day == today),
        ),
        (
          title: strings.upcoming,
          icon: Icons.event_outlined,
          records: planned((day) => day > today),
        ),
      ] else
        (
          title: strings.planned,
          icon: Icons.event_outlined,
          records: planned((_) => true),
        ),
      (
        title: strings.history,
        icon: Icons.history,
        records: records
            .where((v) => v.status == VaccinationStatus.administered)
            .toList(),
      ),
    ];
  }

  Widget _loaded(VaccinationsLoaded state) {
    final busy = _busy;
    final strings = AppLocalizations.of(context);
    final records = state.vaccinations
        .where(
          (record) =>
              !_global || _filterId == null || record.petId == _filterId,
        )
        .toList();
    return Column(
      children: [
        if (state.deleteError != null && state.deletionVaccination != null)
          Flexible(
            child: AppErrorFeedback(
              message: strings.vaccinationDeleteFailed,
              retryLabel: strings.retryDeletion,
              onRetry: busy ? null : () => _delete(state.deletionVaccination!),
            ),
          )
        else if (state.refreshError != null)
          Flexible(
            child: AppErrorFeedback(
              message: strings.vaccinationsLoadFailed,
              retryLabel: strings.retry,
              onRetry: busy ? null : _reload,
            ),
          ),
        Expanded(
          child: _global && widget.petsLoaded && widget.pets.isEmpty
              ? CareEmptyView(
                  icon: Icons.pets_outlined,
                  title: strings.noPetsYet,
                  message: strings.petsEmptyDescription,
                )
              : VaccinationListContent(
                  groups: _groups(records),
                  petsById: _global ? _petsById : null,
                  header: _global ? _filter(busy) : null,
                  isDeleting: (record) =>
                      state.isDeleting &&
                      state.deletionVaccination?.id == record.id,
                  onOpen: state.isDeleting || !_global && state.isRefreshing
                      ? null
                      : _open,
                  onDelete: busy ? null : _delete,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_global) {
      _cubit.setPetContext(
        widget.pets.map((p) => p.id),
        selectedPetId: _filterId,
      );
    }
    return BlocBuilder<VaccinationCubit, VaccinationState>(
      builder: (context, state) {
        final strings = AppLocalizations.of(context);
        final deleting =
            _confirming || state is VaccinationsLoaded && state.isDeleting;
        final busy = _busy;
        final addLabel = _global && widget.pets.isEmpty
            ? strings.addFirstPet
            : strings.addVaccination;
        return PopScope(
          canPop: !deleting,
          child: Scaffold(
            appBar: _global
                ? null
                : petCareAppBar(
                    context,
                    title: PetCareTitle(
                      title: strings.vaccinations,
                      petName: widget.petName,
                    ),
                    toolbarHeight: PetCareTitle.toolbarHeight(context),
                    busy: deleting,
                    progress: busy
                        ? LinearProgressIndicator(
                            semanticsLabel: strings.updatingVaccinations,
                          )
                        : null,
                  ),
            floatingActionButton:
                state is VaccinationsLoaded && (!_global || widget.petsLoaded)
                ? FloatingActionButton.extended(
                    isExtended:
                        MediaQuery.textScalerOf(context).scale(14) <= 21,
                    tooltip: addLabel,
                    onPressed: busy ? null : _add,
                    icon: const Icon(Icons.add),
                    label: Text(addLabel),
                  )
                : null,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: switch (state) {
                    VaccinationsLoaded() => _loaded(state),
                    VaccinationError(:final failure) => ErrorView(
                      message: failure is NotFoundFailure
                          ? strings.vaccinationNotFound
                          : strings.vaccinationsLoadFailed,
                      onRetry: _reload,
                    ),
                    _ => const Center(child: CircularProgressIndicator()),
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
