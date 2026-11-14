import 'package:flutter/material.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/widgets/app_gap.dart';
import 'package:patilog/core/widgets/error_view.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_state.dart';
import 'package:patilog/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:patilog/features/pet/presentation/widgets/pet_avatar.dart';
import 'package:patilog/features/pet/presentation/widgets/pet_species_icon.dart';

void _openAddPet(BuildContext context) => context.push(AppRoutes.addEditPet);

class PetListPage extends StatefulWidget {
  final List<Pet>? pets;
  final ValueChanged<Pet>? onOpenPet;
  final Set<String> pinningPetIds;
  final ValueChanged<Pet>? onTogglePin;
  const PetListPage({super.key})
    : pets = null,
      onOpenPet = null,
      pinningPetIds = const {},
      onTogglePin = null;
  const PetListPage.fromRecords({
    super.key,
    required List<Pet> this.pets,
    required ValueChanged<Pet> this.onOpenPet,
    this.pinningPetIds = const {},
    this.onTogglePin,
  });

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  GoRouter? _router;
  bool _active = false;
  bool _handledDeletion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pets != null) return;
    final router = GoRouter.maybeOf(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_routeChanged);
    _router = router;
    _active = router?.state.uri.path == AppRoutes.pets;
    router?.routerDelegate.addListener(_routeChanged);
  }

  void _routeChanged() {
    final active = _router!.state.uri.path == AppRoutes.pets;
    if (active && !_active) {
      // Both Back and My pets can reveal a retained list route.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _router!.state.uri.path == AppRoutes.pets) {
          if (!_handledDeletion) context.read<PetCubit>().loadPets();
          _handledDeletion = false;
        }
      });
    }
    _active = active;
  }

  Future<void> _openPet(Pet pet) async {
    final deletedId = await context.push<String>(AppRoutes.petDetail(pet.id));
    if (!mounted || deletedId == null || deletedId != pet.id) return;
    final cubit = context.read<PetCubit>();
    if (cubit.state is PetsLoaded) {
      cubit.removeDeletedPet(deletedId);
      _handledDeletion = true;
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pets != null) {
      return widget.pets!.isEmpty
          ? const _PetWelcomeView()
          : _PetListView(
              pets: widget.pets!,
              onOpenPet: widget.onOpenPet!,
              pinningPetIds: widget.pinningPetIds,
              onTogglePin: widget.onTogglePin,
            );
    }
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).myPets)),
      body: BlocBuilder<PetCubit, PetState>(
        builder: (context, state) {
          return switch (state) {
            PetLoading() => const _PetLoadingView(),

            PetsLoaded(:final pets) =>
              pets.isEmpty
                  ? const _PetWelcomeView()
                  : _PetListView(pets: pets, onOpenPet: _openPet),

            PetError() => Padding(
              padding: const EdgeInsets.only(bottom: 96),
              child: ErrorView(
                message: AppLocalizations.of(context).petsLoadFailed,
                onRetry: () => context.read<PetCubit>().loadPets(),
              ),
            ),

            _ => const _PetLoadingView(),
          };
        },
      ),
      floatingActionButton: BlocBuilder<PetCubit, PetState>(
        builder: (context, state) {
          final strings = AppLocalizations.of(context);
          final label = state is PetsLoaded && state.pets.isEmpty
              ? strings.addFirstPet
              : strings.addPet;
          return FloatingActionButton.extended(
            tooltip: label,
            isExtended: MediaQuery.textScalerOf(context).scale(14) <= 21,
            onPressed: () => _openAddPet(context),
            icon: const Icon(Icons.add),
            label: Text(label),
          );
        },
      ),
    );
  }
}

class _PetLoadingView extends StatelessWidget {
  const _PetLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _PetWelcomeView extends StatelessWidget {
  const _PetWelcomeView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              // FAB height, Scaffold margin, and a small gap.
              80,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final species in PetSpecies.values)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: PetSpeciesIcon(
                              species: species,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                VerticalGap.lg,
                Text(
                  strings.petWelcomeTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                VerticalGap.sm,
                Text(
                  strings.petWelcomeDescription,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                VerticalGap.lg,
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.smartphone_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        HorizontalGap.md,
                        Expanded(
                          child: Text(
                            strings.petWelcomePrivacy,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _PetListView extends StatelessWidget {
  final List<Pet> pets;
  final ValueChanged<Pet> onOpenPet;
  final Set<String> pinningPetIds;
  final ValueChanged<Pet>? onTogglePin;
  const _PetListView({
    required this.pets,
    required this.onOpenPet,
    this.pinningPetIds = const {},
    this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(AppLocalizations.of(context).choosePetOverview),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    112,
                  ),
                  itemCount: pets.length,
                  itemBuilder: (context, index) => _PetListItem(
                    key: ValueKey(pets[index].id),
                    pet: pets[index],
                    onTap: () => onOpenPet(pets[index]),
                    onTogglePin: onTogglePin == null
                        ? null
                        : () => onTogglePin!(pets[index]),
                    isPinning: pinningPetIds.contains(pets[index].id),
                  ),
                  separatorBuilder: (context, index) => VerticalGap.md,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetListItem extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;

  /// Null hides the pin control.
  final VoidCallback? onTogglePin;
  final bool isPinning;
  const _PetListItem({
    super.key,
    required this.pet,
    required this.onTap,
    this.onTogglePin,
    this.isPinning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ExcludeSemantics(child: PetAvatar(pet: pet)),
              HorizontalGap.md,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: theme.textTheme.titleMedium),
                    VerticalGap.xs,
                    Text(
                      pet.speciesAndBreed(strings),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTogglePin != null)
                IconButton(
                  isSelected: pet.isPinned,
                  tooltip: pet.isPinned
                      ? strings.unpinPet(pet.name)
                      : strings.pinPet(pet.name),
                  onPressed: isPinning ? null : onTogglePin,
                  icon: const Icon(Icons.push_pin_outlined),
                  selectedIcon: Icon(
                    Icons.push_pin,
                    color: theme.colorScheme.primary,
                  ),
                ),
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
        ),
      ),
    );
  }
}
