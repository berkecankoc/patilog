import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:petlytics/core/widgets/pet_care_tabs.dart';
import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/l10n/app_number_formats.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_state.dart';
import 'package:petlytics/features/weight_history/presentation/widgets/weight_history_chart.dart';

class WeightHistoryPage extends StatelessWidget {
  final String petId;
  final String? petName;

  const WeightHistoryPage({super.key, required this.petId, this.petName});

  Future<void> _openForm(BuildContext context, [WeightEntry? entry]) async {
    final saved = await context.push<bool>(
      AppRoutes.addEditWeightEntry(petId),
      extra: WeightEntryFormExtra(petId: petId, petName: petName, entry: entry),
    );
    if (!context.mounted || PetCareChanges.maybeOf(context) != null) return;
    if (saved == true) {
      await context.read<WeightHistoryCubit>().loadWeightHistory(petId);
    }
  }

  Future<void> _delete(BuildContext context, WeightEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: AppLocalizations.of(context).deleteMeasurementTitle,
        message: AppLocalizations.of(context).deleteMeasurementMessage(
          localizedWeight(entry.weight, Localizations.localeOf(context)),
          MaterialLocalizations.of(
            context,
          ).formatShortDate(entry.measuredAt.toLocal()),
        ),
        confirmLabel: AppLocalizations.of(context).deleteAction,
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<WeightHistoryCubit>().deleteWeightEntry(entry);
      if (!context.mounted) return;
      if (context.read<WeightHistoryCubit>().state case WeightHistoryLoaded(
        :final entries,
      ) when !entries.any((item) => item.id == entry.id)) {
        PetCareChanges.recordChanged(
          context,
          petId,
          PetCareTab.weightHistory,
          listIsCurrent: true,
        );
      }
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
            appBar: petCareAppBar(
              context,
              title: PetCareTitle(
                title: AppLocalizations.of(context).weightHistory,
                petName: petName,
              ),
              toolbarHeight: PetCareTitle.toolbarHeight(context),
              busy: deleting,
              progress:
                  deleting || state is WeightHistoryLoaded && state.isRefreshing
                  ? LinearProgressIndicator(
                      semanticsLabel: AppLocalizations.of(
                        context,
                      ).updatingMeasurements,
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
              tooltip: AppLocalizations.of(context).addMeasurement,
              label: Text(AppLocalizations.of(context).addMeasurement),
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
                      :final refreshError,
                    ) =>
                      Column(
                        children: [
                          if (deleteError != null && deletionEntry != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: AppLocalizations.of(
                                  context,
                                ).measurementDeleteFailed,
                                retryLabel: AppLocalizations.of(
                                  context,
                                ).retryDeletion,
                                onRetry: () => _delete(context, deletionEntry),
                              ),
                            )
                          else if (refreshError != null)
                            Flexible(
                              child: AppErrorFeedback(
                                message: AppLocalizations.of(
                                  context,
                                ).weightLoadFailed,
                                onRetry: () => context
                                    .read<WeightHistoryCubit>()
                                    .loadWeightHistory(petId),
                              ),
                            ),
                          Expanded(
                            child: AbsorbPointer(
                              absorbing: deleting,
                              child: entries.isEmpty
                                  ? Center(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          24,
                                          24,
                                          96,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ExcludeSemantics(
                                              child: Icon(
                                                Icons.monitor_weight_outlined,
                                                size: 48,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            VerticalGap.md,
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              ).noMeasurements,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            VerticalGap.sm,
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              ).measurementsEmpty,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
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
                    WeightHistoryError(:final failure) => ErrorView(
                      message: failure is NotFoundFailure
                          ? AppLocalizations.of(context).measurementNotFound
                          : AppLocalizations.of(context).weightLoadFailed,
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
                            semanticsLabel: AppLocalizations.of(
                              context,
                            ).deletingMeasurement,
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
