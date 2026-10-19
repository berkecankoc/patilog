import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';

class AppRelatedRecordsSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onLoad;
  final Widget child;

  const AppRelatedRecordsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.onLoad,
    required this.child,
  });

  @override
  State<AppRelatedRecordsSection> createState() =>
      _AppRelatedRecordsSectionState();
}

class _AppRelatedRecordsSectionState extends State<AppRelatedRecordsSection> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final style = Theme.of(
          context,
        ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600);
        final compactPadding =
            constraints.maxWidth < 300 &&
            MediaQuery.textScalerOf(context).scale(style.fontSize!) > 20;
        return ListTileTheme.merge(
          minLeadingWidth: 20,
          horizontalTitleGap: AppSpacing.sm,
          titleAlignment: ListTileTitleAlignment.center,
          child: ExpansionTile(
            maintainState: true,
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Icon(widget.icon, size: 20),
            title: Text(widget.title, style: style),
            tilePadding: EdgeInsets.symmetric(
              horizontal: compactPadding ? AppSpacing.xs : AppSpacing.md,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            onExpansionChanged: (expanded) {
              if (expanded && !_requested) {
                _requested = true;
                widget.onLoad();
              }
            },
            children: [widget.child],
          ),
        );
      },
    ),
  );
}

class AppRelatedRecordTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String openLabel;
  final VoidCallback? onOpen;
  final Widget details;

  const AppRelatedRecordTile({
    super.key,
    required this.title,
    required this.icon,
    required this.openLabel,
    required this.onOpen,
    required this.details,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final style = theme.textTheme.bodyLarge!;
      final stackAction =
          constraints.maxWidth < 280 &&
          MediaQuery.textScalerOf(context).scale(style.fontSize!) > 20;
      final action = IconButton(
        tooltip: openLabel,
        icon: const Icon(Icons.chevron_right),
        onPressed: onOpen,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(icon, size: 20)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: style,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!stackAction) action,
            ],
          ),
          if (stackAction)
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          details,
        ],
      );
    },
  );
}
