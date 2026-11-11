import 'package:flutter/material.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/widgets/app_gap.dart';

class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 360),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    namesRoute: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  VerticalGap.md,
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              primary: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: OverflowBar(
                  spacing: AppSpacing.sm,
                  overflowSpacing: AppSpacing.sm,
                  alignment: MainAxisAlignment.center,
                  overflowAlignment: OverflowBarAlignment.center,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        minimumSize: const Size(96, 48),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        cancelLabel ?? AppLocalizations.of(context).cancel,
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(96, 48),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
