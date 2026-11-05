import 'package:petlytics/core/error/failure.dart';
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
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/presentation/widgets/vet_visit_list_content.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:petlytics/features/vet_visit/presentation/utils/confirm_vet_visit_deletion.dart';

class VetVisitListPage extends StatelessWidget {
  final String petId;
  final String? petName;

  const VetVisitListPage({super.key, required this.petId, this.petName});

  Future<void> _addVisit(BuildContext context) async {
    final saved = await context.push<bool>(
      AppRoutes.addEditVetVisit(petId),
      extra: VetVisitFormExtra(petId: petId, petName: petName),
    );
    if (!context.mounted || PetCareChanges.maybeOf(context) != null) return;
    if (saved == true) {
      await context.read<VetVisitCubit>().loadVetVisits(petId);
    }
  }

  Future<void> _openVisit(BuildContext context, VetVisit visit) async {
    final deletedId = await context.push<String>(
      AppRoutes.vetVisitDetail(petId, visit.id),
      extra: PetCareRouteExtra(petId: petId, petName: petName),
    );
    if (!context.mounted || PetCareChanges.maybeOf(context) != null) return;
    final cubit = context.read<VetVisitCubit>();
    if (deletedId != null) {
      cubit.removeDeletedVisit(deletedId);
    } else {
      await cubit.loadVetVisits(petId);
    }
  }

  Future<void> _delete(BuildContext context, VetVisit visit) async {
    final confirmed = await confirmVetVisitDeletion(context, visit);
    if (confirmed && context.mounted) {
      await context.read<VetVisitCubit>().deleteListedVisit(visit);
      if (!context.mounted) return;
      if (context.read<VetVisitCubit>().state
          case VetVisitsLoaded(:final visits)
          when !visits.any((item) => item.id == visit.id)) {
        PetCareChanges.recordChanged(
          context,
          petId,
          PetCareTab.vetVisits,
          listIsCurrent: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VetVisitCubit, VetVisitState>(
      builder: (context, state) {
        final deleting = state is VetVisitsLoaded && state.isDeleting;
        final busy =
            state is VetVisitsLoaded &&
            (state.isRefreshing || state.isDeleting);
        return PopScope(
          canPop: !deleting,
          child: Scaffold(
            appBar: petCareAppBar(
              context,
              title: PetCareTitle(
                title: AppLocalizations.of(context).vetVisitsNavigation,
                petName: petName,
              ),
              toolbarHeight: PetCareTitle.toolbarHeight(context),
              busy: deleting,
              progress: busy
                  ? LinearProgressIndicator(
                      semanticsLabel: AppLocalizations.of(context)
                          .updatingVisits,
                    )
                  : null,
            ),
            floatingActionButton: state is VetVisitsLoaded
                ? FloatingActionButton.extended(
                    isExtended:
                        MediaQuery.textScalerOf(context).scale(14) <= 21,
                    tooltip: AppLocalizations.of(context).addVisit,
                    onPressed: busy ? null : () => _addVisit(context),
                    icon: const Icon(Icons.add),
                    label: Text(AppLocalizations.of(context).addVisit),
                  )
                : null,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: switch (state) {
                    VetVisitsLoaded(
                      :final visits,
                      :final refreshError,
                      :final deleteError,
                      :final deletionVisit,
                    ) =>
                      Column(
                        children: [
                          if (deleteError != null && deletionVisit != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: AppLocalizations.of(context)
                                    .visitDeleteFailed,
                                retryLabel: AppLocalizations.of(context)
                                    .retryDeletion,
                                onRetry: () => _delete(context, deletionVisit),
                              ),
                            )
                          else if (refreshError != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: AppLocalizations.of(context)
                                    .visitsLoadFailed,
                                retryLabel: AppLocalizations.of(context).retry,
                                onRetry: () => context
                                    .read<VetVisitCubit>()
                                    .loadVetVisits(petId),
                              ),
                            ),
                          Expanded(
                            child: VetVisitListContent(
                              visits: visits,
                              isDeleting: (visit) =>
                                  deleting && deletionVisit?.id == visit.id,
                              onOpen: busy
                                  ? null
                                  : (visit) => _openVisit(context, visit),
                              onDelete: busy
                                  ? null
                                  : (visit) => _delete(context, visit),
                            ),
                          ),
                        ],
                      ),
                    VetVisitError(:final failure) => ErrorView(
                      message: failure is NotFoundFailure
                          ? AppLocalizations.of(context).visitNotFound
                          : AppLocalizations.of(context).visitsLoadFailed,
                      onRetry: () =>
                          context.read<VetVisitCubit>().loadVetVisits(petId),
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
