import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetCubit, PetState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: const Text('Pet profile'),
          actions: [
            if (state case PetLoaded(:final pet))
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => _editPet(context, pet),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: switch (state) {
          PetLoaded(:final pet) => _PetView(pet: pet),
          PetError(:final message) => ErrorView(
            message: message,
            onRetry: () => context.read<PetCubit>().getPetById(petId),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _PetView extends StatelessWidget {
  final Pet pet;
  const _PetView({required this.pet});

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
                Text('Care records', style: theme.textTheme.titleLarge),
                VerticalGap.md,
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (index, section) in const [
                        (Icons.local_hospital_outlined, 'Vet visits'),
                        (Icons.vaccines_outlined, 'Vaccines'),
                        (Icons.medication_outlined, 'Medicine'),
                        (Icons.monitor_weight_outlined, 'Weight history'),
                      ].indexed) ...[
                        if (index > 0)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(start: 72),
                            child: Divider(height: 1),
                          ),
                        ListTile(
                          enabled: false,
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
                            'Coming soon',
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
                VerticalGap.lg,
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    title: const Text('Profile details'),
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
                        ('Sex', pet.sex.label),
                        ('Breed', pet.breed),
                        ('Reproductive status', pet.reproductiveStatus.label),
                        (
                          'Birth date',
                          birthDate == null
                              ? null
                              : MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(birthDate),
                        ),
                        (
                          'Current weight',
                          pet.weight == null ? null : '${pet.weight} kg',
                        ),
                        ('Microchip ID', pet.microchipId),
                      ].indexed) ...[
                        if (index > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Divider(height: 1),
                          ),
                        Text(
                          detail.$1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        VerticalGap.xs,
                        Text(
                          detail.$2?.trim().isNotEmpty == true
                              ? detail.$2!
                              : 'Not provided',
                          style: theme.textTheme.bodyLarge,
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
