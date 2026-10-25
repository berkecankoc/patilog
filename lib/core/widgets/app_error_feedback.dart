import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';

/// Wrap in Flexible beside Expanded content to keep recovery reachable when
/// long errors need to scroll on short screens with enlarged text.
class AppErrorFeedback extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  const AppErrorFeedback({
    super.key,
    required this.message,
    this.retryLabel = 'Retry',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Semantics(
                  liveRegion: true,
                  child: Text(message, style: TextStyle(color: colors.error)),
                ),
              ),
            ),
            if (onRetry != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
