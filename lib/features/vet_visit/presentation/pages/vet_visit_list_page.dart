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
import 'package:patilog/core/widgets/care_record_card.dart';
import 'package:patilog/core/widgets/error_view.dart';
import 'package:patilog/core/widgets/pet_care_tabs.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:patilog/features/vet_visit/presentation/utils/confirm_vet_visit_deletion.dart';
import 'package:patilog/features/vet_visit/presentation/widgets/vet_visit_list_content.dart';

import 'package:patilog/l10n/generated/app_localizations.dart';

class VetVisitListPage extends StatefulWidget {
  final String? petId;
  final String? petName;
  final List<Pet> pets;
  final bool petsLoaded;

  const VetVisitListPage({
    super.key,
    this.petId,
    this.petName,
    this.pets = const [],
    this.petsLoaded = true,
  });
  @override
  State<VetVisitListPage> createState() => _VetVisitListPageState();
}

class _VetVisitListPageState extends State<VetVisitListPage> {
  String? _selectedPetId;
  bool _confirming = false;
  bool get _global => widget.petId == null;
  VetVisitCubit get _cubit => context.read<VetVisitCubit>();
  Map<String, Pet> get _petsById => {
    for (final pet in widget.pets) pet.id: pet,
  };
  String? get _filterId =>
      _petsById.containsKey(_selectedPetId) ? _selectedPetId : null;
  String? _name(String id) => _global ? _petsById[id]?.name : widget.petName;
  bool get _busy =>
      _confirming ||
      switch (_cubit.state) {
        VetVisitsLoaded(:final isDeleting, :final isRefreshing) =>
          isDeleting || isRefreshing,
        _ => false,
      };

  Future<void> _reload() =>
      _global ? _cubit.loadAllVetVisits() : _cubit.loadVetVisits(widget.petId!);

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
      AppRoutes.addEditVetVisit(id),
      extra: VetVisitFormExtra(petId: id, petName: _name(id)),
    );
    if (!mounted || _global || PetCareChanges.maybeOf(context) != null) return;
    if (saved == true) await _reload();
  }

  Future<void> _open(VetVisit record) async {
    if (_confirming ||
        _cubit.state is VetVisitsLoaded &&
            (_cubit.state as VetVisitsLoaded).isDeleting ||
        _global && !_petsById.containsKey(record.petId)) {
      return;
    }
    final deletedId = await context.push<String>(
      AppRoutes.vetVisitDetail(record.petId, record.id),
      extra: PetCareRouteExtra(
        petId: record.petId,
        petName: _name(record.petId),
      ),
    );
    if (!mounted || _global || PetCareChanges.maybeOf(context) != null) return;
    if (deletedId != null) {
      _cubit.removeDeletedVisit(deletedId);
    } else {
      await _reload();
    }
  }

  Future<void> _delete(VetVisit record) async {
    if (_busy || _global && !_petsById.containsKey(record.petId)) return;
    setState(() => _confirming = true);
    final confirmed = await confirmVetVisitDeletion(
      context,
      record,
      petName: _global ? _name(record.petId) : null,
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (!confirmed) return;
    await _cubit.deleteListedVisit(record);
    if (!mounted) return;
    if (_cubit.state
        case VetVisitsLoaded(
          :final visits,
          deleteError: null,
          isDeleting: false,
        )
        when !visits.any(
          (item) => item.id == record.id && item.petId == record.petId,
        )) {
      if (_global) {
        CareRecordChanges.maybeOf(context)?.changed(
          record.petId,
          PetCareTab.vetVisits,
          deletedId: record.id,
          globalListIsCurrent: true,
        );
      } else {
        PetCareChanges.recordChanged(
          context,
          record.petId,
          PetCareTab.vetVisits,
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

  Widget _loaded(VetVisitsLoaded state) {
    final busy = _busy;
    final strings = AppLocalizations.of(context);
    final records = state.visits
        .where(
          (record) =>
              !_global || _filterId == null || record.petId == _filterId,
        )
        .toList();
    return Column(
      children: [
        if (state.deleteError != null && state.deletionVisit != null)
          Flexible(
            child: AppErrorFeedback(
              message: strings.visitDeleteFailed,
              retryLabel: strings.retryDeletion,
              onRetry: busy ? null : () => _delete(state.deletionVisit!),
            ),
          )
        else if (state.refreshError != null)
          Flexible(
            child: AppErrorFeedback(
              message: strings.visitsLoadFailed,
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
              : VetVisitListContent(
                  visits: records,
                  petsById: _global ? _petsById : null,
                  header: _global ? _filter(busy) : null,
                  isDeleting: (record) =>
                      state.isDeleting && state.deletionVisit?.id == record.id,
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
    return BlocBuilder<VetVisitCubit, VetVisitState>(
      builder: (context, state) {
        final strings = AppLocalizations.of(context);
        final deleting =
            _confirming || state is VetVisitsLoaded && state.isDeleting;
        final busy = _busy;
        final addLabel = _global && widget.pets.isEmpty
            ? strings.addFirstPet
            : strings.addVisit;
        return PopScope(
          canPop: !deleting,
          child: Scaffold(
            appBar: _global
                ? null
                : petCareAppBar(
                    context,
                    title: PetCareTitle(
                      title: strings.vetVisitsNavigation,
                      petName: widget.petName,
                    ),
                    toolbarHeight: PetCareTitle.toolbarHeight(context),
                    busy: deleting,
                    progress: busy
                        ? LinearProgressIndicator(
                            semanticsLabel: strings.updatingVisits,
                          )
                        : null,
                  ),
            floatingActionButton:
                state is VetVisitsLoaded && (!_global || widget.petsLoaded)
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
                    VetVisitsLoaded() => _loaded(state),
                    VetVisitError(:final failure) => ErrorView(
                      message: failure is NotFoundFailure
                          ? strings.visitNotFound
                          : strings.visitsLoadFailed,
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
