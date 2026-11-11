import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/core/l10n/app_number_formats.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/router/care_record_changes.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_route_extra.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/core/widgets/app_gap.dart';
import 'package:patilog/core/widgets/app_pet_filter.dart';
import 'package:patilog/core/widgets/app_pet_picker.dart';
import 'package:patilog/core/widgets/app_section_heading.dart';
import 'package:patilog/core/widgets/care_record_card.dart';
import 'package:patilog/core/widgets/error_view.dart';
import 'package:patilog/core/widgets/pet_care_tabs.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_state.dart';
import 'package:patilog/features/weight_history/presentation/widgets/weight_history_chart.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

class WeightHistoryPage extends StatefulWidget {
  final String? petId;
  final String? petName;
  final List<Pet> pets;
  final bool petsLoaded;

  const WeightHistoryPage({
    super.key,
    this.petId,
    this.petName,
    this.pets = const [],
    this.petsLoaded = true,
  });

  @override
  State<WeightHistoryPage> createState() => _WeightHistoryPageState();
}

class _WeightHistoryPageState extends State<WeightHistoryPage> {
  String? _selectedPetId;
  bool get _global => widget.petId == null;
  WeightHistoryCubit get _cubit => context.read<WeightHistoryCubit>();
  bool get _busy =>
      _cubit.state is WeightHistoryLoaded &&
      (_cubit.state as WeightHistoryLoaded).isDeleting;
  String? get _ownerId => _global
      ? widget.pets.any((pet) => pet.id == _selectedPetId)
            ? _selectedPetId
            : null
      : widget.petId;
  Map<String, Pet> get _petsById => {
    for (final pet in widget.pets) pet.id: pet,
  };
  Future<void> _reload() => _global
      ? _cubit.loadAllWeightHistory()
      : _cubit.loadWeightHistory(widget.petId!);

  void _select(String? id) {
    if (_busy) return;
    _cubit.dismissDeletionError();
    setState(() => _selectedPetId = id);
  }

  Future<void> _openForm([WeightEntry? entry]) async {
    if (_busy) return;
    final pet = _global
        ? entry == null
              ? await pickCarePet(context, widget.pets, selectedPetId: _ownerId)
              : _petsById[entry.petId]
        : null;
    if (!mounted || _global && pet == null) return;
    final id = pet?.id ?? widget.petId!;
    final saved = await context.push<bool>(
      AppRoutes.addEditWeightEntry(id),
      extra: WeightEntryFormExtra(
        petId: id,
        petName: pet?.name ?? widget.petName,
        entry: entry,
      ),
    );
    if (!mounted ||
        saved != true ||
        PetCareChanges.maybeOf(context) != null ||
        CareRecordChanges.maybeOf(context) != null) {
      return;
    }
    await _reload();
  }

  Future<void> _create() async {
    if (_busy) return;
    if (_global && widget.pets.isEmpty) {
      await context.push(AppRoutes.addEditPet);
      return;
    }
    await _openForm();
  }

  Future<void> _delete(WeightEntry entry) async {
    final current = _cubit.state;
    if (_busy ||
        current is! WeightHistoryLoaded ||
        current.isRefreshing ||
        _global &&
            (!_petsById.containsKey(entry.petId) || _ownerId != entry.petId)) {
      return;
    }
    final strings = AppLocalizations.of(context);
    final weight = localizedWeight(
      entry.weight,
      Localizations.localeOf(context),
    );
    final date = MaterialLocalizations.of(context)
        .formatShortDate(entry.measuredAt.toLocal());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: strings.deleteMeasurementTitle,
        message: _global
            ? strings.deleteMeasurementForPetMessage(
                weight,
                date,
                _petsById[entry.petId]!.name,
              )
            : strings.deleteMeasurementMessage(weight, date),
        confirmLabel: strings.deleteAction,
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    await _cubit.deleteWeightEntry(entry);
    if (!mounted) return;
    final after = _cubit.state;
    if (after is WeightHistoryLoaded &&
        after.deleteError == null &&
        !after.entries.any((item) => item.id == entry.id)) {
      if (_global) {
        CareRecordChanges.maybeOf(context)?.changed(
          entry.petId,
          PetCareTab.weightHistory,
          deletedId: entry.id,
          globalListIsCurrent: true,
        );
      } else {
        PetCareChanges.recordChanged(
          context,
          entry.petId,
          PetCareTab.weightHistory,
          deletedId: entry.id,
          listIsCurrent: true,
        );
      }
    }
  }

