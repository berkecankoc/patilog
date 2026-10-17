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
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:petlytics/features/vet_visit/presentation/utils/confirm_vet_visit_deletion.dart';
import 'package:petlytics/features/vet_visit/presentation/utils/vet_visit_cost.dart';

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
    }
  }

  Future<void> _delete(BuildContext context, VetVisit visit) async {
    final confirmed = await confirmVetVisitDeletion(context, visit);
    if (confirmed && context.mounted) {
      await context.read<VetVisitCubit>().deleteVetVisit();
    }
  }

  Widget _field(BuildContext context, String label, String? value) {
    final theme = Theme.of(context);
    final hasValue = value != null && value.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        VerticalGap.xs,
        Text(
          hasValue ? value : 'Not provided',
          style: hasValue
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VetVisitCubit, VetVisitState>(
      listener: (context, state) {
        if (state case VetVisitDeleted(:final visitId)) context.pop(visitId);
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
              leading: deleting
                  ? IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: null,
                      icon: const BackButtonIcon(),
                    )
                  : null,
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
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
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
                                              color: colors.onSurfaceVariant,
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
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Edit visit',
                                            color: colors.primary,
                                            onPressed: busy
                                                ? null
                                                : () => _edit(context, visit),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                        ],
                                      ),
                                      VerticalGap.md,
                                      _field(
                                        context,
                                        'Reason for visit',
                                        visit.reason,
                                      ),
                                      const Divider(height: AppSpacing.xxl),
                                      const AppSectionHeading(
                                        title: 'Clinic & veterinarian',
                                        icon: Icons.local_hospital_outlined,
                                      ),
                                      VerticalGap.md,
                                      _field(
                                        context,
                                        'Clinic',
                                        visit.clinicName,
                                      ),
                                      VerticalGap.md,
                                      _field(
                                        context,
                                        'Veterinarian',
                                        visit.veterinarianName,
                                      ),
                                      const Divider(height: AppSpacing.xxl),
                                      const AppSectionHeading(
                                        title: 'Medical notes',
                                        icon:
                                            Icons.medical_information_outlined,
                                      ),
                                      VerticalGap.md,
                                      _field(
                                        context,
                                        'Diagnosis',
                                        visit.diagnosis,
                                      ),
                                      VerticalGap.md,
                                      _field(context, 'Notes', visit.notes),
                                      const Divider(height: AppSpacing.xxl),
                                      const AppSectionHeading(
                                        title: 'Cost',
                                        icon: Icons.payments_outlined,
                                      ),
                                      VerticalGap.md,
                                      _field(
                                        context,
                                        'Amount',
                                        visit.costMinorUnits == null
                                            ? null
                                            : '${formatVetVisitCost(visit.costMinorUnits!)} ${visit.currency!.code}',
                                      ),
                                    ],
                                  ),
                                ),
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
