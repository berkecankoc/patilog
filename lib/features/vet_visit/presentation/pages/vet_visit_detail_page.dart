import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/pet_care_tabs.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/widgets/visit_medications_section.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_detail_field.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/my_pets_button.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:petlytics/features/vet_visit/presentation/utils/confirm_vet_visit_deletion.dart';
import 'package:petlytics/features/vet_visit/presentation/utils/vet_visit_cost.dart';
import 'package:petlytics/features/vet_visit/presentation/widgets/visit_vaccinations_section.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';

class VetVisitDetailPage extends StatelessWidget {
  final String petId;
  final String visitId;
  final String? petName;

  const VetVisitDetailPage({
    super.key,
    required this.petId,
    required this.visitId,
    this.petName,
  });

  Future<void> _edit(BuildContext context, VetVisit visit) async {
    final saved = await context.push<bool>(
      AppRoutes.addEditVetVisit(petId),
      extra: VetVisitFormExtra(petId: petId, petName: petName, visit: visit),
    );
    if (saved == true && context.mounted) {
      await context.read<VetVisitCubit>().loadVetVisit(petId, visitId);
      if (!context.mounted) return;
      final linked = context.read<VaccinationCubit>();
      if (linked.state is! VaccinationInitial) {
        await linked.loadVaccinations(petId, vetVisitId: visitId);
      }
    }
  }

  Future<void> _delete(BuildContext context, VetVisit visit) async {
    final confirmed = await confirmVetVisitDeletion(context, visit);
    if (confirmed && context.mounted) {
      await context.read<VetVisitCubit>().deleteVetVisit();
    }
  }

  Future<void> _openMedication(
    BuildContext context,
    Medication medication,
  ) async {
    final deleted = await context.push<String>(
      AppRoutes.medicationDetail(petId, medication.id),
      extra: PetCareRouteExtra(petId: petId, petName: petName),
    );
    if (!context.mounted) return;
    await context.read<VetVisitCubit>().loadVetVisit(petId, visitId);
    if (!context.mounted ||
        context.read<VetVisitCubit>().state is! VetVisitLoaded) {
      return;
    }
    final cubit = context.read<MedicationCubit>();
    if (deleted != null) {
      cubit.removeDeletedMedication(deleted);
    } else {
      await cubit.loadMedications(petId, vetVisitId: visitId);
    }
  }

