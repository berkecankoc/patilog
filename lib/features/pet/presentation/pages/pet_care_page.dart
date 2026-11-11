import 'dart:math' as math;
import 'package:patilog/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_state.dart';
import 'package:flutter/material.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_route_extra.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:patilog/core/widgets/pet_care_tabs.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_state.dart';
import 'package:patilog/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:patilog/features/pet/presentation/widgets/pet_avatar.dart';
import 'package:patilog/features/pet/presentation/utils/pet_actions.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_state.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_state.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_state.dart';

class PetCarePage extends StatefulWidget {
  final String petId;
  final PetCareTab tab;
  final Map<PetCareTab, Widget Function(String? petName)> builders;
  const PetCarePage({
    super.key,
    required this.petId,
    required this.tab,
    required this.builders,
  });
  @override
  State<PetCarePage> createState() => _PetCarePageState();
}

class _PetCarePageState extends State<PetCarePage>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(
    length: PetCareTab.values.length,
    vsync: this,
    initialIndex: widget.tab.index,
  );
  late final _visited = {widget.tab};
  final _loaded = {PetCareTab.profile};
  final _buckets = <PetCareTab, PageStorageBucket>{};
  GoRouter? _router;
  PetCareChanges? _changes;
  Pet? _pet;
  bool _queued = false;
  late final _tabScroll = TabBarScrollController()
    ..addListener(_updateTabEdges);
  bool _hasPreviousTabs = false;
  bool _hasMoreTabs = false;

  void _updateTabEdges() {
    if (!mounted ||
        !_tabScroll.hasClients ||
        !_tabScroll.position.hasContentDimensions) {
      return;
    }
    final previous = _tabScroll.position.extentBefore > 1;
    final more = _tabScroll.position.extentAfter > 1;
    if (previous == _hasPreviousTabs && more == _hasMoreTabs) return;
    setState(() {
      _hasPreviousTabs = previous;
      _hasMoreTabs = more;
    });
  }

  void _scrollTabs(int direction) {
    if (_busy || !_tabScroll.hasClients) return;
    final position = _tabScroll.position;
    final target =
        (position.pixels +
                direction * math.max(48, position.viewportDimension - 48))
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _tabScroll.jumpTo(target);
    } else {
      _tabScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    }
  }

  void _exit() {
    if (_busy) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.pets);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    final changes = PetCareChanges.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_scheduleSync);
      _router = router;
      router.routerDelegate.addListener(_scheduleSync);
    }
    if (changes != _changes) {
      _changes?.removeListener(_scheduleSync);
      _changes = changes;
      changes?.addListener(_scheduleSync);
    }
    _scheduleSync();
  }

  @override
  void didUpdateWidget(PetCarePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.tab);
    _scheduleSync();
  }

  Cubit<Object> get _activeCubit => switch (widget.tab) {
    PetCareTab.profile => context.read<PetCubit>(),
    PetCareTab.vetVisits => context.read<VetVisitCubit>(),
    PetCareTab.vaccinations => context.read<VaccinationCubit>(),
    PetCareTab.medications => context.read<MedicationCubit>(),
    PetCareTab.feeding => context.read<FeedingCubit>(),
    PetCareTab.weightHistory => context.read<WeightHistoryCubit>(),
  };

  bool get _busy => switch (_activeCubit.state) {
    PetLoaded(:final isDeleting) => isDeleting,
    VetVisitsLoaded(:final isDeleting) => isDeleting,
    VaccinationsLoaded(:final isDeleting) => isDeleting,
    WeightHistoryLoaded(:final isDeleting) => isDeleting,
    MedicationsLoaded(:final pendingAction) => pendingAction != null,
    FeedingLoaded(:final pendingAction) => pendingAction != null,
    _ => false,
  };

  bool _select(PetCareTab tab) {
    if (_busy) {
      return false;
    }
    if (tab == widget.tab) return true;
    context.go(
      tab.location(widget.petId),
      extra: PetCareRouteExtra(petId: widget.petId, petName: _pet?.name),
    );
    return true;
  }

  void _scheduleSync() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted ||
          _router!.state.uri.path != widget.tab.location(widget.petId) ||
          _busy) {
        return;
      }
      // Restored/deep routes can create the strip offstage; animate only after
      // its visible viewport has been laid out.
      if (_tabController.index != widget.tab.index) {
        _tabController.animateTo(
          widget.tab.index,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : null,
        );
      }
      final change = _changes?.take(widget.tab);
      final first = _loaded.add(widget.tab);
      for (final id in change?.deleted ?? <String>{}) {
        switch (widget.tab) {
          case PetCareTab.vetVisits:
            context.read<VetVisitCubit>().removeDeletedVisit(id);
          case PetCareTab.vaccinations:
            context.read<VaccinationCubit>().removeDeletedVaccination(id);
          case PetCareTab.medications:
            context.read<MedicationCubit>().removeDeletedMedication(id);
          case PetCareTab.feeding:
            context.read<FeedingCubit>().removeDeletedEntry(widget.petId, id);
          case PetCareTab.profile || PetCareTab.weightHistory:
            break;
        }
      }
      if (first || change?.reload == true) {
        switch (widget.tab) {
          case PetCareTab.profile:
            context.read<PetCubit>().refreshPet(widget.petId);
          case PetCareTab.vetVisits:
            context.read<VetVisitCubit>().loadVetVisits(widget.petId);
          case PetCareTab.vaccinations:
            context.read<VaccinationCubit>().loadVaccinations(widget.petId);
          case PetCareTab.medications:
            context.read<MedicationCubit>().loadMedications(widget.petId);
          case PetCareTab.feeding:
            final cubit = context.read<FeedingCubit>();
            final current = cubit.state;
            cubit.load(
              petId: widget.petId,
              historyDays: current is FeedingLoaded ? current.historyDays : 7,
              date: current is FeedingLoaded && !current.followsToday
                  ? current.date
                  : null,
            );
          case PetCareTab.weightHistory:
            context.read<WeightHistoryCubit>().loadWeightHistory(widget.petId);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabScroll.dispose();
    _tabController.dispose();
    _router?.routerDelegate.removeListener(_scheduleSync);
    _changes?.removeListener(_scheduleSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PetCubit, PetState>(
    builder: (context, state) {
      final strings = AppLocalizations.of(context);
      if (state is PetLoaded) _pet = state.pet;
      final pet = _pet;
      final theme = Theme.of(context);
      final scaler = MediaQuery.textScalerOf(context);
      final compact = MediaQuery.sizeOf(context).height < 400;
      return PetCareTabs(
        active: widget.tab,
        onSelect: _select,
        onExit: _exit,
        child: BlocBuilder<Cubit<Object>, Object>(
          bloc: _activeCubit,
          builder: (context, activeState) {
            final busy = _busy;
            final refreshing = switch (activeState) {
              PetLoaded(:final isRefreshing) => isRefreshing,
              VetVisitsLoaded(:final isRefreshing) => isRefreshing,
              VaccinationsLoaded(:final isRefreshing) => isRefreshing,
              WeightHistoryLoaded(:final isRefreshing) => isRefreshing,
              MedicationsLoaded(:final isRefreshing, :final doses) =>
                isRefreshing || doses.isLoading,
              FeedingLoaded(:final isRefreshing) => isRefreshing,
              _ => false,
            };
            return Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                centerTitle: false,
                titleSpacing: 4,
                scrolledUnderElevation: 0,
                leading: busy
                    ? IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: null,
                        icon: const BackButtonIcon(),
                      )
                    : BackButton(onPressed: _exit),
                actions: [
                  if (widget.tab == PetCareTab.profile && state is PetLoaded)
                    IconButton(
                      tooltip: strings.deletePet,
                      onPressed: busy
                          ? null
                          : () => deletePetWithConfirmation(context, state.pet),
                      icon: const Icon(Icons.delete_outline),
                    )
                  else
                    const SizedBox(width: 48),
                ],
                title: pet == null
                    ? Text(strings.petProfile)
                    : Row(
                        children: [
                          ExcludeSemantics(
                            child: PetAvatar(
                              pet: pet,
                              size: 40,
                              iconSize: 24,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: compact
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pet.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontSize: 20,
                                                height: 1.2,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        pet.species.label(strings),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pet.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontSize: 20,
                                              height: 1.2,
                                            ),
                                      ),
                                      Text(
                                        pet.species.label(strings),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              height: 1.2,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                toolbarHeight: compact
                    ? kToolbarHeight
                    : math.max(
                        kToolbarHeight,
                        scaler.scale(20) * 1.2 +
                            scaler.scale(theme.textTheme.bodySmall!.fontSize!) *
                                1.2 +
                            8,
                      ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: IconButton(
                                tooltip: strings.previousTabs,
                                onPressed: busy || !_hasPreviousTabs
                                    ? null
                                    : () => _scrollTabs(-1),
                                icon: const Icon(Icons.chevron_left),
                              ),
                            ),
                            Expanded(
                              child:
                                  NotificationListener<
                                    ScrollMetricsNotification
                                  >(
                                    onNotification: (_) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) _updateTabEdges();
                                          });
                                      return false;
                                    },
                                    child: IgnorePointer(
                                      ignoring: busy,
                                      child: TabBar(
                                        controller: _tabController,
                                        scrollController: _tabScroll,
                                        isScrollable: true,
                                        tabAlignment: TabAlignment.start,
                                        dividerHeight: 0,
                                        onTap: (index) {
                                          if (!_select(
                                            PetCareTab.values[index],
                                          )) {
                                            _tabController.index =
                                                widget.tab.index;
                                          }
                                        },
                                        tabs: [
                                          for (final tab in PetCareTab.values)
                                            Tab(text: tab.label(strings)),
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                            SizedBox(
                              width: 48,
                              child: IconButton(
                                tooltip: strings.moreTabs,
                                onPressed: busy || !_hasMoreTabs
                                    ? null
                                    : () => _scrollTabs(1),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (busy || refreshing)
                        const LinearProgressIndicator(minHeight: 2),
                    ],
                  ),
                ),
              ),
              body: IndexedStack(
                index: widget.tab.index,
                sizing: StackFit.expand,
                children: [
                  for (final tab in PetCareTab.values)
                    _visited.contains(tab)
                        ? HeroMode(
                            enabled: tab == widget.tab,
                            child: TickerMode(
                              enabled: tab == widget.tab,
                              child: PrimaryScrollController.none(
                                child: PageStorage(
                                  key: ValueKey(tab),
                                  bucket: _buckets.putIfAbsent(
                                    tab,
                                    PageStorageBucket.new,
                                  ),
                                  child: widget.builders[tab]!(pet?.name),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
