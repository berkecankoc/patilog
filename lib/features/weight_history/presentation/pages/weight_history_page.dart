import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_state.dart';

class WeightHistoryPage extends StatelessWidget {
  final String petId;

  const WeightHistoryPage({super.key, required this.petId});

  Future<void> _openForm(BuildContext context, [WeightEntry? entry]) async {
    final saved = await context.push<bool>(
      AppRoutes.addEditWeightEntry(petId),
      extra: entry,
    );
    if (saved == true && context.mounted) {
      await context.read<WeightHistoryCubit>().loadWeightHistory(petId);
    }
  }

  Future<void> _delete(BuildContext context, WeightEntry entry) async {
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(entry.measuredAt.toLocal());
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete measurement?'),
        content: Text('Remove the ${entry.weight} kg measurement from $date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<WeightHistoryCubit>().deleteWeightEntry(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeightHistoryCubit, WeightHistoryState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Weight history')),
        floatingActionButton: FloatingActionButton.extended(
          // Keep the action within the viewport when text is enlarged.
          isExtended: MediaQuery.textScalerOf(context).scale(14) <= 21,
          onPressed: state is WeightHistoryLoaded
              ? () => _openForm(context)
              : null,
          icon: const Icon(Icons.add),
          tooltip: 'Add measurement',
          label: const Text('Add weight'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: switch (state) {
                WeightHistoryLoaded(:final entries) when entries.isEmpty =>
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monitor_weight_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        VerticalGap.md,
                        Text(
                          'No measurements yet',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        VerticalGap.sm,
                        const Text(
                          'Add a weight measurement to start the history.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                WeightHistoryLoaded(:final entries) => _Measurements(
                  entries: entries,
                  onEdit: (entry) => _openForm(context, entry),
                  onDelete: (entry) => _delete(context, entry),
                ),
                WeightHistoryError(:final message) => ErrorView(
                  message: message,
                  onRetry: () => context
                      .read<WeightHistoryCubit>()
                      .loadWeightHistory(petId),
                ),
                _ => const CircularProgressIndicator(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Measurements extends StatelessWidget {
  final List<WeightEntry> entries;
  final ValueChanged<WeightEntry> onEdit;
  final ValueChanged<WeightEntry> onDelete;

  const _Measurements({
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = entries.first;
    final localizations = MaterialLocalizations.of(context);

    return CustomScrollView(
      slivers: [
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
                          'Latest weight',
                          style: theme.textTheme.titleMedium,
                        ),
                        VerticalGap.sm,
                        Text(
                          '${latest.weight} kg',
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
                Text('Measurements', style: theme.textTheme.titleLarge),
                VerticalGap.xs,
                Text(
                  'Newest first. Select a measurement to edit it.',
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
                  title: Text('${entry.weight} kg'),
                  subtitle: Text(date),
                  onTap: () => onEdit(entry),
                  trailing: IconButton(
                    tooltip: 'Delete ${entry.weight} kg measurement from $date',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(entry),
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
