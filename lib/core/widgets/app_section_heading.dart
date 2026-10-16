import 'package:flutter/material.dart';
import 'package:petlytics/core/widgets/app_gap.dart';

class AppSectionHeading extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const AppSectionHeading({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        HorizontalGap.sm,
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
