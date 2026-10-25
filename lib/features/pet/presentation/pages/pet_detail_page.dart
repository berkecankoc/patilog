import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/utils/weight_utils.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';
import 'package:petlytics/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_avatar.dart';

class PetDetailPage extends StatelessWidget {
  final String petId;

  const PetDetailPage({super.key, required this.petId});

  Future<void> _editPet(BuildContext context, Pet pet) async {
    final updated = await context.push<bool>(AppRoutes.addEditPet, extra: pet);

    if (updated == true && context.mounted) {
      await context.read<PetCubit>().getPetById(petId);
    }
  }

  Future<void> _openWeightHistory(BuildContext context, Pet pet) async {
    await context.push(
      AppRoutes.weightHistory(petId),
      extra: PetCareRouteExtra(petId: petId, petName: pet.name),
    );
    if (context.mounted) {
      await context.read<PetCubit>().getPetById(petId);
    }
  }

  Future<void> _deletePet(BuildContext context, Pet pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: 'Delete pet?',
        message:
            '${pet.name}’s profile, photo, weight history, vet visits, vaccinations, medications and dose records will be removed. This cannot be undone.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<PetCubit>().deletePet(pet);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PetCubit, PetState>(
      listener: (context, state) {
        if (state is PetDeleted) context.pop(petId);
      },
      builder: (context, state) {
        final deleting = state is PetLoaded && state.isDeleting;
        return PopScope<String>(
          canPop: !deleting,
          child: Scaffold(
            appBar: AppBar(
              title: Text(deleting ? 'Deleting pet…' : 'Pet profile'),
              leading: deleting
                  ? IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: null,
                      icon: const BackButtonIcon(),
                    )
                  : null,
              bottom: deleting
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(4),
                      child: LinearProgressIndicator(
                        semanticsLabel: 'Deleting pet',
                      ),
                    )
                  : null,
              actions: [
                if (state case PetLoaded(:final pet)) ...[
                  IconButton(
                    tooltip: 'Delete pet',
                    onPressed: deleting ? null : () => _deletePet(context, pet),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            body: AbsorbPointer(
              absorbing: deleting,
              child: switch (state) {
                PetLoaded(:final pet, :final deleteError) => Column(
                  children: [
                    if (deleteError != null)
                      Flexible(
                        child: AppErrorFeedback(
                          message: deleteError,
                          retryLabel: 'Retry deletion',
                          onRetry: () => _deletePet(context, pet),
                        ),
                      ),
                    Expanded(
                      child: _PetView(
                        pet: pet,
                        onEdit: deleting ? null : () => _editPet(context, pet),
                        onWeightHistory: () => _openWeightHistory(context, pet),
                        onVetVisits: () => context.push(
                          AppRoutes.vetVisits(petId),
                          extra: PetCareRouteExtra(
                            petId: petId,
                            petName: pet.name,
                          ),
                        ),
                        onVaccinations: () => context.push(
                          AppRoutes.vaccinations(petId),
                          extra: PetCareRouteExtra(
                            petId: petId,
                            petName: pet.name,
                          ),
                        ),
                        onMedications: () => context.push(
                          AppRoutes.medications(petId),
                          extra: PetCareRouteExtra(
                            petId: petId,
                            petName: pet.name,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                PetError(:final message) => ErrorView(
                  message: message,
                  onRetry: () => context.read<PetCubit>().getPetById(petId),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        );
      },
    );
  }
}

class _PetView extends StatelessWidget {
  final Pet pet;
  final VoidCallback? onEdit;
  final VoidCallback onWeightHistory;
  final VoidCallback onVetVisits;
  final VoidCallback onVaccinations;
  final VoidCallback onMedications;
  const _PetView({
    required this.pet,
    required this.onEdit,
    required this.onWeightHistory,
    required this.onVetVisits,
    required this.onVaccinations,
    required this.onMedications,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final birthDate = pet.birthDate;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Semantics(
                    label: pet.imagePath == null
                        ? 'No photo of ${pet.name}'
                        : 'Photo of ${pet.name}',
                    image: true,
                    child: ExcludeSemantics(
                      child: PetAvatar(
                        pet: pet,
                        size: 96,
                        iconSize: 48,
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                VerticalGap.md,
                Text(
                  pet.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                VerticalGap.xs,
                Text(
                  pet.speciesAndBreed,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                VerticalGap.xl,
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        const Expanded(child: Text('Profile details')),
                        IconButton(
                          tooltip: 'Edit profile',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, detail) in [
                        (Icons.wc_outlined, 'Sex', pet.sex.label),
                        (Icons.category_outlined, 'Breed', pet.breed),
                        (
                          Icons.health_and_safety_outlined,
                          'Reproductive status',
                          pet.reproductiveStatus.label,
                        ),
                        (
                          Icons.cake_outlined,
                          'Birth date',
                          birthDate == null
                              ? null
                              : MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(birthDate),
                        ),
                        (
                          Icons.monitor_weight_outlined,
                          'Current weight',
                          pet.weight == null
                              ? null
                              : '${formatWeight(pet.weight!)} kg',
                        ),
                        (
                          Icons.memory_outlined,
                          'Microchip ID',
                          pet.microchipId,
                        ),
                      ].indexed) ...[
                        if (index > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Divider(height: 1),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                detail.$1,
                                color: colors.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                            HorizontalGap.md,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detail.$2,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                  VerticalGap.xs,
                                  Text(
                                    detail.$3?.trim().isNotEmpty == true
                                        ? detail.$3!
                                        : 'Not provided',
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                VerticalGap.lg,
                const AppSectionHeading(
                  title: 'Care records',
                  icon: Icons.folder_open_outlined,
                ),
                VerticalGap.md,
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (index, section) in const [
                        (Icons.local_hospital_outlined, 'Vet visits'),
                        (Icons.vaccines_outlined, 'Vaccinations'),
                        (Icons.medication_outlined, 'Medications'),
                        (Icons.monitor_weight_outlined, 'Weight history'),
                      ].indexed) ...[
                        if (index > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Divider(height: 1),
                          ),
                        ListTile(
                          enabled:
                              section.$2 == 'Weight history' ||
                              section.$2 == 'Vet visits' ||
                              section.$2 == 'Vaccinations' ||
                              section.$2 == 'Medications',
                          onTap: switch (section.$2) {
                            'Weight history' => onWeightHistory,
                            'Vet visits' => onVetVisits,
                            'Vaccinations' => onVaccinations,
                            'Medications' => onMedications,
                            _ => null,
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          leading: ExcludeSemantics(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                section.$1,
                                color: colors.onPrimaryContainer,
                                size: 20,
                              ),
                            ),
                          ),
                          title: Text(
                            section.$2,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            switch (section.$2) {
                              'Weight history' =>
                                'View and manage measurements',
                              'Vet visits' => 'View and manage visits',
                              'Vaccinations' => 'View and manage vaccinations',
                              'Medications' =>
                                'Track doses and manage medications',
                              _ => 'Coming soon',
                            },
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          trailing: ExcludeSemantics(
                            child: Icon(
                              Icons.chevron_right,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
