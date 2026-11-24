import 'package:flutter/material.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/theme/app_spacing.dart';

/// Place in AppFeedbackArea above Expanded content to keep recovery reachable
/// when long errors need to scroll on short screens with enlarged text. With
/// bounded height the message scrolls above a visible action; without one (a
/// scrolling group of strips) the message is laid out in full.
class AppErrorFeedback extends StatelessWidget {
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final EdgeInsets padding;

  const AppErrorFeedback({
    super.key,
    required this.message,
    this.retryLabel,
    this.onRetry,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xs,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final text = Semantics(
              liveRegion: true,
              child: Text(message, style: TextStyle(color: colors.error)),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (constraints.hasBoundedHeight)
                  Flexible(child: SingleChildScrollView(child: text))
                else
                  text,
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
                      child: Text(
                        retryLabel ?? AppLocalizations.of(context).retry,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
