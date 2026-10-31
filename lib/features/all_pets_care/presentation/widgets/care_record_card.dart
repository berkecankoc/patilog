import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_avatar.dart';

class CarePetIdentity extends StatelessWidget {
  final Pet? pet;
  const CarePetIdentity({super.key, required this.pet});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ExcludeSemantics(
        child: pet == null
            ? const Icon(Icons.pets_outlined, size: 28)
            : PetAvatar(pet: pet!, size: 28, iconSize: 18),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          pet?.name ?? AppLocalizations.of(context).petUnavailable,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    ],
  );
}

class CareRecordCard extends StatelessWidget {
  final Pet? pet;
  final String title;
  final IconData icon;
  final Widget? details;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final String? deleteLabel;
  final bool deleting;
  const CareRecordCard({
    super.key,
    required this.pet,
    required this.title,
    required this.icon,
    this.details,
    this.onOpen,
    this.onDelete,
    this.deleteLabel,
    this.deleting = false,
  });

  @override
  Widget build(BuildContext context) => Card(
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
                Expanded(child: CarePetIdentity(pet: pet)),
                if (deleteLabel != null)
                  SizedBox.square(
                    dimension: 48,
                    child: deleting
                        ? Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: AppLocalizations.of(
                                context,
                              ).deletingRecord,
                            ),
                          )
                        : IconButton(
                            tooltip: deleteLabel,
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (deleteLabel == null)
                  const ExcludeSemantics(child: Icon(Icons.chevron_right)),
              ],
            ),
            if (details != null) ...[
              const SizedBox(height: AppSpacing.sm),
              details!,
            ],
          ],
        ),
      ),
    ),
  );
}

class CareEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const CareEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
