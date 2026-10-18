import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';

class VaccinationStatusBadge extends StatelessWidget {
  final Vaccination vaccination;

  const VaccinationStatusBadge({super.key, required this.vaccination});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final date = DateUtils.dateOnly(vaccination.date);
    final administered = vaccination.status == VaccinationStatus.administered;
    final overdue = !administered && date.isBefore(today);
    final label = administered
        ? 'Administered'
        : overdue
        ? 'Overdue'
        : date == today
        ? 'Due today'
        : 'Upcoming';
    final foreground = administered
        ? colors.onSurfaceVariant
        : overdue
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: administered
              ? colors.surfaceContainerHighest
              : overdue
              ? colors.errorContainer
              : colors.primaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  administered
                      ? Icons.check_circle_outline
                      : overdue
                      ? Icons.event_busy_outlined
                      : Icons.schedule_outlined,
                  size: 18,
                  color: foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
