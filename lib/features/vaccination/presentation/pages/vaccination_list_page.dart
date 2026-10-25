import 'package:petlytics/core/widgets/pet_care_tabs.dart';
import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:petlytics/features/vaccination/presentation/utils/confirm_vaccination_deletion.dart';
import 'package:petlytics/features/vaccination/presentation/widgets/vaccination_status_badge.dart';

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
      if (context.read<VaccinationCubit>().state case VaccinationsLoaded(
        :final vaccinations,
      ) when !vaccinations.any((item) => item.id == vaccination.id)) {
        PetCareChanges.recordChanged(
          context,
          petId,
          PetCareTab.vaccinations,
          listIsCurrent: true,
        );
      }
    }
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Vaccination> rows,
    VaccinationsLoaded state,
  ) {
    if (rows.isEmpty) return [];
    final busy = state.isDeleting || state.isRefreshing;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        sliver: SliverToBoxAdapter(
          child: AppSectionHeading(title: title, icon: icon),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final vaccination = rows[index];
            return Padding(
              key: ValueKey(vaccination.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _VaccinationListItem(
                vaccination: vaccination,
                deleting:
                    state.isDeleting &&
                    state.deletionVaccination?.id == vaccination.id,
                onOpen: busy ? null : () => _open(context, vaccination),
                onDelete: busy ? null : () => _delete(context, vaccination),
              ),
            );
          },
        ),
      ),
    ];
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
                message: state.deleteError!,
                retryLabel: 'Retry deletion',
                onRetry: () => _delete(context, state.deletionVaccination!),
              ),
            )
          else if (state.refreshError != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.75,
              ),
              child: AppErrorFeedback(
                message: state.refreshError!,
                retryLabel: 'Retry',
                onRetry: () =>
                    context.read<VaccinationCubit>().loadVaccinations(petId),
              ),
            ),
          Expanded(
            child: state.vaccinations.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                      child: Column(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.vaccines_outlined,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          VerticalGap.md,
                          Text(
                            'No vaccinations yet',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          VerticalGap.sm,
                          const Text(
                            'Record an administered vaccine or plan an upcoming dose.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      ..._section(
                        context,
                        'Planned',
                        Icons.event_outlined,
                        planned,
                        state,
                      ),
                      ..._section(
                        context,
                        'History',
                        Icons.history,
                        history,
                        state,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 96)),
                    ],
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
                title: PetCareTitle(title: 'Vaccinations', petName: petName),
                toolbarHeight: PetCareTitle.toolbarHeight(context),
                busy: deleting,
                progress: busy
                    ? const LinearProgressIndicator(
                        semanticsLabel: 'Updating vaccinations',
                      )
                    : null,
              ),
              floatingActionButton: state is VaccinationsLoaded
                  ? FloatingActionButton.extended(
                      isExtended:
                          MediaQuery.textScalerOf(context).scale(14) <= 21,
                      tooltip: 'Add vaccination',
                      onPressed: busy ? null : () => _add(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add vaccination'),
                    )
                  : null,
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: switch (state) {
                      VaccinationsLoaded() => _loaded(context, state),
                      VaccinationError(:final message) => ErrorView(
                        message: message,
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

class _VaccinationListItem extends StatelessWidget {
  final Vaccination vaccination;
  final bool deleting;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  const _VaccinationListItem({
    required this.vaccination,
    required this.deleting,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(vaccination.date);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.event_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  HorizontalGap.sm,
                  Expanded(
                    child: Text(
                      date,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 48,
                    child: deleting
                        ? const Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: 'Deleting vaccination',
                              ),
                            ),
                          )
                        : IconButton(
                            tooltip:
                                'Delete ${vaccination.vaccineName} from $date',
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline),
                          ),
                  ),
                ],
              ),
              Text(
                vaccination.vaccineName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              VerticalGap.sm,
              VaccinationStatusBadge(vaccination: vaccination),
              if (vaccination.clinicName != null) ...[
                VerticalGap.sm,
                Text(
                  vaccination.clinicName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
