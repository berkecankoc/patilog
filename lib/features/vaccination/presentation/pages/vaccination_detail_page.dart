import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/pet_care_tabs.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_detail_field.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/my_pets_button.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:petlytics/features/vaccination/presentation/utils/confirm_vaccination_deletion.dart';
import 'package:petlytics/features/vaccination/presentation/widgets/vaccination_status_badge.dart';
import 'package:petlytics/features/vaccination/presentation/widgets/linked_vet_visit_section.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';

class VaccinationDetailPage extends StatelessWidget {
  final String petId;
  final String vaccinationId;
  final String? petName;

  const VaccinationDetailPage({
    super.key,
    required this.petId,
    required this.vaccinationId,
    this.petName,
  });

  Future<void> _edit(
    BuildContext context,
    Vaccination vaccination, {
    bool recordAdministration = false,
  }) async {
    final saved = await context.push<bool>(
      AppRoutes.addEditVaccination(petId),
      extra: VaccinationFormExtra(
        petId: petId,
        petName: petName,
        vaccination: vaccination,
        recordAdministration: recordAdministration,
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<VaccinationCubit>().loadVaccination(
        petId,
        vaccinationId,
      );
    }
  }

  Future<void> _openVisit(BuildContext context, String visitId) async {
    await context.push(
      AppRoutes.vetVisitDetail(petId, visitId),
      extra: PetCareRouteExtra(petId: petId, petName: petName),
    );
    if (context.mounted) {
      // A visit may have been deleted; reload the canonical optional link.
      await context.read<VaccinationCubit>().loadVaccination(
        petId,
        vaccinationId,
      );
      if (!context.mounted) return;
      final state = context.read<VaccinationCubit>().state;
      if (state is VaccinationLoaded &&
          state.vaccination.vetVisitId == visitId) {
        await context.read<VetVisitCubit>().loadVetVisit(petId, visitId);
      }
    }
  }

  Future<void> _delete(BuildContext context, Vaccination vaccination) async {
    final confirmed = await confirmVaccinationDeletion(context, vaccination);
    if (confirmed && context.mounted) {
      await context.read<VaccinationCubit>().deleteVaccination();
    }
  }

  Widget _recordAction(
    BuildContext context,
    Vaccination vaccination,
    bool busy, {
    required bool fixed,
  }) => AppFormActions(
    label: 'Record administration',
    saving: false,
    fixed: fixed,
    onPressed: busy
        ? null
        : () => _edit(context, vaccination, recordAdministration: true),
  );

  Widget _card(BuildContext context, Vaccination vaccination, bool busy) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
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
                    MaterialLocalizations.of(
                      context,
                    ).formatShortDate(vaccination.date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit vaccination',
                  color: theme.colorScheme.primary,
                  onPressed: busy ? null : () => _edit(context, vaccination),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            VerticalGap.sm,
            VaccinationStatusBadge(vaccination: vaccination),
            VerticalGap.md,
            AppDetailField(label: 'Vaccine', value: vaccination.vaccineName),
            const Divider(height: AppSpacing.xl),
            const AppSectionHeading(
              title: 'Clinic & veterinarian',
              icon: Icons.local_hospital_outlined,
            ),
            VerticalGap.md,
            AppDetailField(label: 'Clinic', value: vaccination.clinicName),
            VerticalGap.md,
            AppDetailField(
              label: 'Veterinarian',
              value: vaccination.veterinarianName,
            ),
            const Divider(height: AppSpacing.xl),
            const AppSectionHeading(title: 'Notes', icon: Icons.notes_outlined),
            VerticalGap.md,
            Text(
              vaccination.notes ?? 'Not provided',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<VaccinationCubit, VaccinationState>(
    listener: (context, state) {
      if (state case VaccinationDeleted(:final vaccinationId)) {
        PetCareChanges.recordChanged(
          context,
          petId,
          PetCareTab.vaccinations,
          deletedId: vaccinationId,
        );
        context.pop(vaccinationId);
      }
    },
    builder: (context, state) {
      final deleting = state is VaccinationLoaded && state.isDeleting;
      final busy =
          state is VaccinationLoaded &&
          (state.isDeleting || state.isRefreshing);
      final planned =
          state is VaccinationLoaded &&
          state.vaccination.status == VaccinationStatus.planned;
      final fixedAction =
          planned && MediaQuery.orientationOf(context) == Orientation.portrait;
      return PopScope<String>(
        canPop: !deleting,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: PetCareTitle.toolbarHeight(context),
            title: PetCareTitle(title: 'Vaccination', petName: petName),
            leading: careBackButton(context, busy: deleting),
            bottom: busy
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      semanticsLabel: deleting
                          ? 'Deleting vaccination'
                          : 'Refreshing vaccination',
                    ),
                  )
                : null,
            actions: [
              MyPetsButton(enabled: !busy),
              if (state case VaccinationLoaded(:final vaccination))
                IconButton(
                  tooltip: 'Delete vaccination',
                  onPressed: busy ? null : () => _delete(context, vaccination),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          bottomNavigationBar: fixedAction
              ? _recordAction(context, state.vaccination, busy, fixed: true)
              : null,
          body: SafeArea(
            bottom: !fixedAction,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: switch (state) {
                  VaccinationLoaded(
                    :final vaccination,
                    :final deleteError,
                    :final refreshError,
                  ) =>
                    LayoutBuilder(
                      builder: (context, constraints) => Column(
                        children: [
                          if (deleteError != null || refreshError != null)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * 0.75,
                              ),
                              child: AppErrorFeedback(
                                message: deleteError ?? refreshError!,
                                retryLabel: deleteError != null
                                    ? 'Retry deletion'
                                    : 'Retry',
                                onRetry: deleteError != null
                                    ? () => _delete(context, vaccination)
                                    : () => context
                                          .read<VaccinationCubit>()
                                          .loadVaccination(
                                            petId,
                                            vaccinationId,
                                          ),
                              ),
                            ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _card(context, vaccination, busy),
                                  if (vaccination.vetVisitId != null) ...[
                                    VerticalGap.md,
                                    LinkedVetVisitSection(
                                      petId: petId,
                                      visitId: vaccination.vetVisitId!,
                                      parentClinicName: vaccination.clinicName,
                                      parentVeterinarianName:
                                          vaccination.veterinarianName,
                                      onOpen: busy
                                          ? null
                                          : () => _openVisit(
                                              context,
                                              vaccination.vetVisitId!,
                                            ),
                                    ),
                                  ],
                                  if (planned && !fixedAction) ...[
                                    VerticalGap.lg,
                                    _recordAction(
                                      context,
                                      vaccination,
                                      busy,
                                      fixed: false,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  VaccinationError(:final message) => ErrorView(
                    message: message,
                    onRetry: () => context
                        .read<VaccinationCubit>()
                        .loadVaccination(petId, vaccinationId),
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
