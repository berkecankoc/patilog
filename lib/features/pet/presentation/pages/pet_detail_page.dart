import 'package:flutter/material.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/router/care_record_changes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/l10n/app_number_formats.dart';
import 'package:patilog/core/widgets/app_gap.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/core/widgets/error_view.dart';
import 'package:patilog/core/widgets/pet_care_tabs.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_state.dart';
import 'package:patilog/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:patilog/features/pet/presentation/utils/pet_actions.dart';

class PetDetailPage extends StatelessWidget {
  final String petId;
  const PetDetailPage({super.key, required this.petId});

  Future<void> _editPet(BuildContext context, Pet pet) async {
    final updated = await context.push<bool>(AppRoutes.addEditPet, extra: pet);
    if (updated == true && context.mounted) {
      final changes = PetCareChanges.maybeOf(context);
      if (changes != null) {
        changes.changed(PetCareTab.profile);
      } else {
        await context.read<PetCubit>().refreshPet(petId);
      }
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<PetCubit, PetState>(
    listener: (context, state) {
      if (state is PetDeleted) {
        CareRecordChanges.maybeOf(
          context,
        )?.changed(petId, PetCareTab.profile, petDeleted: true);
        context.pop(petId);
      }
    },
    builder: (context, state) {
      final strings = AppLocalizations.of(context);
      final loaded = state is PetLoaded ? state : null;
      final deleting = loaded?.isDeleting == true;
      return PopScope<String>(
        canPop: !deleting,
        child: Scaffold(
          appBar: petCareAppBar(
            context,
            title: PetCareTitle(
              title: strings.petProfile,
              petName: loaded?.pet.name,
            ),
            busy: deleting,
            progress: deleting || loaded?.isRefreshing == true
                ? const LinearProgressIndicator()
                : null,
            actions: [
              if (loaded != null)
                IconButton(
                  tooltip: strings.deletePet,
                  onPressed: deleting
                      ? null
                      : () => deletePetWithConfirmation(context, loaded.pet),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: AbsorbPointer(
            absorbing: deleting,
            child: switch (state) {
              PetLoaded(:final pet, :final deleteError, :final refreshError) =>
                Column(
                  children: [
                    if (deleteError != null || refreshError != null)
                      Flexible(
                        child: AppErrorFeedback(
                          message: deleteError != null
                              ? strings.petDeleteFailed
                              : refreshError is NotFoundFailure
                              ? strings.petNotFound
                              : strings.petRefreshFailed,
                          retryLabel: deleteError != null
                              ? strings.retryDeletion
                              : strings.retryProfile,
                          onRetry: () => deleteError != null
                              ? deletePetWithConfirmation(context, pet)
                              : context.read<PetCubit>().refreshPet(petId),
                        ),
                      ),
                    Expanded(
                      child: _PetView(
                        pet: pet,
                        onEdit: deleting ? null : () => _editPet(context, pet),
                      ),
                    ),
                  ],
                ),
              PetError(:final failure) => ErrorView(
                message: failure is NotFoundFailure
                    ? strings.petNotFound
                    : strings.petLoadFailed,
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

class _PetView extends StatelessWidget {
  final Pet pet;
  final VoidCallback? onEdit;
  const _PetView({required this.pet, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final colors = theme.colorScheme;
    final birthDate = pet.birthDate;
    return SafeArea(
      child: SingleChildScrollView(
        key: const PageStorageKey('pet-profile-details'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.profileDetails,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.editProfile,
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    VerticalGap.md,
                    for (final (index, detail) in [
                      (Icons.wc_outlined, strings.sex, pet.sex.label(strings)),
                      (Icons.category_outlined, strings.breed, pet.breed),
                      (
                        Icons.health_and_safety_outlined,
                        strings.reproductiveStatus,
                        pet.reproductiveStatus.label(strings),
                      ),
                      (
                        Icons.cake_outlined,
                        strings.birthDate,
                        birthDate == null
                            ? null
                            : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(birthDate),
                      ),
                      (
                        Icons.monitor_weight_outlined,
                        strings.currentWeight,
                        pet.weight == null
                            ? null
                            : '${localizedWeight(pet.weight!, Localizations.localeOf(context))} kg',
                      ),
                      (
                        Icons.memory_outlined,
                        strings.microchipId,
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
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                VerticalGap.xs,
                                Text(
                                  detail.$3?.trim().isNotEmpty == true
                                      ? detail.$3!
                                      : strings.notProvided,
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
            ),
          ),
        ),
      ),
    );
  }
}
