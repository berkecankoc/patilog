import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: 'Delete measurement?',
        message: 'Remove the ${entry.weight} kg measurement from $date?',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<WeightHistoryCubit>().deleteWeightEntry(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeightHistoryCubit, WeightHistoryState>(
      builder: (context, state) {
        final deleting = state is WeightHistoryLoaded && state.isDeleting;
        return PopScope(
          canPop: !deleting,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Weight history'),
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
                        semanticsLabel: 'Deleting measurement',
                      ),
                    )
                  : null,
            ),
            floatingActionButton: FloatingActionButton.extended(
              // Keep the action within the viewport when text is enlarged.
              isExtended: MediaQuery.textScalerOf(context).scale(14) <= 21,
              onPressed: state is WeightHistoryLoaded && !deleting
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
                    WeightHistoryLoaded(
                      :final entries,
                      :final deleteError,
                      :final deletionEntry,
                    ) =>
                      Column(
                        children: [
                          if (deleteError != null && deletionEntry != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: deleteError,
                                retryLabel: 'Retry deletion',
                                onRetry: () => _delete(context, deletionEntry),
                              ),
                            ),
                          Expanded(
                            child: AbsorbPointer(
                              absorbing: deleting,
                              child: entries.isEmpty
                                  ? SingleChildScrollView(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        24,
                                        24,
                                        96,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.monitor_weight_outlined,
                                            size: 48,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          VerticalGap.md,
                                          Text(
                                            'No measurements yet',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                          VerticalGap.sm,
                                          const Text(
                                            'Add a weight measurement to start the history.',
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
                                  : _Measurements(
                                      entries: entries,
                                      deletingEntryId: deleting
                                          ? deletionEntry?.id
                                          : null,
                                      onEdit: deleting
                                          ? null
                                          : (entry) =>
                                                _openForm(context, entry),
                                      onDelete: deleting
                                          ? null
                                          : (entry) => _delete(context, entry),
                                    ),
                            ),
                          ),
                        ],
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
      },
    );
  }
}

class _Measurements extends StatelessWidget {
  final List<WeightEntry> entries;
  final ValueChanged<WeightEntry>? onEdit;
  final ValueChanged<WeightEntry>? onDelete;
  final String? deletingEntryId;

  const _Measurements({
    required this.entries,
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
                const AppSectionHeading(
                  title: 'Measurements',
                  icon: Icons.monitor_weight_outlined,
                ),
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
                  onTap: onEdit == null ? null : () => onEdit!(entry),
                  trailing: deletingEntryId == entry.id
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Deleting measurement',
                          ),
                        )
                      : IconButton(
                          tooltip:
                              'Delete ${entry.weight} kg measurement from $date',
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
