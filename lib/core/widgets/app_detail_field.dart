import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_gap.dart';

class AppDetailField extends StatelessWidget {
  final String label;
  final String? value;

  const AppDetailField({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        VerticalGap.xs,
        Text(
          hasValue ? value! : 'Not provided',
          style: hasValue
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ],
    );
  }
}
