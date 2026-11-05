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
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/widgets/vaccination_list_content.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:petlytics/features/vaccination/presentation/utils/confirm_vaccination_deletion.dart';

class VaccinationListPage extends StatelessWidget {
  final String petId;
  final String? petName;

  const VaccinationListPage({super.key, required this.petId, this.petName});

  Future<void> _add(BuildContext context) async {
    final saved = await context.push<bool>(
      AppRoutes.addEditVaccination(petId),
      extra: VaccinationFormExtra(petId: petId, petName: petName),
    );
    if (!context.mounted || PetCareChanges.maybeOf(context) != null) return;
    if (saved == true) {
      await context.read<VaccinationCubit>().loadVaccinations(petId);
    }
  }

  Future<void> _open(BuildContext context, Vaccination vaccination) async {
    final deletedId = await context.push<String>(
      AppRoutes.vaccinationDetail(petId, vaccination.id),
      extra: PetCareRouteExtra(petId: petId, petName: petName),
    );
    if (!context.mounted || PetCareChanges.maybeOf(context) != null) return;
    final cubit = context.read<VaccinationCubit>();
    if (deletedId != null) {
      cubit.removeDeletedVaccination(deletedId);
    } else {
      await cubit.loadVaccinations(petId);
    }
  }

  Future<void> _delete(BuildContext context, Vaccination vaccination) async {
    final confirmed = await confirmVaccinationDeletion(context, vaccination);
    if (confirmed && context.mounted) {
      await context.read<VaccinationCubit>().deleteListedVaccination(
        vaccination,
      );
      if (!context.mounted) return;
      if (context.read<VaccinationCubit>().state
          case VaccinationsLoaded(:final vaccinations)
          when !vaccinations.any((item) => item.id == vaccination.id)) {
        PetCareChanges.recordChanged(
          context,
          petId,
          PetCareTab.vaccinations,
          listIsCurrent: true,
        );
      }
    }
  }

  Widget _loaded(BuildContext context, VaccinationsLoaded state) {
    final planned = state.vaccinations
        .where((v) => v.status == VaccinationStatus.planned)
        .toList();
    final history = state.vaccinations
        .where((v) => v.status == VaccinationStatus.administered)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (state.deleteError != null && state.deletionVaccination != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.75,
              ),
              child: AppErrorFeedback(
                message: AppLocalizations.of(context).vaccinationDeleteFailed,
                retryLabel: AppLocalizations.of(context).retryDeletion,
                onRetry: () => _delete(context, state.deletionVaccination!),
              ),
            )
          else if (state.refreshError != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.75,
              ),
              child: AppErrorFeedback(
                message: AppLocalizations.of(context).vaccinationsLoadFailed,
                retryLabel: AppLocalizations.of(context).retry,
                onRetry: () =>
                    context.read<VaccinationCubit>().loadVaccinations(petId),
              ),
            ),
          Expanded(
            child: VaccinationListContent(
              groups: [
                (
                  title: AppLocalizations.of(context).planned,
                  icon: Icons.event_outlined,
                  records: planned,
                ),
                (
                  title: AppLocalizations.of(context).history,
                  icon: Icons.history,
                  records: history,
                ),
              ],
              isDeleting: (vaccination) =>
                  state.isDeleting &&
                  state.deletionVaccination?.id == vaccination.id,
              onOpen: state.isDeleting || state.isRefreshing
                  ? null
                  : (vaccination) => _open(context, vaccination),
              onDelete: state.isDeleting || state.isRefreshing
                  ? null
                  : (vaccination) => _delete(context, vaccination),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<VaccinationCubit, VaccinationState>(
        builder: (context, state) {
          final deleting = state is VaccinationsLoaded && state.isDeleting;
          final busy =
              state is VaccinationsLoaded &&
              (state.isDeleting || state.isRefreshing);
          return PopScope(
            canPop: !deleting,
            child: Scaffold(
              appBar: petCareAppBar(
                context,
                title: PetCareTitle(
                  title: AppLocalizations.of(context).vaccinations,
                  petName: petName,
                ),
                toolbarHeight: PetCareTitle.toolbarHeight(context),
                busy: deleting,
                progress: busy
                    ? LinearProgressIndicator(
                        semanticsLabel: AppLocalizations.of(context)
                            .updatingVaccinations,
                      )
                    : null,
              ),
              floatingActionButton: state is VaccinationsLoaded
                  ? FloatingActionButton.extended(
                      isExtended:
                          MediaQuery.textScalerOf(context).scale(14) <= 21,
                      tooltip: AppLocalizations.of(context).addVaccination,
                      onPressed: busy ? null : () => _add(context),
                      icon: const Icon(Icons.add),
                      label: Text(AppLocalizations.of(context).addVaccination),
                    )
                  : null,
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: switch (state) {
                      VaccinationsLoaded() => _loaded(context, state),
                      VaccinationError(:final failure) => ErrorView(
                        message: failure is NotFoundFailure
                            ? AppLocalizations.of(context).vaccinationNotFound
                            : AppLocalizations.of(context)
                                  .vaccinationsLoadFailed,
                        onRetry: () => context
                            .read<VaccinationCubit>()
                            .loadVaccinations(petId),
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
