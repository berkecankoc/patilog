import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/care_record_card.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/widgets/vaccination_status_badge.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

/// Callers retain their existing grouping; both contexts share list rendering.
class VaccinationListContent extends StatelessWidget {
  final List<({String title, IconData icon, List<Vaccination> records})> groups;
  final Map<String, Pet>? petsById;
  final Widget? header;
  final ValueChanged<Vaccination>? onOpen;
  final ValueChanged<Vaccination>? onDelete;
  final bool Function(Vaccination)? isDeleting;

  const VaccinationListContent({
    super.key,
    required this.groups,
    this.petsById,
    this.header,
    required this.onOpen,
    required this.onDelete,
    this.isDeleting,
  });

  Widget _item(Vaccination vaccination) {
    final available =
        petsById == null || petsById!.containsKey(vaccination.petId);
    return _VaccinationListItem(
      vaccination: vaccination,
      showPet: petsById != null,
      pet: petsById?[vaccination.petId],
      deleting: isDeleting?.call(vaccination) ?? false,
      onOpen: available && onOpen != null ? () => onOpen!(vaccination) : null,
      onDelete: available && onDelete != null
          ? () => onDelete!(vaccination)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final global = petsById != null;
    final empty = CareEmptyView(
      icon: Icons.vaccines_outlined,
      title: strings.noVaccinations,
      message: strings.vaccinationsEmpty,
      bottomPadding: global ? 112 : 96,
    );
    if (!global && groups.every((group) => group.records.isEmpty)) return empty;
    return CustomScrollView(
      key: global ? const PageStorageKey('global-vaccines') : null,
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        if (groups.every((group) => group.records.isEmpty))
          SliverFillRemaining(hasScrollBody: false, child: empty),
        for (final group in groups)
          if (group.records.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, global ? 12 : 16),
              sliver: SliverToBoxAdapter(
                child: AppSectionHeading(title: group.title, icon: group.icon),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: group.records.length,
                itemBuilder: (_, index) {
                  final vaccination = group.records[index];
                  return Padding(
                    key: ValueKey(vaccination.id),
                    padding: EdgeInsets.only(bottom: global ? 12 : 16),
                    child: _item(vaccination),
                  );
                },
              ),
            ),
          ],
        SliverToBoxAdapter(child: SizedBox(height: global ? 112 : 96)),
      ],
    );
  }
}

class _VaccinationListItem extends StatelessWidget {
  final Vaccination vaccination;
  final bool showPet;
  final Pet? pet;
  final bool deleting;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  const _VaccinationListItem({
    required this.vaccination,
    this.showPet = false,
    this.pet,
    required this.deleting,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = MaterialLocalizations.of(context)
        .formatShortDate(vaccination.date);
    if (showPet) {
      return CareRecordCard(
        pet: pet,
        title: vaccination.vaccineName,
        icon: Icons.vaccines_outlined,
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date),
            const SizedBox(height: 8),
            VaccinationStatusBadge(vaccination: vaccination),
          ],
        ),
        onOpen: onOpen,
        deleteLabel: AppLocalizations.of(context)
            .deleteNamedRecord(vaccination.vaccineName),
        deleting: deleting,
        onDelete: onDelete,
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.event_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
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
                  SizedBox.square(
                    dimension: 48,
                    child: deleting
                        ? Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: AppLocalizations.of(context)
                                    .deletingVaccination,
                              ),
                            ),
                          )
                        : IconButton(
                            tooltip: AppLocalizations.of(context)
                                .deleteVaccinationTooltip(
                                  vaccination.vaccineName,
                                  date,
                                ),
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline),
                          ),
                  ),
                ],
              ),
              Text(
                vaccination.vaccineName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              VerticalGap.sm,
              VaccinationStatusBadge(vaccination: vaccination),
              if (vaccination.clinicName != null) ...[
                VerticalGap.sm,
                Text(
                  vaccination.clinicName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
