import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:patilog/core/theme/app_spacing.dart';

class PetCareTitle extends StatelessWidget {
  final String title;
  final String? petName;

  const PetCareTitle({super.key, required this.title, this.petName});

  static double toolbarHeight(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge!.copyWith(
      fontSize: 20,
      height: 1.2,
    );
    final nameStyle = theme.textTheme.bodySmall!.copyWith(height: 1.2);
    final scaler = MediaQuery.textScalerOf(context);
    return math.max(
      kToolbarHeight,
      scaler.scale(titleStyle.fontSize!) * (titleStyle.height ?? 1.4) +
          scaler.scale(nameStyle.fontSize!) * (nameStyle.height ?? 1.4) +
          AppSpacing.xs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            height: 1.2,
          ),
        ),
        if (petName != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            petName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
