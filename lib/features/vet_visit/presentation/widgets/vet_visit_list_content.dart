import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/care_record_card.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

/// Visit presentation shared by the directory and the pet profile.
class VetVisitListContent extends StatelessWidget {
  final List<VetVisit> visits;
  final Map<String, Pet>? petsById;
  final Widget? header;
  final ValueChanged<VetVisit>? onOpen;
  final ValueChanged<VetVisit>? onDelete;
  final bool Function(VetVisit)? isDeleting;

  const VetVisitListContent({
    super.key,
    required this.visits,
    this.petsById,
    this.header,
    required this.onOpen,
    required this.onDelete,
    this.isDeleting,
  });

  Widget _item(VetVisit visit) {
    final available = petsById == null || petsById!.containsKey(visit.petId);
    return _VisitListItem(
      key: ValueKey(visit.id),
      visit: visit,
      showPet: petsById != null,
      pet: petsById?[visit.petId],
      deleting: isDeleting?.call(visit) ?? false,
      onOpen: available && onOpen != null ? () => onOpen!(visit) : null,
      onDelete: available && onDelete != null ? () => onDelete!(visit) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final empty = CareEmptyView(
      icon: Icons.event_note_outlined,
      title: petsById == null ? strings.noVisits : strings.noVetVisits,
      message: petsById == null ? strings.visitsEmpty : strings.allVisitsEmpty,
      bottomPadding: petsById == null ? 96 : 112,
    );
    if (petsById == null) {
      return visits.isEmpty
          ? empty
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
              itemCount: visits.length,
              separatorBuilder: (_, _) => VerticalGap.md,
              itemBuilder: (_, index) => _item(visits[index]),
            );
    }
    return CustomScrollView(
      key: const PageStorageKey('global-visits'),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        if (visits.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: empty)
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 112),
            sliver: SliverList.separated(
              itemCount: visits.length,
              itemBuilder: (_, index) => _item(visits[index]),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
            ),
          ),
      ],
    );
  }
}

class _VisitListItem extends StatelessWidget {
  final VetVisit visit;
  final bool showPet;
  final Pet? pet;
  final bool deleting;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  const _VisitListItem({
    super.key,
    required this.visit,
    this.showPet = false,
    this.pet,
    required this.deleting,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = MaterialLocalizations.of(context)
        .formatShortDate(visit.visitedOn);
    final clinic = visit.clinicName?.trim();
    if (showPet) {
      return CareRecordCard(
        pet: pet,
        title: date,
        icon: Icons.event_note_outlined,
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(visit.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (visit.clinicName != null) ...[
              const SizedBox(height: 8),
              Text(visit.clinicName!),
            ],
          ],
        ),
        onOpen: onOpen,
        deleteLabel: AppLocalizations.of(context)
            .deleteNamedRecord(visit.reason),
        deleting: deleting,
        onDelete: onDelete,
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: colors.surfaceContainer,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.event_note_outlined,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    HorizontalGap.sm,
                    Expanded(
                      child: Text(
                        date,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    HorizontalGap.sm,
                    SizedBox.square(
                      dimension: 48,
                      child: deleting
                          ? Center(
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: AppLocalizations.of(context)
                                      .deletingVisit,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: AppLocalizations.of(context)
                                  .deleteVisitTooltip(date, visit.reason),
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    visit.reason,
                    style: theme.textTheme.bodyLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (clinic != null && clinic.isNotEmpty) ...[
                    VerticalGap.sm,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.local_hospital_outlined,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        HorizontalGap.sm,
                        Expanded(
                          child: Text(
                            clinic,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