  Future<void> _openVaccination(
    BuildContext context,
    Vaccination vaccination,
  ) async {
    final deletedId = await context.push<String>(
      AppRoutes.vaccinationDetail(petId, vaccination.id),
      extra: PetCareRouteExtra(petId: petId, petName: petName),
    );
    if (!context.mounted) return;
    await context.read<VetVisitCubit>().loadVetVisit(petId, visitId);
    if (!context.mounted ||
        context.read<VetVisitCubit>().state is! VetVisitLoaded) {
      return;
    }
    final cubit = context.read<VaccinationCubit>();
    if (deletedId != null) {
      cubit.removeDeletedVaccination(deletedId);
    } else {
      await cubit.loadVaccinations(petId, vetVisitId: visitId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VetVisitCubit, VetVisitState>(
      listener: (context, state) {
        if (state case VetVisitDeleted(:final visitId)) {
          PetCareChanges.recordChanged(
            context,
            petId,
            PetCareTab.vetVisits,
            deletedId: visitId,
          );
          context.pop(visitId);
        }
      },
      builder: (context, state) {
        final colors = Theme.of(context).colorScheme;
        final deleting = state is VetVisitLoaded && state.isDeleting;
        final busy =
            state is VetVisitLoaded && (state.isDeleting || state.isRefreshing);
        return PopScope<String>(
          canPop: !deleting,
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: PetCareTitle.toolbarHeight(context),
              title: PetCareTitle(title: 'Vet visit', petName: petName),
              leading: careBackButton(context, busy: deleting),
              bottom: busy
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(4),
                      child: LinearProgressIndicator(
                        semanticsLabel: deleting
                            ? 'Deleting visit'
                            : 'Refreshing visit',
                      ),
                    )
                  : null,
              actions: [
                MyPetsButton(enabled: !busy),
                if (state case VetVisitLoaded(:final visit))
                  IconButton(
                    tooltip: 'Delete visit',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: busy ? null : () => _delete(context, visit),
                  ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: switch (state) {
                    VetVisitLoaded(
                      :final visit,
                      :final refreshError,
                      :final deleteError,
                    ) =>
                      Column(
                        children: [
                          if (deleteError != null || refreshError != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: deleteError ?? refreshError!,
                                retryLabel: deleteError != null
                                    ? 'Retry deletion'
                                    : 'Retry',
                                onRetry: deleteError != null
                                    ? () => _delete(context, visit)
                                    : () => context
                                          .read<VetVisitCubit>()
                                          .loadVetVisit(petId, visitId),
                              ),
                            ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Card(
                                    margin: EdgeInsets.zero,
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              ExcludeSemantics(
                                                child: Icon(
                                                  Icons.event_note_outlined,
                                                  size: 20,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                              ),
                                              HorizontalGap.sm,
                                              Expanded(
                                                child: Text(
                                                  MaterialLocalizations.of(
                                                    context,
                                                  ).formatShortDate(
                                                    visit.visitedOn,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Edit visit',
                                                color: colors.primary,
                                                onPressed: busy
                                                    ? null
                                                    : () =>
                                                          _edit(context, visit),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                            ],
                                          ),
                                          VerticalGap.md,
                                          AppDetailField(
                                            label: 'Reason for visit',
                                            value: visit.reason,
                                          ),
                                          const Divider(height: AppSpacing.xxl),
                                          const AppSectionHeading(
                                            title: 'Clinic & veterinarian',
                                            icon: Icons.local_hospital_outlined,
                                          ),
                                          VerticalGap.md,
                                          AppDetailField(
                                            label: 'Clinic',
                                            value: visit.clinicName,
                                          ),
                                          VerticalGap.md,
                                          AppDetailField(
                                            label: 'Veterinarian',
                                            value: visit.veterinarianName,
                                          ),
                                          const Divider(height: AppSpacing.xxl),
                                          const AppSectionHeading(
                                            title: 'Medical notes',
                                            icon: Icons
                                                .medical_information_outlined,
                                          ),
                                          VerticalGap.md,
                                          AppDetailField(
                                            label: 'Diagnosis',
                                            value: visit.diagnosis,
                                          ),
                                          VerticalGap.md,
                                          AppDetailField(
                                            label: 'Notes',
                                            value: visit.notes,
                                          ),
                                          const Divider(height: AppSpacing.xxl),
                                          const AppSectionHeading(
                                            title: 'Cost',
                                            icon: Icons.payments_outlined,
                                          ),
                                          VerticalGap.md,
                                          AppDetailField(
                                            label: 'Amount',
                                            value: visit.costMinorUnits == null
                                                ? null
                                                : '${formatVetVisitCost(visit.costMinorUnits!)} ${visit.currency!.code}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  VerticalGap.md,
                                  VisitVaccinationsSection(
                                    petId: petId,
                                    visitId: visitId,
                                    parentClinicName: visit.clinicName,
                                    parentVeterinarianName:
                                        visit.veterinarianName,
                                    onOpen: busy
                                        ? null
                                        : (vaccination) => _openVaccination(
                                            context,
                                            vaccination,
                                          ),
                                  ),
                                  VerticalGap.md,
                                  VisitMedicationsSection(
                                    petId: petId,
                                    visitId: visitId,
                                    parentClinicName: visit.clinicName,
                                    parentVeterinarianName:
                                        visit.veterinarianName,
                                    onOpen: busy
                                        ? null
                                        : (medication) => _openMedication(
                                            context,
                                            medication,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    VetVisitError(:final message) => ErrorView(
                      message: message,
                      onRetry: () => context.read<VetVisitCubit>().loadVetVisit(
                        petId,
                        visitId,
                      ),
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
