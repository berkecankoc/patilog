import 'package:flutter/material.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';

class AppFormActions extends StatelessWidget {
  final String label;
  final bool saving;
  final bool fixed;
  final VoidCallback? onPressed;
  final Widget? feedback;

  const AppFormActions({
    super.key,
    required this.label,
    required this.saving,
    required this.onPressed,
    this.fixed = false,
    this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (feedback != null) ...[feedback!, VerticalGap.md],
        ElevatedButton(
          onPressed: saving ? null : onPressed,
          child: saving
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    HorizontalGap.sm,
                    Flexible(child: Text(AppLocalizations.of(context).saving)),
                  ],
                )
              : Text(label),
        ),
      ],
    );
    if (!fixed) return content;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