  Widget? _filter(bool busy) => !_global || widget.pets.isEmpty
      ? null
      : Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: AppPetFilter(
            pets: widget.pets,
            selectedPetId: _ownerId,
            onChanged: busy ? null : _select,
          ),
        );

  Widget _empty(Widget? header) {
    final strings = AppLocalizations.of(context);
    final empty = CareEmptyView(
      icon: Icons.monitor_weight_outlined,
      title: strings.noMeasurements,
      message: strings.measurementsEmpty,
      bottomPadding: 112,
    );
    if (header == null) return empty;
    return CustomScrollView(
      key: PageStorageKey(('empty-weight', _ownerId)),
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverFillRemaining(hasScrollBody: false, child: empty),
      ],
    );
  }

  Widget _summary(WeightHistoryLoaded state, Widget? header) {
    final latest = <String, WeightEntry>{};
    for (final entry in state.entries) {
      latest.putIfAbsent(entry.petId, () => entry);
    }
    final strings = AppLocalizations.of(context);
    return CustomScrollView(
      key: const PageStorageKey('all-pets-weight'),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(
            child: AppSectionHeading(
              title: strings.latestWeight,
              icon: Icons.monitor_weight_outlined,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 112),
          sliver: SliverList.builder(
            itemCount: widget.pets.length,
            itemBuilder: (context, index) {
              final pet = widget.pets[index];
              final entry = latest[pet.id];
              return Padding(
                key: ValueKey(pet.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: CareRecordCard(
                  pet: pet,
                  title: entry == null
                      ? strings.noMeasurements
                      : '${localizedWeight(entry.weight, Localizations.localeOf(context))} kg',
                  icon: Icons.monitor_weight_outlined,
                  details: entry == null
                      ? null
                      : Text(
                          MaterialLocalizations.of(context)
                              .formatShortDate(entry.measuredAt.toLocal()),
                        ),
                  onOpen: _busy ? null : () => _select(pet.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _loaded(WeightHistoryLoaded state) {
    final strings = AppLocalizations.of(context);
    final header = _filter(state.isDeleting);
    final entries = _global
        ? state.entries.where((entry) => entry.petId == _ownerId).toList()
        : state.entries;
    return Column(
      children: [
        if (state.deleteError != null && state.deletionEntry != null)
          Flexible(
            child: AppErrorFeedback(
              message: strings.measurementDeleteFailed,
              retryLabel: strings.retryDeletion,
              onRetry: state.isDeleting
                  ? null
                  : () => _delete(state.deletionEntry!),
            ),
          )
        else if (state.refreshError != null)
          Flexible(
            child: AppErrorFeedback(
              message: strings.weightLoadFailed,
              onRetry: state.isDeleting ? null : _reload,
            ),
          ),
        Expanded(
          child: AbsorbPointer(
            absorbing: state.isDeleting,
            child: _global && !widget.petsLoaded
                ? const Center(child: CircularProgressIndicator())
                : _global && widget.pets.isEmpty
                ? CareEmptyView(
                    icon: Icons.pets_outlined,
                    title: strings.noPetsYet,
                    message: strings.petsEmptyDescription,
                  )
                : _global && _ownerId == null
                ? _summary(state, header)
                : entries.isEmpty
                ? _empty(header)
                : _Measurements(
                    key: ValueKey(_ownerId),
                    entries: entries,
                    header: header,
                    deletingEntryId: state.isDeleting
                        ? state.deletionEntry?.id
                        : null,
                    onEdit: state.isDeleting ? null : _openForm,
                    onDelete: state.isDeleting || state.isRefreshing
                        ? null
                        : _delete,
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_global && widget.petsLoaded) {
      _cubit.setPetContext(
        widget.pets.map((pet) => pet.id),
        selectedPetId: _ownerId,
      );
    }
    return BlocBuilder<WeightHistoryCubit, WeightHistoryState>(
      builder: (context, state) {
        final deleting = state is WeightHistoryLoaded && state.isDeleting;
        final strings = AppLocalizations.of(context);
        final noPets = _global && widget.petsLoaded && widget.pets.isEmpty;
        return PopScope(
          canPop: !deleting,
          child: Scaffold(
            appBar: _global
                ? null
                : petCareAppBar(
                    context,
                    title: PetCareTitle(
                      title: strings.weightHistory,
                      petName: widget.petName,
                    ),
                    toolbarHeight: PetCareTitle.toolbarHeight(context),
                    busy: deleting,
                    progress:
                        deleting ||
                            state is WeightHistoryLoaded && state.isRefreshing
                        ? LinearProgressIndicator(
                            semanticsLabel: strings.updatingMeasurements,
                          )
                        : null,
                  ),
            floatingActionButton: FloatingActionButton.extended(
              isExtended: MediaQuery.textScalerOf(context).scale(14) <= 21,
              onPressed:
                  state is WeightHistoryLoaded &&
                      !deleting &&
                      (!_global || widget.petsLoaded)
                  ? _create
                  : null,
              icon: const Icon(Icons.add),
              tooltip: noPets ? strings.addFirstPet : strings.addMeasurement,
              label: Text(
                noPets ? strings.addFirstPet : strings.addMeasurement,
              ),
            ),
            body: SafeArea(
              bottom: !_global,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: switch (state) {
                    WeightHistoryLoaded() => _loaded(state),
                    WeightHistoryError(:final failure) => ErrorView(
                      message: failure is NotFoundFailure
                          ? strings.measurementNotFound
                          : strings.weightLoadFailed,
                      onRetry: _reload,
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

class _Measurements extends StatelessWidget {
  final List<WeightEntry> entries;
  final Widget? header;
  final ValueChanged<WeightEntry>? onEdit;
  final ValueChanged<WeightEntry>? onDelete;
  final String? deletingEntryId;

  const _Measurements({
    super.key,
    required this.entries,
    this.header,
    required this.onEdit,
    required this.onDelete,
    required this.deletingEntryId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = entries.first;
    final localizations = MaterialLocalizations.of(context);

    return CustomScrollView(
      key: PageStorageKey(('weight-measurements', latest.petId)),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header!),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).latestWeight,
                          style: theme.textTheme.titleMedium,
                        ),
                        VerticalGap.sm,
                        Text(
                          '${localizedWeight(latest.weight, Localizations.localeOf(context))} kg',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        VerticalGap.xs,
                        Text(
                          localizations.formatShortDate(
                            latest.measuredAt.toLocal(),
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalGap.lg,
                WeightHistoryChart(
                  key: ValueKey(latest.petId),
                  entries: entries,
                ),
                VerticalGap.lg,
                AppSectionHeading(
                  title: AppLocalizations.of(context).measurements,
                  icon: Icons.monitor_weight_outlined,
                ),
                VerticalGap.xs,
                Text(
                  AppLocalizations.of(context).measurementsOrderHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final date = localizations.formatShortDate(
                entry.measuredAt.toLocal(),
              );
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.md,
                    end: AppSpacing.sm,
                  ),
                  minVerticalPadding: AppSpacing.md,
                  title: Text(
                    '${localizedWeight(entry.weight, Localizations.localeOf(context))} kg',
                  ),
                  subtitle: Text(date),
                  onTap: onEdit == null ? null : () => onEdit!(entry),
                  trailing: deletingEntryId == entry.id
                      ? SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: AppLocalizations.of(context)
                                .deletingMeasurement,
                          ),
                        )
                      : IconButton(
                          tooltip: AppLocalizations.of(context)
                              .deleteMeasurementTooltip(
                                localizedWeight(
                                  entry.weight,
                                  Localizations.localeOf(context),
                                ),
                                date,
                              ),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: onDelete == null
                              ? null
                              : () => onDelete!(entry),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
