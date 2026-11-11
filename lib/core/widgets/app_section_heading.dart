import 'package:flutter/material.dart';
import 'package:patilog/core/widgets/app_gap.dart';

class AppSectionHeading extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  const AppSectionHeading({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.trailing,
  }) : assert(icon != null || leading != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        ExcludeSemantics(
          child: IconTheme.merge(
            data: IconThemeData(
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            child: leading ?? Icon(icon),
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
