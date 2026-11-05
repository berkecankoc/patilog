import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/widgets/app_view_selector.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:petlytics/core/widgets/pet_care_tabs.dart';
import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_actions.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_display.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_clock.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_list_content.dart';

class MedicationListPage extends StatefulWidget {
  final String petId;
  final String? petName;
  const MedicationListPage({super.key, required this.petId, this.petName});
  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  int _tab = 0;
  Future<void> _reload() =>
      context.read<MedicationCubit>().loadMedications(widget.petId);
  Future<void> _add() async {
    final saved = await context.push<bool>(
      AppRoutes.addEditMedication(widget.petId),
      extra: MedicationFormExtra(petId: widget.petId, petName: widget.petName),
    );
    if (mounted && PetCareChanges.maybeOf(context) == null) {
      if (saved == true) await _reload();
    }
  }

  Future<void> _open(Medication medication) async {
    final deleted = await context.push<String>(
      AppRoutes.medicationDetail(widget.petId, medication.id),
      extra: PetCareRouteExtra(petId: widget.petId, petName: widget.petName),
    );
    if (!mounted || PetCareChanges.maybeOf(context) != null) return;
    if (deleted != null) {
      context.read<MedicationCubit>().removeDeletedMedication(deleted);
    } else {
      await _reload();
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

  Widget _doses(MedicationsLoaded state) {
    final cubit = context.read<MedicationCubit>();
    final busy = state.pendingAction != null || state.isRefreshing;
    final date = state.doses.date;
    return Column(
      children: [
        MedicationDateSelector(
          date: date,
          now: cubit.now,
          onChanged: busy ? null : cubit.loadDoses,
        ),
        if (state.doses.error != null)
          Flexible(
            child: AppErrorFeedback(
              message: AppLocalizations.of(context).doseLoadFailed,
              retryLabel: AppLocalizations.of(context).retryDoseRecords,
              onRetry: () => cubit.loadDoses(date),
            ),
          ),
        Expanded(
          child: MedicationDoseListContent(
            doses: state.doses.doses,
            known: state.doses.hasLoaded && !state.doses.isLoading,
            loading: state.doses.isLoading,
            busy: busy,
            empty: state.doses.isLoading && !state.doses.hasLoaded
                ? const Center(child: CircularProgressIndicator())
                : _empty(
                    AppLocalizations.of(context).noDoses,
                    AppLocalizations.of(context).noDosesForDay,
                    action: AppLocalizations.of(context).viewMedications,
                    onAction: () => setState(() => _tab = 1),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _catalog(MedicationsLoaded state) => MedicationCatalogContent(
    medications: state.medications,
    currentTime: state.currentTime,
    onOpen: state.pendingAction != null || state.isRefreshing ? null : _open,
  );

  @override
  Widget build(BuildContext context) => MedicationClock(
    active: PetCareTabs.maybeOf(context)?.active == PetCareTab.medications,
    onResume: _reload,
    child: BlocBuilder<MedicationCubit, MedicationState>(
      builder: (context, state) {
        final loaded = state is MedicationsLoaded ? state : null;
        final busy = loaded?.pendingAction != null;
        return PopScope(
          canPop: !busy,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: petCareAppBar(
              context,
              title: PetCareTitle(
                title: AppLocalizations.of(context).medications,
                petName: widget.petName,
              ),
              toolbarHeight: PetCareTitle.toolbarHeight(context),
              busy: busy,
              progress:
                  loaded?.isRefreshing == true ||
                      loaded?.doses.isLoading == true ||
                      busy
                  ? LinearProgressIndicator(
                      semanticsLabel: AppLocalizations.of(context)
                          .updatingMedications,
                    )
                  : null,
            ),
            floatingActionButton:
                loaded != null && (_tab == 1 || loaded.medications.isEmpty)
                ? FloatingActionButton.extended(
                    isExtended:
                        MediaQuery.textScalerOf(context).scale(14) <= 21,
                    onPressed: busy || loaded.isRefreshing ? null : _add,
                    icon: const Icon(Icons.add),
                    tooltip: AppLocalizations.of(context).addMedication,
                    label: Text(AppLocalizations.of(context).addMedication),
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
                                    ? AppLocalizations.of(context)
                                          .medicationNotFound
                                    : AppLocalizations.of(context)
                                          .medicationsLoadFailed,
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
                                          AppLocalizations.of(context),
                                          loaded.failedAction,
                                        )
                                      : AppLocalizations.of(context)
                                            .medicationsLoadFailed,
                                  retryLabel: loaded.failedAction != null
                                      ? AppLocalizations.of(context).retryAction
                                      : AppLocalizations.of(context).retry,
                                  onRetry: () {
                                    final action = loaded.failedAction;
                                    if (action != null) {
                                      performMedicationAction(
                                        context,
                                        context.read<MedicationCubit>(),
                                        action,
                                      );
                                    } else {
                                      _reload();
                                    }
                                  },
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                              child: AppViewSelector(
                                labels: [
                                  AppLocalizations.of(context).doses,
                                  AppLocalizations.of(context).medications,
                                ],
                                selectedIndex: _tab,
                                onSelected: busy
                                    ? null
                                    : (index) {
                                        final current = context
                                            .read<MedicationCubit>()
                                            .state;
                                        if (current is MedicationsLoaded &&
                                            current.pendingAction == null) {
                                          setState(() => _tab = index);
                                        }
                                      },
                              ),
                            ),
                            Expanded(
                              child: loaded.medications.isEmpty
                                  ? _empty(
                                      AppLocalizations.of(context)
                                          .noMedications,
                                      AppLocalizations.of(context)
                                          .medicationsEmpty,
                                    )
                                  : _tab == 0
                                  ? _doses(loaded)
                                  : _catalog(loaded),
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
