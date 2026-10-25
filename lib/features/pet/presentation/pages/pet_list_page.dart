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

void _openAddPet(BuildContext context) => context.push(AppRoutes.addEditPet);

class PetListPage extends StatefulWidget {
  const PetListPage({super.key});

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
    return Scaffold(
      appBar: AppBar(title: const Text('My pets')),
      body: BlocBuilder<PetCubit, PetState>(
        builder: (context, state) {
          return switch (state) {
            PetLoading() => const _PetLoadingView(),

            PetsLoaded(:final pets) =>
              pets.isEmpty
                  ? _EmptyPetsView(onAddPet: () => _openAddPet(context))
                  : _PetListView(pets: pets, onOpenPet: _openPet),

            PetError(:final message) => Padding(
              padding: const EdgeInsets.only(bottom: 96),
              child: ErrorView(
                message: message,
                onRetry: () => context.read<PetCubit>().loadPets(),
              ),
            ),

            _ => const _PetLoadingView(),
          };
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddPet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add pet'),
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

class _EmptyPetsView extends StatelessWidget {
  final VoidCallback onAddPet;
  const _EmptyPetsView({required this.onAddPet});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 48),

                VerticalGap.md,

                Text(
                  'No pets yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                VerticalGap.sm,

                Text(
                  'Add your first pet to start tracking health and care.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                VerticalGap.lg,

                ElevatedButton(
                  onPressed: onAddPet,
                  child: const Text('Add pet'),
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
  const _PetListView({required this.pets, required this.onOpenPet});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  'Choose a pet to view its profile and care overview.',
                ),
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
                    pet: pets[index],
                    onTap: () => onOpenPet(pets[index]),
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
  const _PetListItem({required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      pet.speciesAndBreed,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
